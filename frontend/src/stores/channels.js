import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import channelsApi from '@/api/channels'

export const useChannelsStore = defineStore('channels', () => {
  const accounts = ref([])
  const platforms = ref([])
  const loading = ref(false)
  const errors = ref([])

  // Revoked channels stay in the list so publishing history survives, but they
  // are not usable until reconnected.
  const activeAccounts = computed(() => accounts.value.filter((a) => a.status === 'active'))

  const connectablePlatforms = computed(() => platforms.value.filter((p) => p.connectable))

  function platformById(id) {
    return platforms.value.find((p) => p.id === id)
  }

  async function load() {
    loading.value = true
    errors.value = []

    try {
      const [accountsResponse, platformsResponse] = await Promise.all([
        channelsApi.list(),
        channelsApi.platforms()
      ])
      accounts.value = accountsResponse.data.social_accounts
      platforms.value = platformsResponse.data.platforms
    } catch (error) {
      errors.value = error.messages ?? ['Could not load your channels.']
    } finally {
      loading.value = false
    }
  }

  // Hands off to the provider. The browser leaves the SPA here and returns to
  // /launches via the backend callback.
  async function connect(platform) {
    const { data } = await channelsApi.startConnect(platform)
    window.location.assign(data.authorization_url)
  }

  async function disconnect(id) {
    const { data } = await channelsApi.disconnect(id)
    const index = accounts.value.findIndex((a) => a.id === id)

    if (index !== -1) {
      accounts.value[index] = data.social_account
    }
  }

  return {
    accounts,
    platforms,
    loading,
    errors,
    activeAccounts,
    connectablePlatforms,
    platformById,
    load,
    connect,
    disconnect
  }
})
