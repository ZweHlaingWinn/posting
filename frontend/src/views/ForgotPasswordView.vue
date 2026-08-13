<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

const email = ref('')
const notice = ref('')
const errors = ref([])
const loading = ref(false)

async function onSubmit() {
  loading.value = true
  errors.value = []
  notice.value = ''

  try {
    // The API intentionally responds the same way whether or not the address is
    // registered, so this message is shown in both cases.
    const data = await auth.requestPasswordReset({ email: email.value })
    notice.value = data.message
  } catch (error) {
    errors.value = error.messages ?? ['Unable to send reset instructions.']
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-layout">
    <div class="card">
      <h1>Reset your password</h1>
      <p class="subtitle">We'll email you a link to choose a new one.</p>

      <div v-if="notice" class="alert alert-success">{{ notice }}</div>

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

        <button class="btn" type="submit" :disabled="loading">
          {{ loading ? 'Sending...' : 'Send reset link' }}
        </button>
      </form>

      <p class="form-footer">
        <RouterLink to="/login">Back to sign in</RouterLink>
      </p>
    </div>
  </div>
</template>
