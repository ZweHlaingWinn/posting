<script setup>
import { ref, onMounted, computed } from 'vue'
import { RouterLink } from 'vue-router'
import ChannelStrip from '@/components/ChannelStrip.vue'
import PostCard from '@/components/PostCard.vue'
import PostComposer from '@/components/PostComposer.vue'
import { useChannelsStore } from '@/stores/channels'
import { usePostsStore } from '@/stores/posts'

const channels = useChannelsStore()
const posts = usePostsStore()

const composerOpen = ref(false)
const notice = ref('')
const error = ref('')
const busyId = ref(null)

const hasChannels = computed(() => channels.activeAccounts.length > 0)

onMounted(() => posts.load())

function onPublished() {
  notice.value = 'Sent to your TikTok drafts. Open the TikTok app to finish posting.'
  error.value = ''
}

function onSaved() {
  notice.value = 'Draft saved.'
  error.value = ''
}

async function onPublish(post) {
  busyId.value = post.id
  notice.value = ''
  error.value = ''

  try {
    await posts.publish(post.id)
    onPublished()
  } catch (e) {
    error.value = e.messages?.[0] ?? 'Could not publish that post.'
    // The per-channel statuses changed even though the call failed.
    posts.load()
  } finally {
    busyId.value = null
  }
}

async function onRemove(post) {
  if (!window.confirm('Delete this post?')) return

  busyId.value = post.id
  error.value = ''

  try {
    await posts.remove(post.id)
    notice.value = 'Post deleted.'
  } catch (e) {
    error.value = e.messages?.[0] ?? 'Could not delete that post.'
  } finally {
    busyId.value = null
  }
}
</script>

<template>
  <div class="flex min-h-full flex-col">
    <header class="flex items-center justify-between border-b border-edge px-8 py-4">
      <div>
        <h1 class="text-lg font-semibold tracking-tight">Launches</h1>
        <p class="text-xs text-ink-muted">Write a post and send it to your channels.</p>
      </div>

      <div class="flex items-center gap-5">
        <ChannelStrip />
        <button
          class="btn-primary"
          :disabled="!hasChannels"
          :title="hasChannels ? 'Create post' : 'Connect a channel first'"
          @click="composerOpen = true"
        >
          Create post
        </button>
      </div>
    </header>

    <div class="mx-auto w-full max-w-2xl flex-1 px-8 py-8">
      <div v-if="notice" class="alert-success">{{ notice }}</div>
      <div v-if="error" class="alert-error">{{ error }}</div>
      <div v-if="posts.errors.length" class="alert-error">{{ posts.errors[0] }}</div>

      <div v-if="posts.loading" class="space-y-4">
        <div v-for="n in 2" :key="n" class="h-32 animate-pulse rounded-2xl bg-surface" />
      </div>

      <div v-else-if="!hasChannels" class="card p-8 text-center">
        <h2 class="text-base font-semibold">Connect a channel to get started</h2>
        <p class="mt-2 text-sm text-ink-muted">
          Posting needs somewhere to go. Link a TikTok account and the composer opens up.
        </p>
        <RouterLink to="/settings/accounts" class="btn-primary mt-6">
          Connect your first channel
        </RouterLink>
      </div>

      <div v-else-if="posts.posts.length === 0" class="card p-8 text-center">
        <h2 class="text-base font-semibold">Nothing here yet</h2>
        <p class="mt-2 text-sm text-ink-muted">
          Create your first post and it will show up here with its delivery status.
        </p>
        <button class="btn-primary mt-6" @click="composerOpen = true">Create post</button>
      </div>

      <div v-else class="space-y-4">
        <PostCard
          v-for="post in posts.posts"
          :key="post.id"
          :post="post"
          :busy="busyId === post.id"
          @publish="onPublish"
          @remove="onRemove"
        />
      </div>
    </div>

    <PostComposer
      v-if="composerOpen"
      @close="composerOpen = false"
      @published="onPublished"
      @saved="onSaved"
    />
  </div>
</template>
