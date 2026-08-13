import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { setUnauthorizedHandler } from './api/client'
import { useAuthStore } from './stores/auth'
import './assets/main.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// Wire the axios 401 handler here, where both the store and the router already
// exist, keeping the client module free of circular imports.
setUnauthorizedHandler(() => {
  useAuthStore(pinia).reset()

  if (router.currentRoute.value.name !== 'login') {
    router.push({
      name: 'login',
      query: { redirect: router.currentRoute.value.fullPath, expired: '1' }
    })
  }
})

app.mount('#app')
