require 'rails_helper'

RSpec.describe 'Api::V1::Sessions', type: :request do
  let!(:user) do
    create(:user, email: 'member@example.com', password: 'password123',
                  password_confirmation: 'password123')
  end

  describe 'POST /api/v1/auth/login' do
    it 'returns 200 with the user and a token for valid credentials' do
      post '/api/v1/auth/login',
           params: { user: { email: 'member@example.com', password: 'password123' } },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['user']).to include('email' => 'member@example.com')
      expect(json_body['token']).to be_present
    end

    it 'accepts a differently cased email' do
      post '/api/v1/auth/login',
           params: { user: { email: 'MEMBER@example.com', password: 'password123' } },
           as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'returns 401 for a wrong password' do
      post '/api/v1/auth/login',
           params: { user: { email: 'member@example.com', password: 'wrong-password' } },
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_body['errors']).to eq(['Invalid email or password'])
    end

    it 'returns 401 for an unknown email' do
      post '/api/v1/auth/login',
           params: { user: { email: 'nobody@example.com', password: 'password123' } },
           as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_body['errors']).to eq(['Invalid email or password'])
    end

    it 'gives an identical response for a wrong password and an unknown email' do
      post '/api/v1/auth/login',
           params: { user: { email: 'member@example.com', password: 'wrong-password' } },
           as: :json
      wrong_password_body = response.body

      post '/api/v1/auth/login',
           params: { user: { email: 'nobody@example.com', password: 'password123' } },
           as: :json

      expect(response.body).to eq(wrong_password_body)
    end

    it 'returns 400 without a user key' do
      post '/api/v1/auth/login', params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'DELETE /api/v1/auth/logout' do
    it 'returns 200 for an authenticated user' do
      delete '/api/v1/auth/logout', headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['message']).to eq('Signed out successfully')
    end

    it 'rotates the jti so the presented token stops working' do
      headers = auth_headers_for(user)

      expect { delete '/api/v1/auth/logout', headers: headers, as: :json }
        .to change { user.reload.jti }

      delete '/api/v1/auth/logout', headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 without a token' do
      delete '/api/v1/auth/logout', as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(json_body['errors']).to be_present
    end

    it 'returns 401 for a malformed token' do
      delete '/api/v1/auth/logout',
             headers: { 'Authorization' => 'Bearer not-a-real-token' },
             as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
