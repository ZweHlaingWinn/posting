<script setup>
import { ref } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()

const email = ref('')
const password = ref('')
const passwordConfirmation = ref('')
const errors = ref([])
const loading = ref(false)

async function onSubmit() {
  loading.value = true
  errors.value = []

  try {
    await auth.signup({
      email: email.value,
      password: password.value,
      passwordConfirmation: passwordConfirmation.value
    })
    router.push({ name: 'dashboard' })
  } catch (error) {
    errors.value = error.messages ?? ['Unable to create your account.']
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="auth-layout">
    <div class="card">
      <h1>Create your account</h1>
      <p class="subtitle">Schedule and publish across every platform.</p>

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
            autocomplete="new-password"
            minlength="6"
            required
          />
        </div>

        <div class="field">
          <label for="password-confirmation">Confirm password</label>
          <input
            id="password-confirmation"
            v-model="passwordConfirmation"
            type="password"
            autocomplete="new-password"
            minlength="6"
            required
          />
        </div>

        <button class="btn" type="submit" :disabled="loading">
          {{ loading ? 'Creating account...' : 'Create account' }}
        </button>
      </form>

      <p class="form-footer">
        Already registered? <RouterLink to="/login">Sign in</RouterLink>
      </p>
    </div>
  </div>
</template>
