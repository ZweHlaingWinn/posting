require 'rails_helper'

RSpec.describe 'Api::V1::Registrations', type: :request do
  describe 'POST /api/v1/auth/signup' do
    let(:valid_params) do
      {
        user: {
          email: 'new-user@example.com',
          password: 'password123',
          password_confirmation: 'password123'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates the user' do
        expect { post '/api/v1/auth/signup', params: valid_params, as: :json }
          .to change(User, :count).by(1)
      end

      it 'returns 201 with the user and a token' do
        post '/api/v1/auth/signup', params: valid_params, as: :json

        expect(response).to have_http_status(:created)
        expect(json_body['user']).to include('email' => 'new-user@example.com')
        expect(json_body['user']).to include('id', 'created_at')
        expect(json_body['token']).to be_present
      end

      it 'never exposes the password digest' do
        post '/api/v1/auth/signup', params: valid_params, as: :json

        expect(json_body['user']).not_to include('encrypted_password', 'jti')
      end

      it 'returns a token that authenticates subsequent requests' do
        post '/api/v1/auth/signup', params: valid_params, as: :json
        token = json_body['token']

        delete '/api/v1/auth/logout', headers: { 'Authorization' => "Bearer #{token}" }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with a duplicate email' do
      before { create(:user, email: 'new-user@example.com') }

      it 'returns 422 without creating a user' do
        expect { post '/api/v1/auth/signup', params: valid_params, as: :json }
          .not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_body['errors']).to include('Email has already been taken')
      end
    end

    context 'with a mismatched password confirmation' do
      it 'returns 422' do
        post '/api/v1/auth/signup',
             params: { user: valid_params[:user].merge(password_confirmation: 'different123') },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_body['errors']).to include("Password confirmation doesn't match Password")
      end
    end

    context 'with an invalid email' do
      it 'returns 422' do
        post '/api/v1/auth/signup',
             params: { user: valid_params[:user].merge(email: 'not-an-email') },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_body['errors']).to include('Email is invalid')
      end
    end

    context 'without a user key' do
      it 'returns 400' do
        post '/api/v1/auth/signup', params: {}, as: :json

        expect(response).to have_http_status(:bad_request)
        expect(json_body['errors'].first).to match(/Missing required parameter/)
      end
    end
  end
end
