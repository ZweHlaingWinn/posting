module Auth
  # Wraps Warden::JWTAuth so the rest of the app never talks to it directly.
  #
  # Tokens are minted here rather than by devise-jwt's request hooks, which keeps
  # issuing explicit and testable (see config/initializers/devise.rb, where
  # dispatch_requests is intentionally empty).
  class TokenIssuer
    SCOPE = :user

    def self.issue_for(user)
      token, _payload = Warden::JWTAuth::UserEncoder.new.call(user, SCOPE, nil)
      token
    end

    # Rotates the user's jti, which invalidates every token previously issued to
    # them. Used on logout and after a password reset.
    def self.revoke_all_for(user)
      user.class.revoke_jwt(nil, user)
    end
  end
end
