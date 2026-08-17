require 'rails_helper'

RSpec.describe Oauth::HandleCallbackService do
  let(:user) { create(:user) }
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
      expires_at: 1.day.from_now,
      scopes: 'user.info.basic,video.upload'
    )
  end
  let(:provider) { instance_double(Oauth::Providers::Tiktok, exchange_code: credentials) }

  before { allow(Oauth::ProviderRegistry).to receive(:for).with('tiktok').and_return(provider) }

  def call(overrides = {})
    described_class.call(**{ platform: 'tiktok', code: 'the-code', state: state }.merge(overrides))
  end

  describe 'a successful connection' do
    it 'succeeds' do
      expect(call).to be_success
    end

    it 'creates a social account for the user in the state' do
      expect { call }.to change { user.social_accounts.count }.by(1)
    end

    it 'stores the identity and credentials' do
      call
      account = user.social_accounts.last

      expect(account.platform).to eq('tiktok')
      expect(account.external_account_id).to eq('open-id-123')
      expect(account.external_username).to eq('Creator Name')
      expect(account.access_token).to eq('access-token')
      expect(account.refresh_token).to eq('refresh-token')
      expect(account).to be_status_active
    end

    it 'passes the PKCE verifier from the state to the provider' do
      call

      expect(provider).to have_received(:exchange_code)
        .with(code: 'the-code', code_verifier: verifier)
    end

    it 'returns the account without exposing tokens' do
      payload = call.data[:social_account]

      expect(payload).to include(platform: 'tiktok', external_username: 'Creator Name')
      expect(payload.keys).not_to include(:access_token, :refresh_token)
    end
  end

  describe 'reconnecting an account that already exists' do
    before do
      create(:social_account, user: user, platform: :tiktok,
                              external_account_id: 'open-id-123',
                              access_token: 'stale-token', status: :revoked)
    end

    it 'updates the existing row instead of creating a duplicate' do
      expect { call }.not_to change { user.social_accounts.count }
    end

    it 'replaces the stored token' do
      call

      expect(user.social_accounts.last.access_token).to eq('access-token')
    end

    it 'returns the account to active' do
      call

      expect(user.social_accounts.last).to be_status_active
    end
  end

  describe 'failures' do
    it 'reports the provider error when the user cancels consent' do
      result = call(provider_error: 'access_denied')

      expect(result).to be_failure
      expect(result.errors).to eq(['access_denied'])
    end

    it 'fails when no code is present' do
      expect(call(code: nil)).to be_failure
    end

    it 'fails on a tampered state' do
      result = call(state: 'tampered-state')

      expect(result).to be_failure
      expect(result.errors.first).to match(/expired or invalid/)
    end

    it 'fails when the state was minted for a different platform' do
      other = Oauth::StateToken.encode(user_id: user.id, platform: 'facebook',
                                       code_verifier: verifier)
      result = call(state: other)

      expect(result).to be_failure
      expect(result.errors.first).to match(/does not match the requested platform/)
    end

    it 'fails when the user has since been deleted' do
      state_for_missing_user = Oauth::StateToken.encode(
        user_id: user.id, platform: 'tiktok', code_verifier: verifier
      )
      user.destroy

      expect(call(state: state_for_missing_user)).to be_failure
    end

    it 'fails when the provider rejects the code' do
      allow(provider).to receive(:exchange_code)
        .and_raise(Oauth::Providers::Base::AuthorizationError, 'code expired')

      result = call

      expect(result).to be_failure
      expect(result.errors).to eq(['code expired'])
    end

    it 'creates no account when the provider cannot identify it' do
      allow(provider).to receive(:exchange_code)
        .and_return(credentials.tap { |c| c.external_account_id = nil })

      expect { call }.not_to change(SocialAccount, :count)
      expect(call).to be_failure
    end

    it 'fails for a platform with no provider' do
      allow(Oauth::ProviderRegistry).to receive(:for).and_call_original
      unsupported = Oauth::StateToken.encode(user_id: user.id, platform: 'facebook',
                                             code_verifier: verifier)

      result = described_class.call(platform: 'facebook', code: 'c', state: unsupported)

      expect(result).to be_failure
      expect(result.errors.first).to match(/not supported yet/)
    end

    it 'surfaces the unexpected error so the UI can show what broke' do
      allow(provider).to receive(:exchange_code).and_raise(RuntimeError, 'encryption exploded')

      result = call

      expect(result).to be_failure
      expect(result.errors.first).to eq('encryption exploded')
    end

    it 'reports a clear error when token encryption is misconfigured' do
      allow_any_instance_of(SocialAccount).to receive(:save)
        .and_raise(ActiveRecord::Encryption::Errors::Configuration, 'Missing primary_key')

      result = call

      expect(result).to be_failure
      expect(result.errors.first).to include('AR_ENCRYPTION_PRIMARY_KEY')
    end
  end
end
