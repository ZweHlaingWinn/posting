require 'rails_helper'

RSpec.describe Oauth::StateToken do
  let(:user) { create(:user) }
  let(:verifier) { 'a-code-verifier' }

  def encode
    described_class.encode(user_id: user.id, platform: 'tiktok', code_verifier: verifier)
  end

  describe 'round trip' do
    it 'recovers the payload it encoded' do
      expect(described_class.decode(encode)).to eq(
        user_id: user.id, platform: 'tiktok', code_verifier: verifier
      )
    end

    it 'produces a different token each time for the same input' do
      expect(encode).not_to eq(encode)
    end
  end

  describe 'confidentiality' do
    it 'does not leak the PKCE verifier into the token' do
      # The state travels to the provider and back, so the verifier must not be
      # readable from it.
      expect(encode).not_to include(verifier)
    end

    it 'does not leak the user id into the token' do
      expect(encode).not_to include(user.id.to_s)
    end
  end

  describe 'tamper resistance' do
    it 'rejects a modified token' do
      tampered = "#{encode.chop}X"

      expect { described_class.decode(tampered) }
        .to raise_error(described_class::InvalidStateError)
    end

    it 'rejects arbitrary text' do
      expect { described_class.decode('not-a-real-state') }
        .to raise_error(described_class::InvalidStateError)
    end

    it 'rejects a blank state' do
      expect { described_class.decode('') }
        .to raise_error(described_class::InvalidStateError, /missing/)
    end

    it 'rejects a nil state' do
      expect { described_class.decode(nil) }
        .to raise_error(described_class::InvalidStateError, /missing/)
    end
  end

  describe 'expiry' do
    it 'accepts a token inside the window' do
      state = encode

      travel_to(described_class::EXPIRY.from_now - 1.minute) do
        expect(described_class.decode(state)[:user_id]).to eq(user.id)
      end
    end

    it 'rejects a token past the window' do
      state = encode

      travel_to(described_class::EXPIRY.from_now + 1.minute) do
        expect { described_class.decode(state) }
          .to raise_error(described_class::InvalidStateError, /expired/)
      end
    end
  end
end
