<script setup>
import { ref, computed } from 'vue'
import ChannelAvatar from '@/components/ChannelAvatar.vue'
import { useChannelsStore } from '@/stores/channels'

const channels = useChannelsStore()

const notice = ref('')
const error = ref('')
const busyPlatform = ref(null)
const disconnecting = ref(null)

const connectedPlatformIds = computed(() =>
  channels.accounts.filter((a) => a.status === 'active').map((a) => a.platform)
)

async function onConnect(platform) {
  busyPlatform.value = platform.id
  error.value = ''

  try {
    await channels.connect(platform.id)
  } catch (e) {
    error.value = e.messages?.[0] ?? `Could not start the ${platform.name} connection.`
    busyPlatform.value = null
  }
}

async function onDisconnect(account) {
  if (!window.confirm(`Disconnect ${account.external_username || account.platform}?`)) return

  disconnecting.value = account.id
  error.value = ''

  try {
    await channels.disconnect(account.id)
    notice.value = 'Channel disconnected. Its published history is kept.'
  } catch (e) {
    error.value = e.messages?.[0] ?? 'Could not disconnect that channel.'
  } finally {
    disconnecting.value = null
  }
}
</script>

<template>
  <div class="mx-auto w-full max-w-4xl px-8 py-8">
    <header class="mb-8">
      <h1 class="text-2xl font-semibold tracking-tight">Channels</h1>
      <p class="mt-1 text-sm text-ink-muted">
        Connect the accounts you want to publish to.
      </p>
    </header>

    <div v-if="notice" class="alert-success">{{ notice }}</div>
    <div v-if="error" class="alert-error">{{ error }}</div>
    <div v-if="channels.errors.length" class="alert-error">
      {{ channels.errors[0] }}
    </div>

    <section class="card mb-8 p-6">
      <h2 class="mb-4 text-sm font-semibold text-ink-muted">Connected</h2>

      <div v-if="channels.loading" class="space-y-3">
        <div v-for="n in 2" :key="n" class="h-14 animate-pulse rounded-xl bg-surface-raised" />
      </div>

      <p v-else-if="channels.accounts.length === 0" class="py-6 text-center text-sm text-ink-faint">
        No channels yet. Connect one below to get started.
      </p>

      <ul v-else class="divide-y divide-edge">
        <li
          v-for="account in channels.accounts"
          :key="account.id"
          class="flex items-center gap-4 py-3.5"
        >
          <ChannelAvatar
            :platform="account.platform"
            :username="account.external_username"
            :muted="account.status !== 'active'"
          />

          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-medium">
              {{ account.external_username || account.external_account_id }}
            </p>
            <p class="text-xs capitalize text-ink-faint">{{ account.platform }}</p>
          </div>

          <span
            class="rounded-full px-2.5 py-1 text-[11px] font-medium capitalize"
            :class="
              account.status === 'active'
                ? 'bg-positive/10 text-positive'
                : 'bg-surface-raised text-ink-faint'
            "
          >
            {{ account.status }}
          </span>

          <button
            v-if="account.status === 'active'"
            class="btn-danger px-3 py-1.5 text-xs"
            :disabled="disconnecting === account.id"
            @click="onDisconnect(account)"
          >
            {{ disconnecting === account.id ? 'Working...' : 'Disconnect' }}
          </button>
        </li>
      </ul>
    </section>

    <section class="card p-6">
      <h2 class="mb-4 text-sm font-semibold text-ink-muted">Add a channel</h2>

      <div class="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <button
          v-for="platform in channels.platforms"
          :key="platform.id"
          class="flex flex-col items-center gap-3 rounded-xl border border-edge bg-surface-raised p-5 transition-colors"
          :class="
            platform.connectable
              ? 'cursor-pointer hover:border-brand'
              : 'cursor-not-allowed opacity-50'
          "
          :disabled="!platform.connectable || busyPlatform === platform.id"
          :title="platform.connectable ? `Connect ${platform.name}` : 'Not available yet'"
          @click="onConnect(platform)"
        >
          <ChannelAvatar :platform="platform.id" size="lg" :muted="!platform.connectable" />
          <span class="text-sm font-medium">{{ platform.name }}</span>

          <span v-if="busyPlatform === platform.id" class="text-xs text-brand">
            Redirecting...
          </span>
          <span
            v-else-if="connectedPlatformIds.includes(platform.id)"
            class="text-xs text-ink-faint"
          >
            Add another
          </span>
          <span v-else-if="!platform.connectable" class="text-xs text-ink-faint">
            Not configured
          </span>
        </button>
      </div>

      <p class="mt-4 text-xs text-ink-faint">
        Platforms show as "Not configured" until their OAuth credentials are present in the
        backend environment.
      </p>
    </section>
  </div>
</template>
