import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import postsApi from '@/api/posts'

export const usePostsStore = defineStore('posts', () => {
  const posts = ref([])
  const loading = ref(false)
  const errors = ref([])

  const drafts = computed(() => posts.value.filter((p) => p.status === 'draft'))
  const published = computed(() => posts.value.filter((p) => p.status === 'published'))
  const failed = computed(() => posts.value.filter((p) => p.status === 'failed'))

  async function load() {
    loading.value = true
    errors.value = []

    try {
      const { data } = await postsApi.list()
      posts.value = data.posts
    } catch (error) {
      errors.value = error.messages ?? ['Could not load your posts.']
    } finally {
      loading.value = false
    }
  }

  async function create(attributes) {
    const { data } = await postsApi.create(attributes)
    posts.value.unshift(data.post)

    return data.post
  }

  async function publish(id) {
    const { data } = await postsApi.publish(id)
    replace(data.post)

    return data.post
  }

  async function remove(id) {
    await postsApi.remove(id)
    posts.value = posts.value.filter((p) => p.id !== id)
  }

  function replace(post) {
    const index = posts.value.findIndex((p) => p.id === post.id)

    if (index === -1) {
      posts.value.unshift(post)
    } else {
      posts.value[index] = post
    }
  }

  return {
    posts,
    loading,
    errors,
    drafts,
    published,
    failed,
    load,
    create,
    publish,
    remove
  }
})
