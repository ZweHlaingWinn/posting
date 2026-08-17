<script setup>
import { ref, computed, watch } from 'vue'
import ChannelAvatar from './ChannelAvatar.vue'
import { useChannelsStore } from '@/stores/channels'
import { usePostsStore } from '@/stores/posts'

const emit = defineEmits(['close', 'published', 'saved'])

const channels = useChannelsStore()
const posts = usePostsStore()

// TikTok truncates captions past this, so warn rather than let the platform
// silently cut the text.
const CAPTION_LIMIT = 2200
const MAX_VIDEO_BYTES = 64 * 1024 * 1024
const DIRECT_VIDEO = /\.(mp4|mov|webm)(\?|#|$)/i

const caption = ref('')
const videoUrl = ref('')
const videoFile = ref(null)
const selectedIds = ref([])
const submitting = ref(false)
const error = ref('')

const fileInput = ref(null)

// Only channels that are both connected and have a working publisher adapter.
const publishableAccounts = computed(() =>
  channels.activeAccounts.filter((account) => channels.platformById(account.platform)?.publishable)
)

const overLimit = computed(() => caption.value.length > CAPTION_LIMIT)

const looksLikePageUrl = computed(() => {
  const url = videoUrl.value.trim()
  return url.length > 0 && !DIRECT_VIDEO.test(url)
})

const fileTooLarge = computed(
  () => videoFile.value != null && videoFile.value.size > MAX_VIDEO_BYTES
)

const hasVideo = computed(() => videoFile.value != null || videoUrl.value.trim().length > 0)

// A file or a URL is enough; TikTok cannot accept caption-only posts.
const canSubmit = computed(
  () => selectedIds.value.length > 0 && hasVideo.value && !overLimit.value && !fileTooLarge.value
)

const submitBlockedReason = computed(() => {
  if (selectedIds.value.length === 0) return 'Select a channel first'
  if (!hasVideo.value) return 'Choose a video file or add a video URL'
  if (fileTooLarge.value) return 'Video must be 64 MB or smaller'
  if (overLimit.value) return 'Caption is over the character limit'
  return ''
})

// A lone connected account is the destination, so pick it instead of leaving
// Post now disabled until the chip is clicked.
watch(
  publishableAccounts,
  (accounts) => {
    if (accounts.length === 1 && selectedIds.value.length === 0) {
      selectedIds.value = [accounts[0].id]
    }
  },
  { immediate: true }
)

function toggle(id) {
  const index = selectedIds.value.indexOf(id)

  if (index === -1) {
    selectedIds.value.push(id)
  } else {
    selectedIds.value.splice(index, 1)
  }
}

function onFileChange(event) {
  videoFile.value = event.target.files?.[0] ?? null
}

function clearFile() {
  videoFile.value = null
  if (fileInput.value) fileInput.value.value = ''
}

function fileLabel(file) {
  const megabytes = file.size / (1024 * 1024)
  const size = megabytes >= 10 ? megabytes.toFixed(0) : megabytes.toFixed(1)

  return `${file.name} (${size} MB)`
}

async function submit(publishNow) {
  if (!canSubmit.value) return

  submitting.value = true
  error.value = ''

  try {
    const payload = {
      content: caption.value.trim(),
      social_account_ids: selectedIds.value,
      publish_now: publishNow
    }

    if (videoFile.value) {
      payload.video = videoFile.value
    } else {
      payload.media_urls = [videoUrl.value.trim()]
    }

    await posts.create(payload)

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

      <label class="field-label" for="composer-file">Video</label>
      <input
        id="composer-file"
        ref="fileInput"
        class="sr-only"
        type="file"
        accept="video/mp4,video/quicktime,video/webm,.mp4,.mov,.webm"
        @change="onFileChange"
      />
      <div class="mb-3 flex items-center gap-3">
        <label for="composer-file" class="btn-secondary cursor-pointer">Choose file</label>
        <p v-if="videoFile" class="min-w-0 truncate text-xs text-ink">
          {{ fileLabel(videoFile) }}
          <button class="ml-2 text-ink-faint hover:text-ink" type="button" @click="clearFile">
            Remove
          </button>
        </p>
        <p v-else class="text-xs text-ink-faint">MP4, MOV or WebM, up to 64 MB.</p>
      </div>
      <p v-if="fileTooLarge" class="mb-3 text-xs text-negative">
        That file is larger than TikTok's 64 MB upload limit for this app.
      </p>

      <label class="field-label" for="composer-video">Or a direct video URL</label>
      <input
        id="composer-video"
        v-model="videoUrl"
        class="field-input"
        type="url"
        placeholder="https://example.com/clip.mp4"
        :disabled="videoFile != null"
      />
      <p
        class="mb-5 mt-1.5 text-xs"
        :class="looksLikePageUrl && !videoFile ? 'text-negative' : 'text-ink-faint'"
      >
        <template v-if="looksLikePageUrl && !videoFile">
          That looks like a page, not a video file. Paste a publicly reachable link that ends in
          .mp4, .mov or .webm.
        </template>
        <template v-else>
          Optional if you chose a file. The server only accepts a public MP4, MOV or WebM link.
        </template>
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
          :title="submitBlockedReason"
          @click="submit(false)"
        >
          Save as draft
        </button>

        <button
          class="btn-primary"
          :disabled="submitting || !canSubmit"
          :title="submitBlockedReason"
          @click="submit(true)"
        >
          {{ submitting ? 'Uploading...' : 'Post now' }}
        </button>
      </footer>

      <p v-if="submitting" class="mt-3 text-right text-xs text-ink-faint">
        Uploading to TikTok. This can take a minute for a large video.
      </p>
    </div>
  </div>
</template>
