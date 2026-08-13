require 'rails_helper'

RSpec.describe SocialAccount, type: :model do
  describe 'associations' do
    it 'belongs to a user' do
      expect(build(:social_account).user).to be_a(User)
    end

    it 'requires a user' do
      account = build(:social_account, user: nil)

      expect(account).not_to be_valid
      expect(account.errors[:user]).to include('must exist')
    end

    it 'has many post targets' do
      account = create(:social_account)
      target = create(:post_target, social_account: account)

      expect(account.post_targets).to contain_exactly(target)
    end

    it 'has many posts through post targets' do
      account = create(:social_account)
      post = create(:post)
      create(:post_target, social_account: account, post: post)

      expect(account.posts).to contain_exactly(post)
    end

    it 'destroys its post targets when destroyed' do
      account = create(:social_account)
      create(:post_target, social_account: account)

      expect { account.destroy }.to change(PostTarget, :count).by(-1)
    end

    it 'is destroyed along with its user' do
      user = create(:user)
      create(:social_account, user: user)

      expect { user.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe 'validations' do
    it 'is valid with the factory attributes' do
      expect(build(:social_account)).to be_valid
    end

    it 'requires an external_account_id' do
      account = build(:social_account, external_account_id: nil)

      expect(account).not_to be_valid
      expect(account.errors[:external_account_id]).to include("can't be blank")
    end

    it 'rejects the same external account twice for one user and platform' do
      existing = create(:social_account)
      duplicate = build(:social_account,
                        user: existing.user,
                        platform: existing.platform,
                        external_account_id: existing.external_account_id)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_account_id]).to include('has already been taken')
    end

    it 'allows the same external account id on a different platform' do
      existing = create(:social_account, platform: :twitter)
      other = build(:social_account,
                    user: existing.user,
                    platform: :linkedin,
                    external_account_id: existing.external_account_id)

      expect(other).to be_valid
    end

    it 'allows two different users to connect the same external account' do
      existing = create(:social_account)
      other = build(:social_account,
                    platform: existing.platform,
                    external_account_id: existing.external_account_id)

      expect(other).to be_valid
    end

    it 'enforces uniqueness at the database level' do
      existing = create(:social_account)
      duplicate = build(:social_account,
                        user: existing.user,
                        platform: existing.platform,
                        external_account_id: existing.external_account_id)

      expect { duplicate.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'rejects a platform outside the enum' do
      expect { build(:social_account, platform: :myspace) }
        .to raise_error(ArgumentError, /not a valid platform/)
    end
  end

  describe 'enums' do
    it 'defines every supported platform' do
      expect(described_class.platforms.keys)
        .to eq(%w[twitter linkedin facebook instagram tiktok])
    end

    it 'defines every connection status' do
      expect(described_class.statuses.keys).to eq(%w[active expired revoked error])
    end

    it 'defaults to active' do
      expect(described_class.new.status).to eq('active')
    end
  end

  describe 'token encryption' do
    it 'round-trips the access token through the model' do
      account = create(:social_account, access_token: 'super-secret-token')

      expect(account.reload.access_token).to eq('super-secret-token')
    end

    it 'does not store the access token as plaintext' do
      account = create(:social_account, access_token: 'super-secret-token')
      raw = described_class.connection.select_value(
        "SELECT access_token FROM social_accounts WHERE id = #{account.id}"
      )

      expect(raw).not_to include('super-secret-token')
      expect(raw).to include('"p":') # Active Record Encryption envelope
    end

    it 'does not store the refresh token as plaintext' do
      account = create(:social_account, refresh_token: 'super-secret-refresh')
      raw = described_class.connection.select_value(
        "SELECT refresh_token FROM social_accounts WHERE id = #{account.id}"
      )

      expect(raw).not_to include('super-secret-refresh')
    end
  end

  describe '#token_expired?' do
    it 'is true once the expiry has passed' do
      expect(build(:social_account, expires_at: 1.minute.ago)).to be_token_expired
    end

    it 'is false while the expiry is in the future' do
      expect(build(:social_account, expires_at: 1.hour.from_now)).not_to be_token_expired
    end

    it 'is false when no expiry was supplied' do
      # Facebook Page tokens are long-lived and arrive without one.
      expect(build(:social_account, :facebook_page)).not_to be_token_expired
    end
  end

  describe '#needs_refresh?' do
    it 'is true for an expired token that has a refresh token' do
      account = build(:social_account, expires_at: 1.minute.ago, refresh_token: 'refresh')

      expect(account).to be_needs_refresh
    end

    it 'is false when there is nothing to refresh with' do
      account = build(:social_account, expires_at: 1.minute.ago, refresh_token: nil)

      expect(account).not_to be_needs_refresh
    end
  end

  describe '.connected' do
    it 'returns only active accounts' do
      active = create(:social_account)
      create(:social_account, :expired)

      expect(described_class.connected).to contain_exactly(active)
    end
  end
end
