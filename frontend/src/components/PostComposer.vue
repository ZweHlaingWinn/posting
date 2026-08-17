<script setup>
import { ref, computed } from 'vue'
import ChannelAvatar from './ChannelAvatar.vue'
import { useChannelsStore } from '@/stores/channels'
import { usePostsStore } from '@/stores/posts'

const emit = defineEmits(['close', 'published', 'saved'])

const channels = useChannelsStore()
const posts = usePostsStore()

// TikTok truncates captions past this, so warn rather than let the platform
// silently cut the text.
const CAPTION_LIMIT = 2200

const caption = ref('')
const videoUrl = ref('')
const selectedIds = ref([])
const submitting = ref(false)
const error = ref('')

// Only channels that are both connected and have a working publisher adapter.
const publishableAccounts = computed(() =>
  channels.activeAccounts.filter((account) => channels.platformById(account.platform)?.publishable)
)

const overLimit = computed(() => caption.value.length > CAPTION_LIMIT)

// Every platform wired up so far is video-only, so a URL is always required.
const canSubmit = computed(
  () => selectedIds.value.length > 0 && videoUrl.value.trim().length > 0 && !overLimit.value
)

function toggle(id) {
  const index = selectedIds.value.indexOf(id)

  if (index === -1) {
    selectedIds.value.push(id)
  } else {
    selectedIds.value.splice(index, 1)
  }
}

async function submit(publishNow) {
  if (!canSubmit.value) return

  submitting.value = true
  error.value = ''

  try {
    await posts.create({
      content: caption.value.trim(),
      media_urls: [videoUrl.value.trim()],
      social_account_ids: selectedIds.value,
      publish_now: publishNow
    })

    emit(publishNow ? 'published' : 'saved')
    emit('close')
  } catch (e) {
    error.value = e.messages?.[0] ?? 'Could not create that post.'
    // A failed publish still leaves the post saved and marked failed, so pull the
    // list back in rather than leaving it out of step with the server.
    posts.load()
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto bg-black/70 p-4 sm:p-8"
    @click.self="emit('close')"
  >
    <div class="card w-full max-w-xl p-6">
      <header class="mb-5 flex items-start justify-between gap-4">
        <div>
          <h2 class="text-base font-semibold">Create post</h2>
          <p class="mt-1 text-xs text-ink-muted">
            The video is sent to your TikTok drafts, then you finish it in the TikTok app.
          </p>
        </div>

        <button
          class="cursor-pointer rounded-lg px-2 text-xl leading-none text-ink-faint transition-colors hover:text-ink"
          title="Close"
          @click="emit('close')"
        >
          &times;
        </button>
      </header>

      <div v-if="error" class="alert-error">{{ error }}</div>

      <div v-if="publishableAccounts.length === 0" class="alert-error">
        No channel can publish yet. Connect a TikTok account under Settings first.
      </div>

      <label class="field-label">Channels</label>
      <div class="mb-5 flex flex-wrap gap-2">
        <button
          v-for="account in publishableAccounts"
          :key="account.id"
          class="flex cursor-pointer items-center gap-2 rounded-full border py-1.5 pl-1.5 pr-3 text-xs transition-colors"
          :class="
            selectedIds.includes(account.id)
              ? 'border-brand bg-brand-soft text-ink'
              : 'border-edge text-ink-muted hover:border-edge-strong'
          "
          @click="toggle(account.id)"
        >
          <ChannelAvatar :platform="account.platform" size="sm" />
          {{ account.external_username || account.platform }}
        </button>
      </div>

      <label class="field-label" for="composer-video">Video URL</label>
      <input
        id="composer-video"
        v-model="videoUrl"
        class="field-input"
        type="url"
        placeholder="https://example.com/clip.mp4"
      />
      <p class="mb-5 mt-1.5 text-xs text-ink-faint">
        A direct, publicly reachable MP4, MOV or WebM link. The server downloads it and hands it to
        TikTok.
      </p>

      <label class="field-label" for="composer-caption">Caption</label>
      <textarea
        id="composer-caption"
        v-model="caption"
        class="field-input min-h-28 resize-y"
        placeholder="Write something..."
      />
      <p class="mt-1.5 text-right text-xs" :class="overLimit ? 'text-negative' : 'text-ink-faint'">
        {{ caption.length }} / {{ CAPTION_LIMIT }}
      </p>

      <footer class="mt-6 flex items-center justify-end gap-3">
        <button class="btn-secondary" :disabled="submitting" @click="emit('close')">Cancel</button>

        <button
          class="btn-secondary"
          :disabled="submitting || !canSubmit"
          @click="submit(false)"
        >
          Save as draft
        </button>

        <button class="btn-primary" :disabled="submitting || !canSubmit" @click="submit(true)">
          {{ submitting ? 'Uploading...' : 'Post now' }}
        </button>
      </footer>

      <p v-if="submitting" class="mt-3 text-right text-xs text-ink-faint">
        Uploading to TikTok. This can take a minute for a large video.
      </p>
    </div>
  </div>
</template>
