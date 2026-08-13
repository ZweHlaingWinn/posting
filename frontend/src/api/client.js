import axios from 'axios'
import { getToken } from './session'

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api/v1',
  headers: { 'Content-Type': 'application/json' },
  timeout: 15000
})

// Set by main.js so the client can tear down the session on a 401 without
// importing the store or the router (both of which import this module).
let onUnauthorized = () => {}

export function setUnauthorizedHandler(handler) {
  onUnauthorized = handler
}

client.interceptors.request.use((config) => {
  const token = getToken()

  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }

  return config
})

client.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status

    // A 401 on the login endpoint just means bad credentials; only an expired or
    // revoked token on an authenticated call should log the user out.
    const isLoginAttempt = error.config?.url?.includes('/auth/login')

    if (status === 401 && !isLoginAttempt) {
      onUnauthorized()
    }

    return Promise.reject(normalizeError(error))
  }
)

// Collapses the API's { errors: [...] } envelope, validation failures and
// network errors into one shape so views never inspect raw axios errors.
function normalizeError(error) {
  const errors = error.response?.data?.errors

  if (Array.isArray(errors) && errors.length > 0) {
    return { messages: errors, status: error.response.status }
  }

  if (!error.response) {
    return { messages: ['Unable to reach the server. Please try again.'], status: null }
  }

  return { messages: ['Something went wrong. Please try again.'], status: error.response.status }
}

export default client
