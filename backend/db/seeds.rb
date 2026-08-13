# Seed data. Idempotent: running `bin/rails db:seed` repeatedly is safe.
#
# The development account below is a convenience for local work only. It is
# skipped outside development so a well-known password can never reach a
# deployed environment.

if Rails.env.development?
  email = ENV.fetch("SEED_USER_EMAIL", "dev@example.com")
  password = ENV.fetch("SEED_USER_PASSWORD", "password123")

  user = User.find_or_initialize_by(email: email)

  if user.new_record?
    user.password = password
    user.password_confirmation = password
    user.save!
    puts "Created development user: #{email}"
  else
    puts "Development user already exists: #{email}"
  end
else
  puts "Skipping development user seed in #{Rails.env}."
end
