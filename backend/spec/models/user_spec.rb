require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with an email and password' do
      expect(build(:user)).to be_valid
    end

    it 'requires an email' do
      user = build(:user, email: nil)

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'rejects a malformed email' do
      user = build(:user, email: 'not-an-email')

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'requires the email to be unique' do
      create(:user, email: 'taken@example.com')
      user = build(:user, email: 'taken@example.com')

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'treats emails as case insensitive' do
      create(:user, email: 'taken@example.com')
      user = build(:user, email: 'TAKEN@example.com')

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    it 'requires a password' do
      user = build(:user, password: nil, password_confirmation: nil)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    it 'rejects a password shorter than the Devise minimum' do
      user = build(:user, password: 'short', password_confirmation: 'short')

      expect(user).not_to be_valid
      expect(user.errors[:password]).to include(
        "is too short (minimum is #{Devise.password_length.min} characters)"
      )
    end

    it 'requires the password confirmation to match' do
      user = build(:user, password: 'password123', password_confirmation: 'different123')

      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end

  describe 'devise modules' do
    it 'enables the modules this phase depends on' do
      expect(described_class.devise_modules).to include(
        :database_authenticatable, :registerable, :recoverable, :validatable, :jwt_authenticatable
      )
    end

    it 'stores the password as a bcrypt digest rather than plaintext' do
      user = create(:user, password: 'password123', password_confirmation: 'password123')

      expect(user.encrypted_password).not_to eq('password123')
      expect(user.valid_password?('password123')).to be(true)
      expect(user.valid_password?('wrong-password')).to be(false)
    end
  end

  describe 'jti (JWT revocation)' do
    it 'assigns a jti on create' do
      expect(create(:user).jti).to be_present
    end

    it 'assigns a distinct jti to each user' do
      expect(create(:user).jti).not_to eq(create(:user).jti)
    end

    it 'rejects a duplicate jti at the database level' do
      existing = create(:user)
      other = create(:user)

      # update_column skips the before_create hook that would otherwise assign a
      # fresh uuid, so this reaches the unique index.
      expect { other.update_column(:jti, existing.jti) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'considers a payload revoked once the jti no longer matches' do
      user = create(:user)
      payload = { 'jti' => user.jti }

      expect(described_class.jwt_revoked?(payload, user)).to be(false)

      described_class.revoke_jwt(nil, user)

      expect(described_class.jwt_revoked?(payload, user.reload)).to be(true)
    end
  end
end
