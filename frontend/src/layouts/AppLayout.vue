<script setup>
import { onMounted } from 'vue'
import { RouterView } from 'vue-router'
import AppSidebar from '@/components/AppSidebar.vue'
import { useChannelsStore } from '@/stores/channels'

const channels = useChannelsStore()

// Loaded once for the whole authenticated shell; the channel strip and the
// settings page share this store rather than each fetching.
onMounted(() => channels.load())
</script>

<template>
  <div class="flex h-full">
    <AppSidebar />
    <div class="flex min-w-0 flex-1 flex-col overflow-y-auto">
      <RouterView />
    </div>
  </div>
</template>
