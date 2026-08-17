import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import AppLayout from '@/layouts/AppLayout.vue'

const routes = [
  { path: '/', redirect: '/launches' },
  { path: '/dashboard', redirect: '/launches' },
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/LoginView.vue'),
    meta: { guestOnly: true }
  },
  {
    path: '/signup',
    name: 'signup',
    component: () => import('@/views/SignupView.vue'),
    meta: { guestOnly: true }
  },
  {
    path: '/forgot-password',
    name: 'forgot-password',
    component: () => import('@/views/ForgotPasswordView.vue'),
    meta: { guestOnly: true }
  },
  {
    path: '/reset-password',
    name: 'reset-password',
    component: () => import('@/views/ResetPasswordView.vue'),
    meta: { guestOnly: true }
  },
  {
    // Everything inside the authenticated shell shares the sidebar and the
    // channels store loaded by AppLayout.
    path: '/',
    component: AppLayout,
    meta: { requiresAuth: true },
    children: [
      {
        // The backend OAuth callback redirects here with ?connected= or
        // ?connect_error=, so this path must stay in sync with
        // Api::V1::Oauth::CallbacksController::FRONTEND_RETURN_PATH.
        path: 'launches',
        name: 'launches',
        component: () => import('@/views/LaunchesView.vue')
      },
      {
        path: 'settings/accounts',
        name: 'settings-accounts',
        component: () => import('@/views/SettingsAccountsView.vue')
      }
    ]
  },
  { path: '/:pathMatch(.*)*', redirect: '/launches' }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach((to) => {
  const auth = useAuthStore()

  if (to.matched.some((record) => record.meta.requiresAuth) && !auth.isAuthenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }

  if (to.meta.guestOnly && auth.isAuthenticated) {
    return { name: 'launches' }
  }

  return true
})

export default router
