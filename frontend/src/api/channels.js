import client from './client'

// Connected channels and the platforms they can be connected from.
export default {
  list() {
    return client.get('/social_accounts')
  },

  disconnect(id) {
    return client.delete(`/social_accounts/${id}`)
  },

  platforms() {
    return client.get('/platforms')
  },

  // Returns the provider URL to send the browser to; the backend mints the
  // PKCE challenge and signed state.
  startConnect(platform) {
    return client.post(`/oauth/${platform}/authorize`)
  }
}
