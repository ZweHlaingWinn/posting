require 'rails_helper'

RSpec.describe 'Api::V1::Passwords', type: :request do
  let!(:user) do
    create(:user, email: 'member@example.com', password: 'password123',
                  password_confirmation: 'password123')
  end
  let(:confirmation) do
    'If that email address exists, password reset instructions have been sent.'
  end

  describe 'POST /api/v1/auth/password' do
    it 'sends reset instructions to a registered address' do
      expect {
        post '/api/v1/auth/password', params: { user: { email: 'member@example.com' } }, as: :json
      }.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(json_body['message']).to eq(confirmation)
      expect(ActionMailer::Base.deliveries.last.to).to eq(['member@example.com'])
    end

    it 'links the email to the frontend reset page' do
      post '/api/v1/auth/password', params: { user: { email: 'member@example.com' } }, as: :json

      expect(ActionMailer::Base.deliveries.last.body.encoded)
        .to include('/reset-password?token=')
    end

    it 'returns the same response for an unknown address without sending mail' do
      expect {
        post '/api/v1/auth/password', params: { user: { email: 'nobody@example.com' } }, as: :json
      }.not_to change { ActionMailer::Base.deliveries.count }

      expect(response).to have_http_status(:ok)
      expect(json_body['message']).to eq(confirmation)
    end

    it 'returns 400 without a user key' do
      post '/api/v1/auth/password', params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe 'PUT /api/v1/auth/password' do
    # `send_reset_password_instructions` returns the raw token; only its digest
    # is stored, so this is the only place it can be captured.
    let(:raw_token) { user.send_reset_password_instructions }

    it 'resets the password with a valid token' do
      put '/api/v1/auth/password',
          params: { user: { reset_password_token: raw_token, password: 'new-password456',
                            password_confirmation: 'new-password456' } },
          as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['message']).to eq('Password has been reset successfully')
      expect(user.reload.valid_password?('new-password456')).to be(true)
    end

    it 'lets the user log in with the new password afterwards' do
      put '/api/v1/auth/password',
          params: { user: { reset_password_token: raw_token, password: 'new-password456',
                            password_confirmation: 'new-password456' } },
          as: :json

      post '/api/v1/auth/login',
           params: { user: { email: 'member@example.com', password: 'new-password456' } },
           as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'revokes tokens issued before the reset' do
      stale_headers = auth_headers_for(user)

      put '/api/v1/auth/password',
          params: { user: { reset_password_token: raw_token, password: 'new-password456',
                            password_confirmation: 'new-password456' } },
          as: :json

      delete '/api/v1/auth/logout', headers: stale_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 422 for an invalid token' do
      put '/api/v1/auth/password',
          params: { user: { reset_password_token: 'bogus-token', password: 'new-password456',
                            password_confirmation: 'new-password456' } },
          as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include('Reset password token is invalid')
      expect(user.reload.valid_password?('password123')).to be(true)
    end

    it 'returns 422 for an expired token' do
      token = raw_token

      travel_to(Devise.reset_password_within.from_now + 1.minute) do
        put '/api/v1/auth/password',
            params: { user: { reset_password_token: token, password: 'new-password456',
                              password_confirmation: 'new-password456' } },
            as: :json
      end

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include('Reset password token has expired, please request a new one')
    end

    it 'returns 422 when the confirmation does not match' do
      put '/api/v1/auth/password',
          params: { user: { reset_password_token: raw_token, password: 'new-password456',
                            password_confirmation: 'something-else' } },
          as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to include("Password confirmation doesn't match Password")
    end

    it 'returns 400 without a user key' do
      put '/api/v1/auth/password', params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end
end
