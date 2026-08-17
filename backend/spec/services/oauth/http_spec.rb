require 'rails_helper'

RSpec.describe Oauth::Http do
  it 'loads Net::HTTP so production token requests do not NameError' do
    expect(described_class::TIMEOUT).to eq(15)
    expect(defined?(Net::HTTP)).to eq('constant')
    expect { Net::HTTP::Post.new(URI.parse('https://example.com/')) }.not_to raise_error
  end
end
