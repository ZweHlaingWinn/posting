<script setup>
import { ref } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AuthCard from '@/components/AuthCard.vue'

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
    router.push({ name: 'launches' })
  } catch (error) {
    errors.value = error.messages ?? ['Unable to create your account.']
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Create your account" subtitle="Schedule and publish across every platform.">
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
          autocomplete="new-password"
          minlength="6"
          required
        />
      </div>

      <div>
        <label class="field-label" for="password-confirmation">Confirm password</label>
        <input
          id="password-confirmation"
          v-model="passwordConfirmation"
          class="field-input"
          type="password"
          autocomplete="new-password"
          minlength="6"
          required
        />
      </div>

      <button class="btn-primary w-full" type="submit" :disabled="loading">
        {{ loading ? 'Creating account...' : 'Create account' }}
      </button>
    </form>

    <template #footer>
      Already registered?
      <RouterLink to="/login" class="text-brand hover:underline">Sign in</RouterLink>
    </template>
  </AuthCard>
</template>
