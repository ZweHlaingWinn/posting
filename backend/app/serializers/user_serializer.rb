# Plain-Ruby presenter for the User resource. Deliberately allowlists fields so
# that adding a column never silently widens the API surface.
class UserSerializer
  def self.call(user)
    {
      id: user.id,
      email: user.email,
      created_at: user.created_at&.iso8601
    }
  end
end
