import client from './client'

// Publishing runs inside the request: the backend uploads the video file (or
// downloads it from a URL) and streams it to the platform before responding.
// That is far slower than the 15s default the client is built with.
const PUBLISH_TIMEOUT = 180000

function toFormData(attributes) {
  const form = new FormData()
  const { video, media_urls, social_account_ids, ...scalars } = attributes

  Object.entries(scalars).forEach(([key, value]) => {
    if (value === undefined || value === null) return
    form.append(`post[${key}]`, value)
  })

  social_account_ids?.forEach((id) => {
    form.append('post[social_account_ids][]', id)
  })

  media_urls?.forEach((url) => {
    form.append('post[media_urls][]', url)
  })

  if (video) {
    form.append('post[video]', video)
  }

  return form
}

export default {
  list() {
    return client.get('/posts')
  },

  get(id) {
    return client.get(`/posts/${id}`)
  },

  create(attributes) {
    const hasFile = attributes.video instanceof File
    const payload = hasFile ? toFormData(attributes) : { post: attributes }

    return client.post(
      '/posts',
      payload,
      attributes.publish_now || hasFile ? { timeout: PUBLISH_TIMEOUT } : {}
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
