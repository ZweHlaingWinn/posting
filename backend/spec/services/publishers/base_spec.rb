require 'rails_helper'

RSpec.describe Publishers::Base do
  let(:social_account) { create(:social_account) }
  let(:post) { create(:post) }
  let(:post_target) { create(:post_target, post: post, social_account: social_account) }

  describe 'the adapter contract' do
    it 'exposes the account it was built for' do
      expect(described_class.new(social_account).social_account).to eq(social_account)
    end

    it 'raises NotImplementedError from #publish until a subclass overrides it' do
      expect { described_class.new(social_account).publish(post, post_target) }
        .to raise_error(NotImplementedError, /must implement #publish/)
    end

    it 'raises NotImplementedError from #fetch_metrics until a subclass overrides it' do
      expect { described_class.new(social_account).fetch_metrics(post_target) }
        .to raise_error(NotImplementedError, /must implement #fetch_metrics/)
    end

    it 'is inherited by every registered adapter' do
      Publishers::Registry.supported_platforms.each do |platform|
        expect(Publishers::Registry.adapter_class(platform).ancestors).to include(described_class)
      end
    end
  end

  describe '#ensure_usable_token!' do
    it 'does nothing while the token is still valid' do
      account = create(:social_account, expires_at: 1.hour.from_now)

      expect { described_class.new(account).ensure_usable_token! }.not_to raise_error
    end

    it 'does nothing when the platform issued no expiry' do
      # Facebook Page tokens never expire.
      account = create(:social_account, :facebook_page)

      expect { described_class.new(account).ensure_usable_token! }.not_to raise_error
    end

    it 'delegates to the subclass when the token can be refreshed' do
      account = create(:social_account, expires_at: 1.minute.ago, refresh_token: 'refresh')
      adapter = described_class.new(account)

      expect(adapter).to receive(:refresh_token!)

      adapter.ensure_usable_token!
    end

    it 'raises TokenRefreshError when there is no refresh token' do
      account = create(:social_account, expires_at: 1.minute.ago, refresh_token: nil)

      expect { described_class.new(account).ensure_usable_token! }
        .to raise_error(Publishers::TokenRefreshError, /must be reconnected/)
    end

    it 'marks the account expired when it cannot be refreshed' do
      account = create(:social_account, expires_at: 1.minute.ago, refresh_token: nil)

      expect { described_class.new(account).ensure_usable_token! }
        .to raise_error(Publishers::TokenRefreshError)

      expect(account.reload).to be_status_expired
    end

    it 'runs before publishing' do
      adapter = described_class.new(social_account)
      allow(adapter).to receive(:perform_publish)

      expect(adapter).to receive(:ensure_usable_token!)

      adapter.publish(post, post_target)
    end

    it 'runs before fetching metrics' do
      adapter = described_class.new(social_account)
      allow(adapter).to receive(:perform_fetch_metrics)

      expect(adapter).to receive(:ensure_usable_token!)

      adapter.fetch_metrics(post_target)
    end
  end

  describe '.platform_name' do
    it 'derives a readable name from the class' do
      expect(Publishers::TiktokPublisher.platform_name).to eq('tiktok')
      expect(Publishers::LinkedinPublisher.platform_name).to eq('linkedin')
    end
  end

  describe '.implemented?' do
    it 'is false for the base class' do
      expect(described_class).not_to be_implemented
    end

    it 'is false for the adapters that are still stubs' do
      (Publishers::Registry.supported_platforms - ['tiktok']).each do |platform|
        expect(Publishers::Registry.adapter_class(platform)).not_to be_implemented
      end
    end

    it 'is true for the adapters that are built' do
      expect(Publishers::TiktokPublisher).to be_implemented
    end
  end

  describe '.requires_media?' do
    it 'is false unless an adapter opts in' do
      expect(described_class).not_to be_requires_media
      expect(Publishers::TwitterPublisher).not_to be_requires_media
    end

    it 'is true for TikTok, which refuses a text-only post' do
      expect(Publishers::TiktokPublisher).to be_requires_media
    end
  end
end
