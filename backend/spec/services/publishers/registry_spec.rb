require 'rails_helper'

RSpec.describe Publishers::Registry do
  describe '.adapter_class' do
    {
      'twitter' => Publishers::TwitterPublisher,
      'linkedin' => Publishers::LinkedinPublisher,
      'facebook' => Publishers::FacebookPublisher,
      'instagram' => Publishers::InstagramPublisher,
      'tiktok' => Publishers::TiktokPublisher
    }.each do |platform, expected_class|
      it "maps #{platform} to #{expected_class}" do
        expect(described_class.adapter_class(platform)).to eq(expected_class)
      end
    end

    it 'accepts a symbol' do
      expect(described_class.adapter_class(:tiktok)).to eq(Publishers::TiktokPublisher)
    end

    it 'raises for an unknown platform' do
      expect { described_class.adapter_class('myspace') }
        .to raise_error(Publishers::UnsupportedPlatformError, /myspace/)
    end
  end

  describe '.for' do
    it 'returns an adapter bound to the account' do
      account = create(:social_account, :tiktok)
      adapter = described_class.for(account)

      expect(adapter).to be_a(Publishers::TiktokPublisher)
      expect(adapter.social_account).to eq(account)
    end

    it 'resolves every platform the SocialAccount enum allows' do
      # Guards against the enum and the registry drifting apart.
      expect(described_class.supported_platforms).to match_array(SocialAccount.platforms.keys)
    end
  end

  describe '.implemented_platforms' do
    it 'reports none while every adapter is still a stub' do
      expect(described_class.implemented_platforms).to be_empty
    end

    it 'reflects an adapter that reports itself implemented' do
      allow(Publishers::TiktokPublisher).to receive(:implemented?).and_return(true)

      expect(described_class.implemented_platforms).to eq(['tiktok'])
      expect(described_class).to be_implemented('tiktok')
    end
  end
end
