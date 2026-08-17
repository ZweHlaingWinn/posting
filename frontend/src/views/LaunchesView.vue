<script setup>
import { RouterLink } from 'vue-router'
import ChannelStrip from '@/components/ChannelStrip.vue'
import { useChannelsStore } from '@/stores/channels'

const channels = useChannelsStore()
</script>

<template>
  <div class="flex min-h-full flex-col">
    <header class="flex items-center justify-between border-b border-edge px-8 py-4">
      <div>
        <h1 class="text-lg font-semibold tracking-tight">Launches</h1>
        <p class="text-xs text-ink-muted">Schedule and track what goes out.</p>
      </div>

      <div class="flex items-center gap-5">
        <ChannelStrip />
        <button class="btn-primary" disabled title="Arrives with the composer">
          Create post
        </button>
      </div>
    </header>

    <div class="flex flex-1 items-center justify-center p-8">
      <div class="card max-w-md p-8 text-center">
        <h2 class="text-base font-semibold">The calendar lands in the next slice</h2>

        <p class="mt-2 text-sm text-ink-muted">
          Channels are wired up end to end. The month and week calendar, plus the post composer,
          come next once the posts API exists.
        </p>

        <RouterLink
          v-if="channels.activeAccounts.length === 0"
          to="/settings/accounts"
          class="btn-primary mt-6"
        >
          Connect your first channel
        </RouterLink>

        <p v-else class="mt-6 text-sm text-ink-faint">
          {{ channels.activeAccounts.length }} channel(s) connected and ready.
        </p>
      </div>
    </div>
  </div>
</template>
