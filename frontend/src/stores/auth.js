import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import authApi from '@/api/auth'
import { getToken, setToken, getUser, setUser, clearSession } from '@/api/session'

export const useAuthStore = defineStore('auth', () => {
  // Seed from localStorage so a page refresh keeps the user signed in.
  const token = ref(getToken())
  const user = ref(getUser())

  const isAuthenticated = computed(() => Boolean(token.value))

  function persist(payload) {
    token.value = payload.token
    user.value = payload.user
    setToken(payload.token)
    setUser(payload.user)
  }

  function reset() {
    token.value = null
    user.value = null
    clearSession()
  }

  async function signup(credentials) {
    const { data } = await authApi.signup(credentials)
    persist(data)
    return data
  }

  async function login(credentials) {
    const { data } = await authApi.login(credentials)
    persist(data)
    return data
  }

  async function logout() {
    try {
      await authApi.logout()
    } finally {
      // Clear locally even if the request fails - the user asked to be signed
      // out, and an unreachable server should not keep them logged in.
      reset()
    }
  }

  async function requestPasswordReset(payload) {
    const { data } = await authApi.requestPasswordReset(payload)
    return data
  }

  async function resetPassword(payload) {
    const { data } = await authApi.resetPassword(payload)
    return data
  }

  return {
    token,
    user,
    isAuthenticated,
    signup,
    login,
    logout,
    requestPasswordReset,
    resetPassword,
    reset
  }
})
