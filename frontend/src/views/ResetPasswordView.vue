<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AuthCard from '@/components/AuthCard.vue'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

// The token arrives as a query param on the link sent by the Devise mailer.
const token = computed(() => route.query.token ?? '')

const password = ref('')
const passwordConfirmation = ref('')
const errors = ref([])
const notice = ref('')
const loading = ref(false)

async function onSubmit() {
  loading.value = true
  errors.value = []

  try {
    const data = await auth.resetPassword({
      token: token.value,
      password: password.value,
      passwordConfirmation: passwordConfirmation.value
    })
    notice.value = data.message
    setTimeout(() => router.push({ name: 'login' }), 1500)
  } catch (error) {
    errors.value = error.messages ?? ['Unable to reset your password.']
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Choose a new password" subtitle="Enter a new password for your account.">
    <div v-if="!token" class="alert-error">
      This reset link is missing its token. Please request a new one.
    </div>

    <div v-if="notice" class="alert-success">{{ notice }}</div>

    <div v-if="errors.length" class="alert-error">
      <ul class="list-inside list-disc space-y-1">
        <li v-for="message in errors" :key="message">{{ message }}</li>
      </ul>
    </div>

    <form v-if="token" class="space-y-4" @submit.prevent="onSubmit">
      <div>
        <label class="field-label" for="password">New password</label>
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
        <label class="field-label" for="password-confirmation">Confirm new password</label>
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
        {{ loading ? 'Updating...' : 'Update password' }}
      </button>
    </form>

    <template #footer>
      <RouterLink to="/forgot-password" class="text-brand hover:underline">
        Request a new link
      </RouterLink>
    </template>
  </AuthCard>
</template>
