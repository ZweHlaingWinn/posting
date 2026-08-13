import client from './client'

// Thin mapping of the Api::V1 auth endpoints. Every payload is wrapped in a
// `user` key to match the Rails strong parameters.
export default {
  signup({ email, password, passwordConfirmation }) {
    return client.post('/auth/signup', {
      user: { email, password, password_confirmation: passwordConfirmation }
    })
  },

  login({ email, password }) {
    return client.post('/auth/login', { user: { email, password } })
  },

  logout() {
    return client.delete('/auth/logout')
  },

  requestPasswordReset({ email }) {
    return client.post('/auth/password', { user: { email } })
  },

  resetPassword({ token, password, passwordConfirmation }) {
    return client.put('/auth/password', {
      user: {
        reset_password_token: token,
        password,
        password_confirmation: passwordConfirmation
      }
    })
  }
}
