<script setup>
import { RouterLink, useRoute } from 'vue-router'
import { useRouter } from 'vue-router'
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()
const signingOut = ref(false)

// `available: false` renders the item as a disabled preview of a later phase,
// which is more honest than a link to an empty page.
const navigation = [
  { name: 'Launches', to: '/launches', icon: 'calendar', available: true },
  { name: 'Analytics', to: '/analytics', icon: 'chart', available: false },
  { name: 'Settings', to: '/settings/accounts', icon: 'cog', available: true }
]

function isActive(item) {
  return route.path.startsWith(item.to)
}

async function onSignOut() {
  signingOut.value = true

  try {
    await auth.logout()
  } finally {
    router.push({ name: 'login' })
  }
}
</script>

<template>
  <aside class="flex w-60 shrink-0 flex-col border-r border-edge bg-surface">
    <div class="flex items-center gap-2.5 px-5 py-5">
      <span class="grid size-8 place-items-center rounded-lg bg-brand text-sm font-bold text-white">
        S
      </span>
      <span class="text-[15px] font-semibold tracking-tight">Scheduler</span>
    </div>

    <nav class="flex flex-1 flex-col gap-1 px-3">
      <template v-for="item in navigation" :key="item.name">
        <RouterLink
          v-if="item.available"
          :to="item.to"
          class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors"
          :class="
            isActive(item)
              ? 'bg-brand-soft text-ink'
              : 'text-ink-muted hover:bg-surface-raised hover:text-ink'
          "
        >
          <span class="size-1.5 rounded-full" :class="isActive(item) ? 'bg-brand' : 'bg-edge-strong'" />
          {{ item.name }}
        </RouterLink>

        <span
          v-else
          class="flex cursor-not-allowed items-center justify-between rounded-lg px-3 py-2.5 text-sm font-medium text-ink-faint"
          title="Arrives in a later phase"
        >
          <span class="flex items-center gap-3">
            <span class="size-1.5 rounded-full bg-edge" />
            {{ item.name }}
          </span>
          <span class="rounded bg-surface-raised px-1.5 py-0.5 text-[10px] uppercase tracking-wide">
            soon
          </span>
        </span>
      </template>
    </nav>

    <div class="border-t border-edge p-3">
      <p class="truncate px-3 pb-2 text-xs text-ink-faint" :title="auth.user?.email">
        {{ auth.user?.email }}
      </p>
      <button class="btn-secondary w-full" :disabled="signingOut" @click="onSignOut">
        {{ signingOut ? 'Signing out...' : 'Sign out' }}
      </button>
    </div>
  </aside>
</template>
