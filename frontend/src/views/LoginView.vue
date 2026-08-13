<script setup>
import { ref } from 'vue'
import { useRouter, useRoute, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

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
    router.push(route.query.redirect || { name: 'dashboard' })
  } catch (error) {
    errors.value = error.messages ?? ['Unable to sign in.']
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-layout">
    <div class="card">
      <h1>Welcome back</h1>
      <p class="subtitle">Sign in to manage your scheduled posts.</p>

      <div v-if="sessionExpired" class="alert alert-error">
        Your session expired. Please sign in again.
      </div>

      <div v-if="errors.length" class="alert alert-error">
        <ul>
          <li v-for="message in errors" :key="message">{{ message }}</li>
        </ul>
      </div>

      <form @submit.prevent="onSubmit">
        <div class="field">
          <label for="email">Email</label>
          <input id="email" v-model="email" type="email" autocomplete="email" required />
        </div>

        <div class="field">
          <label for="password">Password</label>
          <input
            id="password"
            v-model="password"
            type="password"
            autocomplete="current-password"
            required
          />
        </div>

        <button class="btn" type="submit" :disabled="loading">
          {{ loading ? 'Signing in...' : 'Sign in' }}
        </button>
      </form>

      <p class="form-footer">
        <RouterLink to="/forgot-password">Forgot your password?</RouterLink>
      </p>
      <p class="form-footer">
        No account? <RouterLink to="/signup">Create one</RouterLink>
      </p>
    </div>
  </div>
</template>
