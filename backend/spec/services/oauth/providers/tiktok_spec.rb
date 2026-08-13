require 'rails_helper'

RSpec.describe Oauth::Providers::Tiktok do
  subject(:provider) { described_class.new }

  # HTTP is stubbed at the Oauth::Http seam, so no network access and no
  # stubbing library is needed.
  let(:token_response) do
    {
      'access_token' => 'tiktok-access-token',
      'refresh_token' => 'tiktok-refresh-token',
      'expires_in' => 86_400,
      'open_id' => 'open-id-123',
      'scope' => 'user.info.basic,video.upload'
    }
  end
  let(:user_info_response) do
    { 'data' => { 'user' => { 'open_id' => 'open-id-123', 'display_name' => 'Creator Name' } } }
  end

  around do |example|
    ENV['TIKTOK_CLIENT_KEY'] = 'test-client-key'
    ENV['TIKTOK_CLIENT_SECRET'] = 'test-client-secret'
    ENV['BACKEND_URL'] = 'https://api.example.com'
    example.run
    ENV.delete('TIKTOK_CLIENT_KEY')
    ENV.delete('TIKTOK_CLIENT_SECRET')
    ENV.delete('BACKEND_URL')
  end

  describe '#authorization_url' do
    subject(:url) { provider.authorization_url(state: 'the-state', code_challenge: 'the-challenge') }

    let(:query) { Rack::Utils.parse_query(URI.parse(url).query) }

    it 'points at the TikTok v2 authorize endpoint' do
      expect(url).to start_with(described_class::AUTHORIZE_URL)
    end

    it 'sends client_key rather than client_id' do
      expect(query).to include('client_key' => 'test-client-key')
      expect(query).not_to have_key('client_id')
    end

    it 'never includes the client secret' do
      expect(url).not_to include('test-client-secret')
    end

    it 'requests an authorization code' do
      expect(query).to include('response_type' => 'code')
    end

    it 'includes the PKCE challenge and method' do
      expect(query).to include('code_challenge' => 'the-challenge', 'code_challenge_method' => 'S256')
    end

    it 'includes the state' do
      expect(query).to include('state' => 'the-state')
    end

    it 'builds the redirect uri from BACKEND_URL' do
      expect(query).to include(
        'redirect_uri' => 'https://api.example.com/api/v1/oauth/tiktok/callback'
      )
    end

    it 'requests the default scopes when none are configured' do
      expect(query).to include('scope' => described_class::DEFAULT_SCOPES)
    end

    it 'honours TIKTOK_SCOPES when set' do
      ENV['TIKTOK_SCOPES'] = 'user.info.basic,video.publish'

      expect(query).to include('scope' => 'user.info.basic,video.publish')
    ensure
      ENV.delete('TIKTOK_SCOPES')
    end

    it 'raises when the credentials are absent' do
      ENV.delete('TIKTOK_CLIENT_KEY')

      expect { url }.to raise_error(
        Oauth::Providers::Base::ConfigurationError, /TIKTOK_CLIENT_KEY/
      )
    end
  end

  describe '#exchange_code' do
    before do
      allow(Oauth::Http).to receive(:post_form).and_return(token_response)
      allow(Oauth::Http).to receive(:get_json).and_return(user_info_response)
    end

    subject(:credentials) { provider.exchange_code(code: 'the-code', code_verifier: 'the-verifier') }

    it 'returns normalised credentials' do
      expect(credentials.external_account_id).to eq('open-id-123')
      expect(credentials.external_username).to eq('Creator Name')
      expect(credentials.access_token).to eq('tiktok-access-token')
      expect(credentials.refresh_token).to eq('tiktok-refresh-token')
      expect(credentials.scopes).to eq('user.info.basic,video.upload')
    end

    it 'converts expires_in into an absolute time' do
      freeze_time do
        expect(credentials.expires_at).to be_within(1.second).of(86_400.seconds.from_now)
      end
    end

    it 'posts the code and verifier to the token endpoint' do
      credentials

      expect(Oauth::Http).to have_received(:post_form).with(
        described_class::TOKEN_URL,
        hash_including(
          client_key: 'test-client-key',
          client_secret: 'test-client-secret',
          code: 'the-code',
          grant_type: 'authorization_code',
          code_verifier: 'the-verifier'
        ),
        anything
      )
    end

    it 'reads the profile with the access token as a bearer credential' do
      credentials

      expect(Oauth::Http).to have_received(:get_json).with(
        a_string_starting_with(described_class::USER_INFO_URL),
        { 'Authorization' => 'Bearer tiktok-access-token' }
      )
    end

    it 'leaves expires_at nil when TikTok omits expires_in' do
      allow(Oauth::Http).to receive(:post_form).and_return(token_response.except('expires_in'))

      expect(credentials.expires_at).to be_nil
    end

    it 'falls back to the profile open_id when the token response omits it' do
      allow(Oauth::Http).to receive(:post_form).and_return(token_response.except('open_id'))

      expect(credentials.external_account_id).to eq('open-id-123')
    end

    it 'raises when no access token comes back' do
      allow(Oauth::Http).to receive(:post_form).and_return(token_response.except('access_token'))

      expect { credentials }.to raise_error(
        Oauth::Providers::Base::AuthorizationError, /did not return an access token/
      )
    end

    it 'surfaces the provider description when the code is rejected' do
      allow(Oauth::Http).to receive(:post_form).and_raise(
        Oauth::Http::Error.new('HTTP 400', status: 400,
                                          body: { 'error_description' => 'authorization_code is invalid' })
      )

      expect { credentials }.to raise_error(
        Oauth::Providers::Base::AuthorizationError, /authorization_code is invalid/
      )
    end

    it 'raises when the profile lookup fails' do
      allow(Oauth::Http).to receive(:get_json).and_raise(
        Oauth::Http::Error.new('HTTP 401', status: 401, body: nil)
      )

      expect { credentials }.to raise_error(
        Oauth::Providers::Base::AuthorizationError, /Could not read the TikTok profile/
      )
    end
  end

  describe '#configured?' do
    it 'is true when both credentials are present' do
      expect(provider).to be_configured
    end

    it 'is false when the secret is missing' do
      ENV.delete('TIKTOK_CLIENT_SECRET')

      expect(provider).not_to be_configured
    end
  end
end
