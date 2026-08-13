require 'rails_helper'

RSpec.describe PostTarget, type: :model do
  describe 'associations' do
    it 'belongs to a post' do
      expect(build(:post_target).post).to be_a(Post)
    end

    it 'belongs to a social account' do
      expect(build(:post_target).social_account).to be_a(SocialAccount)
    end

    it 'requires a post' do
      target = build(:post_target, post: nil)

      expect(target).not_to be_valid
      expect(target.errors[:post]).to include('must exist')
    end

    it 'requires a social account' do
      target = build(:post_target, social_account: nil)

      expect(target).not_to be_valid
      expect(target.errors[:social_account]).to include('must exist')
    end

    it 'has many analytics snapshots' do
      target = create(:post_target)
      snapshot = create(:analytics_snapshot, post_target: target)

      expect(target.analytics_snapshots).to contain_exactly(snapshot)
    end

    it 'destroys its snapshots when destroyed' do
      target = create(:post_target)
      create(:analytics_snapshot, post_target: target)

      expect { target.destroy }.to change(AnalyticsSnapshot, :count).by(-1)
    end
  end

  describe 'validations' do
    it 'is valid with the factory attributes' do
      expect(build(:post_target)).to be_valid
    end

    it 'rejects the same social account twice on one post' do
      existing = create(:post_target)
      duplicate = build(:post_target,
                        post: existing.post,
                        social_account: existing.social_account)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:social_account_id]).to include('has already been taken')
    end

    it 'enforces that uniqueness at the database level' do
      existing = create(:post_target)
      duplicate = build(:post_target,
                        post: existing.post,
                        social_account: existing.social_account)

      expect { duplicate.save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows one post to target several accounts' do
      existing = create(:post_target)
      other = build(:post_target, post: existing.post, social_account: create(:social_account))

      expect(other).to be_valid
    end

    it 'requires a platform_post_id once published' do
      target = build(:post_target, status: :published, platform_post_id: nil)

      expect(target).not_to be_valid
      expect(target.errors[:platform_post_id]).to include("can't be blank")
    end

    it 'does not require a platform_post_id while pending' do
      expect(build(:post_target, status: :pending, platform_post_id: nil)).to be_valid
    end
  end

  describe 'enums' do
    it 'defines every status' do
      expect(described_class.statuses.keys).to eq(%w[pending published failed])
    end

    it 'defaults to pending' do
      expect(described_class.new.status).to eq('pending')
    end
  end

  describe '#platform' do
    it 'delegates to the social account' do
      target = build(:post_target, social_account: build(:social_account, :tiktok))

      expect(target.platform).to eq('tiktok')
    end
  end

  describe '#mark_published!' do
    it 'records the platform id and clears any earlier error' do
      target = create(:post_target, :failed)

      target.mark_published!(platform_post_id: 'abc123')

      expect(target).to be_status_published
      expect(target.platform_post_id).to eq('abc123')
      expect(target.published_at).to be_present
      expect(target.error_message).to be_nil
    end
  end

  describe '#mark_failed!' do
    it 'records the failure message' do
      target = create(:post_target)

      target.mark_failed!('Token revoked')

      expect(target).to be_status_failed
      expect(target.error_message).to eq('Token revoked')
    end
  end

  describe '#latest_snapshot' do
    it 'returns the most recently fetched snapshot' do
      target = create(:post_target)
      create(:analytics_snapshot, post_target: target, fetched_at: 2.days.ago)
      newest = create(:analytics_snapshot, post_target: target, fetched_at: 1.hour.ago)

      expect(target.latest_snapshot).to eq(newest)
    end

    it 'returns nil before any metrics are fetched' do
      expect(create(:post_target).latest_snapshot).to be_nil
    end
  end

  describe '.awaiting_publish' do
    it 'returns only pending targets' do
      pending = create(:post_target)
      create(:post_target, :published)

      expect(described_class.awaiting_publish).to contain_exactly(pending)
    end
  end
end
