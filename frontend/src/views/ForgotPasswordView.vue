<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AuthCard from '@/components/AuthCard.vue'

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
  <AuthCard title="Reset your password" subtitle="We'll email you a link to choose a new one.">
    <div v-if="notice" class="alert-success">{{ notice }}</div>

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

      <button class="btn-primary w-full" type="submit" :disabled="loading">
        {{ loading ? 'Sending...' : 'Send reset link' }}
      </button>
    </form>

    <template #footer>
      <RouterLink to="/login" class="text-brand hover:underline">Back to sign in</RouterLink>
    </template>
  </AuthCard>
</template>
