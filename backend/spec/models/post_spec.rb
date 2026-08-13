require 'rails_helper'

RSpec.describe Post, type: :model do
  describe 'associations' do
    it 'belongs to a user' do
      expect(build(:post).user).to be_a(User)
    end

    it 'requires a user' do
      post = build(:post, user: nil)

      expect(post).not_to be_valid
      expect(post.errors[:user]).to include('must exist')
    end

    it 'has many post targets' do
      post = create(:post)
      target = create(:post_target, post: post)

      expect(post.post_targets).to contain_exactly(target)
    end

    it 'has many social accounts through post targets' do
      post = create(:post)
      account = create(:social_account)
      create(:post_target, post: post, social_account: account)

      expect(post.social_accounts).to contain_exactly(account)
    end

    it 'destroys its post targets when destroyed' do
      post = create(:post)
      create(:post_target, post: post)

      expect { post.destroy }.to change(PostTarget, :count).by(-1)
    end

    it 'is destroyed along with its user' do
      user = create(:user)
      create(:post, user: user)

      expect { user.destroy }.to change(described_class, :count).by(-1)
    end
  end

  describe 'validations' do
    it 'is valid with the factory attributes' do
      expect(build(:post)).to be_valid
    end

    it 'requires content when no media is attached' do
      post = build(:post, content: nil, media_urls: [])

      expect(post).not_to be_valid
      expect(post.errors[:content]).to include("can't be blank")
    end

    it 'allows empty content when media is attached' do
      # TikTok and Instagram posts are media-only.
      expect(build(:post, :with_media)).to be_valid
    end

    it 'requires scheduled_at when the status is scheduled' do
      post = build(:post, status: :scheduled, scheduled_at: nil)

      expect(post).not_to be_valid
      expect(post.errors[:scheduled_at]).to include("can't be blank")
    end

    it 'rejects a scheduled_at in the past' do
      post = build(:post, status: :scheduled, scheduled_at: 1.hour.ago)

      expect(post).not_to be_valid
      expect(post.errors[:scheduled_at]).to include('must be in the future')
    end

    it 'accepts a scheduled_at in the future' do
      expect(build(:post, :scheduled)).to be_valid
    end

    it 'does not require scheduled_at for a draft' do
      expect(build(:post, status: :draft, scheduled_at: nil)).to be_valid
    end

    it 'leaves an already scheduled post valid once its time passes' do
      post = create(:post, :scheduled)

      travel_to(2.hours.from_now) do
        expect(post.reload).to be_valid
      end
    end

    it 'rejects a status outside the enum' do
      expect { build(:post, status: :cancelled) }
        .to raise_error(ArgumentError, /not a valid status/)
    end
  end

  describe 'enums' do
    it 'defines every status' do
      expect(described_class.statuses.keys).to eq(%w[draft scheduled published failed])
    end

    it 'defaults to draft' do
      expect(described_class.new.status).to eq('draft')
    end
  end

  describe 'media_urls' do
    it 'defaults to an empty array' do
      expect(described_class.new.media_urls).to eq([])
    end

    it 'persists an array of urls as jsonb' do
      urls = ['https://cdn.example.com/a.mp4', 'https://cdn.example.com/b.jpg']
      post = create(:post, media_urls: urls)

      expect(post.reload.media_urls).to eq(urls)
    end
  end

  describe '.due_for_publishing' do
    it 'returns scheduled posts whose time has arrived' do
      due = create(:post, :scheduled, scheduled_at: 30.minutes.from_now)
      create(:post, :scheduled, scheduled_at: 5.hours.from_now)
      create(:post, :published)

      travel_to(1.hour.from_now) do
        expect(described_class.due_for_publishing).to contain_exactly(due)
      end
    end

    it 'excludes drafts whose scheduled_at has passed' do
      create(:post, status: :draft, scheduled_at: 1.hour.from_now)

      travel_to(2.hours.from_now) do
        expect(described_class.due_for_publishing).to be_empty
      end
    end
  end
end
