require 'rails_helper'

RSpec.describe Oauth::Pkce do
  describe '.generate_verifier' do
    it 'produces a verifier within the length RFC 7636 allows' do
      expect(described_class.generate_verifier.length).to be_between(43, 128)
    end

    it 'uses only unreserved URL characters' do
      expect(described_class.generate_verifier).to match(/\A[A-Za-z0-9\-._~]+\z/)
    end

    it 'produces a different verifier each time' do
      expect(described_class.generate_verifier).not_to eq(described_class.generate_verifier)
    end
  end

  describe '.challenge_for' do
    it 'is the base64url-encoded SHA256 of the verifier, unpadded' do
      verifier = 'test-verifier'
      expected = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)

      expect(described_class.challenge_for(verifier)).to eq(expected)
    end

    it 'is deterministic for a given verifier' do
      verifier = described_class.generate_verifier

      expect(described_class.challenge_for(verifier))
        .to eq(described_class.challenge_for(verifier))
    end

    it 'is not the verifier itself' do
      verifier = described_class.generate_verifier

      expect(described_class.challenge_for(verifier)).not_to eq(verifier)
    end
  end
end
