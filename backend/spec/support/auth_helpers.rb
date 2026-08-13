module AuthHelpers
  # Builds the Authorization header a real client would send after logging in.
  def auth_headers_for(user)
    { "Authorization" => "Bearer #{Auth::TokenIssuer.issue_for(user)}" }
  end
end
