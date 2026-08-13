// Single source of truth for persisted credentials.
//
// The axios interceptors and the Pinia store both need the token, but the
// interceptors must not import the store (that would create a cycle), so both
// read through this module instead.

const TOKEN_KEY = 'auth.token'
const USER_KEY = 'auth.user'

export function getToken() {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token) {
  if (token) {
    localStorage.setItem(TOKEN_KEY, token)
  } else {
    localStorage.removeItem(TOKEN_KEY)
  }
}

export function getUser() {
  const raw = localStorage.getItem(USER_KEY)
  if (!raw) return null

  try {
    return JSON.parse(raw)
  } catch {
    // Corrupt entry: drop it rather than trapping the app on a parse error.
    localStorage.removeItem(USER_KEY)
    return null
  }
}

export function setUser(user) {
  if (user) {
    localStorage.setItem(USER_KEY, JSON.stringify(user))
  } else {
    localStorage.removeItem(USER_KEY)
  }
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
}
