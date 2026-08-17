require 'rails_helper'

RSpec.describe 'Api::V1::SocialAccounts', type: :request do
  let(:user) { create(:user) }

  describe 'GET /api/v1/social_accounts' do
    it 'returns the caller\'s connected channels' do
      account = create(:social_account, user: user, external_username: 'creator')

      get '/api/v1/social_accounts', headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['social_accounts'].length).to eq(1)
      expect(json_body['social_accounts'].first).to include(
        'id' => account.id,
        'platform' => 'twitter',
        'status' => 'active',
        'external_username' => 'creator'
      )
    end

    it 'never exposes tokens' do
      create(:social_account, user: user, access_token: 'secret-token')

      get '/api/v1/social_accounts', headers: auth_headers_for(user), as: :json

      expect(response.body).not_to include('secret-token')
      expect(json_body['social_accounts'].first.keys)
        .not_to include('access_token', 'refresh_token')
    end

    it 'does not leak another user\'s channels' do
      create(:social_account)

      get '/api/v1/social_accounts', headers: auth_headers_for(user), as: :json

      expect(json_body['social_accounts']).to be_empty
    end

    it 'returns an empty list before anything is connected' do
      get '/api/v1/social_accounts', headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(json_body['social_accounts']).to eq([])
    end

    it 'orders newest first' do
      older = create(:social_account, user: user, created_at: 2.days.ago)
      newer = create(:social_account, user: user, created_at: 1.hour.ago)

      get '/api/v1/social_accounts', headers: auth_headers_for(user), as: :json

      expect(json_body['social_accounts'].map { |a| a['id'] }).to eq([newer.id, older.id])
    end

    it 'returns 401 without a token' do
      get '/api/v1/social_accounts', as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE /api/v1/social_accounts/:id' do
    let!(:account) { create(:social_account, user: user) }

    it 'revokes the channel and clears its tokens' do
      delete "/api/v1/social_accounts/#{account.id}", headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(account.reload).to be_status_revoked
      expect(account.access_token).to be_nil
      expect(account.refresh_token).to be_nil
    end

    it 'keeps the row so publishing history survives' do
      target = create(:post_target, :published, social_account: account)

      expect {
        delete "/api/v1/social_accounts/#{account.id}", headers: auth_headers_for(user), as: :json
      }.not_to change(SocialAccount, :count)

      expect(target.reload).to be_persisted
    end

    it 'returns the updated channel' do
      delete "/api/v1/social_accounts/#{account.id}", headers: auth_headers_for(user), as: :json

      expect(json_body['social_account']).to include('id' => account.id, 'status' => 'revoked')
    end

    it 'returns 404 for another user\'s channel' do
      other = create(:social_account)

      delete "/api/v1/social_accounts/#{other.id}", headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:not_found)
      expect(other.reload).to be_status_active
    end

    it 'returns 404 for an unknown id' do
      delete '/api/v1/social_accounts/999999', headers: auth_headers_for(user), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 401 without a token' do
      delete "/api/v1/social_accounts/#{account.id}", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
