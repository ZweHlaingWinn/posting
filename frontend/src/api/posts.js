import client from './client'

// Publishing runs inside the request: the backend downloads the video from the
// given URL and streams it to the platform before responding. That is far
// slower than the 15s default the client is built with.
const PUBLISH_TIMEOUT = 180000

export default {
  list() {
    return client.get('/posts')
  },

  get(id) {
    return client.get(`/posts/${id}`)
  },

  create(attributes) {
    return client.post(
      '/posts',
      { post: attributes },
      attributes.publish_now ? { timeout: PUBLISH_TIMEOUT } : {}
    )
  },

  update(id, attributes) {
    return client.patch(`/posts/${id}`, { post: attributes })
  },

  publish(id) {
    return client.post(`/posts/${id}/publish`, {}, { timeout: PUBLISH_TIMEOUT })
  },

  remove(id) {
    return client.delete(`/posts/${id}`)
  }
}
