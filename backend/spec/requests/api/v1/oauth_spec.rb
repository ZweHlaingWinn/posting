require 'rails_helper'

RSpec.describe 'Api::V1::Oauth', type: :request do
  let(:user) { create(:user) }

  around do |example|
    ENV['TIKTOK_CLIENT_KEY'] = 'test-client-key'
    ENV['TIKTOK_CLIENT_SECRET'] = 'test-client-secret'
    example.run
    ENV.delete('TIKTOK_CLIENT_KEY')
    ENV.delete('TIKTOK_CLIENT_SECRET')
  end

  describe 'POST /api/v1/oauth/:platform/authorize' do
    it 'returns a TikTok authorization url for an authenticated user' do
      post '/api/v1/oauth/tiktok/authorize', headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['authorization_url']).to start_with(Oauth::Providers::Tiktok::AUTHORIZE_URL)
      expect(json_body['platform']).to eq('tiktok')
    end

    it 'includes a state and PKCE challenge in the url' do
      post '/api/v1/oauth/tiktok/authorize', headers: auth_headers_for(user), as: :json
      query = Rack::Utils.parse_query(URI.parse(json_body['authorization_url']).query)

      expect(query['state']).to be_present
      expect(query['code_challenge']).to be_present
      expect(query['code_challenge_method']).to eq('S256')
    end

    it 'binds the state to the calling user' do
      post '/api/v1/oauth/tiktok/authorize', headers: auth_headers_for(user), as: :json
      query = Rack::Utils.parse_query(URI.parse(json_body['authorization_url']).query)

      expect(Oauth::StateToken.decode(query['state'])).to include(user_id: user.id)
    end

    it 'never exposes the client secret' do
      post '/api/v1/oauth/tiktok/authorize', headers: auth_headers_for(user), as: :json

      expect(response.body).not_to include('test-client-secret')
    end

    it 'returns 401 without a token' do
      post '/api/v1/oauth/tiktok/authorize', as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 422 for a platform with no provider yet' do
      post '/api/v1/oauth/facebook/authorize', headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors'].first).to match(/not supported yet/)
    end

    it 'returns 503 when the platform credentials are not configured' do
      ENV.delete('TIKTOK_CLIENT_KEY')

      post '/api/v1/oauth/tiktok/authorize', headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:service_unavailable)
      expect(json_body['errors'].first).to match(/TIKTOK_CLIENT_KEY/)
    end
  end

  describe 'GET /api/v1/oauth/:platform/callback' do
    let(:verifier) { 'the-verifier' }
    let(:state) do
      Oauth::StateToken.encode(user_id: user.id, platform: 'tiktok', code_verifier: verifier)
    end
    let(:credentials) do
      Oauth::Providers::Base::Credentials.new(
        external_account_id: 'open-id-123',
        external_username: 'Creator Name',
        access_token: 'access-token',
        refresh_token: 'refresh-token',
        expires_at: 1.day.from_now
      )
    end

    before do
      allow(Oauth::ProviderRegistry).to receive(:for).with('tiktok')
        .and_return(instance_double(Oauth::Providers::Tiktok, exchange_code: credentials))
    end

    it 'connects the account and redirects into the frontend' do
      expect {
        get '/api/v1/oauth/tiktok/callback', params: { code: 'the-code', state: state }
      }.to change { user.social_accounts.count }.by(1)

      expect(response).to have_http_status(:found)
      expect(response.location).to start_with('http://localhost:5173/launches')
      expect(response.location).to include('connected=tiktok')
    end

    it 'requires no JWT, since the provider redirects the browser here' do
      get '/api/v1/oauth/tiktok/callback', params: { code: 'the-code', state: state }

      expect(response).not_to have_http_status(:unauthorized)
    end

    it 'redirects with an error when the user denies consent' do
      get '/api/v1/oauth/tiktok/callback',
          params: { error: 'access_denied', error_description: 'User denied', state: state }

      expect(response).to have_http_status(:found)
      expect(response.location).to include('connect_error=User+denied')
    end

    it 'redirects with an error for a tampered state' do
      expect {
        get '/api/v1/oauth/tiktok/callback', params: { code: 'the-code', state: 'tampered' }
      }.not_to change(SocialAccount, :count)

      expect(response.location).to include('connect_error=')
    end

    it 'redirects with an error when the code is missing' do
      get '/api/v1/oauth/tiktok/callback', params: { state: state }

      expect(response.location).to include('connect_error=')
    end

    it 'does not leak tokens into the redirect url' do
      get '/api/v1/oauth/tiktok/callback', params: { code: 'the-code', state: state }

      expect(response.location).not_to include('access-token')
      expect(response.location).not_to include('refresh-token')
    end

    it 'still redirects into the frontend when the callback raises' do
      allow(Oauth::HandleCallbackService).to receive(:call).and_raise(RuntimeError, 'boom')

      get '/api/v1/oauth/tiktok/callback', params: { code: 'the-code', state: state }

      expect(response).to have_http_status(:found)
      expect(response.location).to start_with('http://localhost:5173/launches')
      expect(response.location).to include('connect_error=')
    end
  end
end
