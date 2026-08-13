<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()
const loading = ref(false)

async function onLogout() {
  loading.value = true

  try {
    await auth.logout()
  } finally {
    router.push({ name: 'login' })
  }
}
</script>

<template>
  <header class="app-header">
    <span class="brand">Social Scheduler</span>
    <button class="btn btn-secondary" :disabled="loading" @click="onLogout">
      {{ loading ? 'Signing out...' : 'Sign out' }}
    </button>
  </header>

  <main class="app-main">
    <h1>Dashboard</h1>
    <p>Signed in as {{ auth.user?.email }}.</p>
    <p class="subtitle">
      Connecting social accounts and scheduling posts arrive in the next phase.
    </p>
  </main>
</template>
