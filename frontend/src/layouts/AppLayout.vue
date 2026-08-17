<script setup>
import { ref, onMounted } from 'vue'
import { RouterView, useRoute, useRouter } from 'vue-router'
import AppSidebar from '@/components/AppSidebar.vue'
import { useChannelsStore } from '@/stores/channels'

const channels = useChannelsStore()
const route = useRoute()
const router = useRouter()

const notice = ref('')
const error = ref('')

// Loaded once for the whole authenticated shell; the channel strip and the
// settings page share this store rather than each fetching.
onMounted(() => {
  channels.load()

  // The backend OAuth callback redirects here (see CallbacksController) with
  // the outcome in the query string, since it is a browser navigation.
  if (route.query.connected) {
    notice.value = `${route.query.connected} connected successfully.`
  }

  if (route.query.connect_error) {
    error.value = String(route.query.connect_error)
  }

  if (route.query.connected || route.query.connect_error) {
    router.replace({ path: route.path })
  }
})
</script>

<template>
  <div class="flex h-full">
    <AppSidebar />
    <div class="flex min-w-0 flex-1 flex-col overflow-y-auto">
      <div v-if="notice" class="alert-success mx-8 mt-4">{{ notice }}</div>
      <div v-if="error" class="alert-error mx-8 mt-4">{{ error }}</div>
      <RouterView />
    </div>
  </div>
</template>
