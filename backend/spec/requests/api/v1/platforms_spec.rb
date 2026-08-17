require 'rails_helper'

RSpec.describe 'Api::V1::Platforms', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v1/platforms' do
    it 'lists every platform the SocialAccount enum supports' do
      get '/api/v1/platforms', headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['platforms'].map { |p| p['id'] })
        .to eq(%w[twitter linkedin facebook instagram tiktok])
    end

    it 'marks TikTok connectable once its credentials are configured' do
      ENV['TIKTOK_CLIENT_KEY'] = 'key'
      ENV['TIKTOK_CLIENT_SECRET'] = 'secret'

      get '/api/v1/platforms', headers: auth_headers_for(user), as: :json
      tiktok = json_body['platforms'].find { |p| p['id'] == 'tiktok' }

      expect(tiktok['connectable']).to be(true)
    ensure
      ENV.delete('TIKTOK_CLIENT_KEY')
      ENV.delete('TIKTOK_CLIENT_SECRET')
    end

    it 'marks TikTok not connectable while credentials are absent' do
      get '/api/v1/platforms', headers: auth_headers_for(user), as: :json
      tiktok = json_body['platforms'].find { |p| p['id'] == 'tiktok' }

      expect(tiktok['connectable']).to be(false)
    end

    it 'marks platforms with no OAuth provider as not connectable' do
      get '/api/v1/platforms', headers: auth_headers_for(user), as: :json
      facebook = json_body['platforms'].find { |p| p['id'] == 'facebook' }

      expect(facebook['connectable']).to be(false)
    end

    it 'reports nothing publishable while every adapter is a stub' do
      get '/api/v1/platforms', headers: auth_headers_for(user), as: :json

      expect(json_body['platforms'].map { |p| p['publishable'] }).to all(be(false))
    end

    it 'returns a display name per platform' do
      get '/api/v1/platforms', headers: auth_headers_for(user), as: :json

      expect(json_body['platforms'].find { |p| p['id'] == 'tiktok' }['name']).to eq('Tiktok')
    end

    it 'returns 401 without a token' do
      get '/api/v1/platforms', as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
