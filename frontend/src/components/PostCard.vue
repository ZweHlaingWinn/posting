<script setup>
import { computed } from 'vue'
import ChannelAvatar from './ChannelAvatar.vue'

const props = defineProps({
  post: { type: Object, required: true },
  busy: { type: Boolean, default: false }
})

const emit = defineEmits(['publish', 'remove'])

const STATUS_STYLES = {
  draft: 'bg-surface-raised text-ink-faint',
  published: 'bg-positive/10 text-positive',
  failed: 'bg-negative/10 text-negative'
}

// "Published" overstates what happened: the video is waiting in the creator's
// TikTok drafts until they post it themselves.
const STATUS_LABELS = {
  draft: 'Draft',
  published: 'Inbox notification sent',
  failed: 'Failed'
}

const statusClass = computed(() => STATUS_STYLES[props.post.status] ?? STATUS_STYLES.draft)
const statusLabel = computed(() => STATUS_LABELS[props.post.status] ?? props.post.status)

const canPublish = computed(() => props.post.status !== 'published')

const timestamp = computed(() => {
  const value = props.post.published_at ?? props.post.created_at

  return value ? new Date(value).toLocaleString() : ''
})

const failures = computed(() =>
  props.post.targets.filter((target) => target.status === 'failed' && target.error_message)
)
</script>

<template>
  <article class="card p-5">
    <div class="flex items-start justify-between gap-4">
      <div class="flex flex-wrap items-center gap-2">
        <ChannelAvatar
          v-for="target in post.targets"
          :key="target.id"
          :platform="target.platform"
          :username="target.external_username"
          size="sm"
          :muted="target.status === 'failed'"
        />

        <span class="rounded-full px-2.5 py-1 text-[11px] font-medium" :class="statusClass">
          {{ statusLabel }}
        </span>
      </div>

      <span class="shrink-0 text-xs text-ink-faint">{{ timestamp }}</span>
    </div>

    <p v-if="post.content" class="mt-3 whitespace-pre-wrap text-sm text-ink">
      {{ post.content }}
    </p>

    <a
      v-for="url in post.media_urls"
      :key="url"
      :href="url"
      target="_blank"
      rel="noopener noreferrer"
      class="mt-2 block truncate text-xs text-brand hover:underline"
    >
      {{ url }}
    </a>

    <p v-if="post.has_video && post.video_filename" class="mt-2 truncate text-xs text-ink-muted">
      {{ post.video_filename }}
    </p>

    <p v-for="target in failures" :key="target.id" class="mt-3 text-xs text-negative">
      {{ target.platform }}: {{ target.error_message }}
    </p>

    <footer class="mt-4 flex items-center justify-end gap-2">
      <button
        v-if="canPublish"
        class="btn-primary px-3 py-1.5 text-xs"
        :disabled="busy"
        @click="emit('publish', post)"
      >
        {{ busy ? 'Uploading...' : post.status === 'failed' ? 'Retry' : 'Publish' }}
      </button>

      <button
        class="btn-danger px-3 py-1.5 text-xs"
        :disabled="busy"
        @click="emit('remove', post)"
      >
        Delete
      </button>
    </footer>
  </article>
</template>
