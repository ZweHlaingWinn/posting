<script setup>
import { RouterLink } from 'vue-router'
import ChannelAvatar from './ChannelAvatar.vue'
import { useChannelsStore } from '@/stores/channels'

const channels = useChannelsStore()
</script>

<template>
  <div class="flex items-center gap-3">
    <div v-if="channels.loading" class="flex gap-2">
      <span v-for="n in 3" :key="n" class="size-10 animate-pulse rounded-full bg-surface-raised" />
    </div>

    <template v-else>
      <ChannelAvatar
        v-for="account in channels.accounts"
        :key="account.id"
        :platform="account.platform"
        :username="account.external_username"
        :muted="account.status !== 'active'"
      />

      <RouterLink
        to="/settings/accounts"
        class="grid size-10 place-items-center rounded-full border border-dashed border-edge-strong text-lg text-ink-muted transition-colors hover:border-brand hover:text-brand"
        title="Add a channel"
      >
        +
      </RouterLink>
    </template>
  </div>
</template>
