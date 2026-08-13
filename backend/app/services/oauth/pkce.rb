module Oauth
  # PKCE (RFC 7636) verifier/challenge pair.
  #
  # TikTok requires PKCE on its v2 authorization endpoint, and it is harmless
  # for the providers that merely tolerate it, so every provider uses it.
  class Pkce
    CHALLENGE_METHOD = "S256".freeze

    # RFC 7636 allows 43-128 characters; 64 random bytes lands comfortably inside
    # that once base64url-encoded.
    def self.generate_verifier
      SecureRandom.urlsafe_base64(64).tr("=", "")
    end

    def self.challenge_for(verifier)
      Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    end
  end
end
