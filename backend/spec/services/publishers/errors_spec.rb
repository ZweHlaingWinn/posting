require 'rails_helper'

RSpec.describe Publishers::PublishError do
  it 'carries the platform and message' do
    error = described_class.new('Rate limited', platform: 'tiktok')

    expect(error.message).to eq('Rate limited')
    expect(error.platform).to eq('tiktok')
  end

  it 'is not retryable by default' do
    expect(described_class.new('Caption rejected')).not_to be_retryable
  end

  it 'can be marked retryable for transient failures' do
    expect(described_class.new('502 from upstream', retryable: true)).to be_retryable
  end

  it 'is rescuable as a StandardError' do
    expect(described_class.new('boom')).to be_a(StandardError)
  end

  describe 'subclasses' do
    [
      Publishers::TokenRefreshError,
      Publishers::UnsupportedPlatformError,
      Publishers::NotImplementedForPlatformError
    ].each do |subclass|
      it "#{subclass} is rescuable as a PublishError" do
        expect(subclass.new('boom')).to be_a(described_class)
      end
    end
  end
end
