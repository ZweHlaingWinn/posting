<script setup>
import { ref } from 'vue'
import { useRouter, useRoute, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AuthCard from '@/components/AuthCard.vue'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const email = ref('')
const password = ref('')
const errors = ref([])
const loading = ref(false)

// Set by the axios interceptor's redirect when a token is rejected mid-session.
const sessionExpired = ref(route.query.expired === '1')

async function onSubmit() {
  loading.value = true
  errors.value = []
  sessionExpired.value = false

  try {
    await auth.login({ email: email.value, password: password.value })
    router.push(route.query.redirect || { name: 'launches' })
  } catch (error) {
    errors.value = error.messages ?? ['Unable to sign in.']
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Welcome back" subtitle="Sign in to manage your scheduled posts.">
    <div v-if="sessionExpired" class="alert-error">
      Your session expired. Please sign in again.
    </div>

    <div v-if="errors.length" class="alert-error">
      <ul class="list-inside list-disc space-y-1">
        <li v-for="message in errors" :key="message">{{ message }}</li>
      </ul>
    </div>

    <form class="space-y-4" @submit.prevent="onSubmit">
      <div>
        <label class="field-label" for="email">Email</label>
        <input id="email" v-model="email" class="field-input" type="email" autocomplete="email" required />
      </div>

      <div>
        <label class="field-label" for="password">Password</label>
        <input
          id="password"
          v-model="password"
          class="field-input"
          type="password"
          autocomplete="current-password"
          required
        />
      </div>

      <button class="btn-primary w-full" type="submit" :disabled="loading">
        {{ loading ? 'Signing in...' : 'Sign in' }}
      </button>
    </form>

    <p class="mt-4 text-center text-[13px]">
      <RouterLink to="/forgot-password" class="text-brand hover:underline">
        Forgot your password?
      </RouterLink>
    </p>

    <template #footer>
      No account?
      <RouterLink to="/signup" class="text-brand hover:underline">Create one</RouterLink>
    </template>
  </AuthCard>
</template>
