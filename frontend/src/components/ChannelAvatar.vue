<script setup>
import { computed } from 'vue'

const props = defineProps({
  platform: { type: String, required: true },
  username: { type: String, default: null },
  size: { type: String, default: 'md' }, // sm | md | lg
  muted: { type: Boolean, default: false }
})

// Brand colours only. Official platform logos are trademarked assets with their
// own usage rules, so drop the real marks in here once you've sourced them.
const BRAND = {
  twitter: { color: '#1d9bf0', label: 'X' },
  linkedin: { color: '#0a66c2', label: 'in' },
  facebook: { color: '#1877f2', label: 'f' },
  instagram: { color: '#e1306c', label: 'ig' },
  tiktok: { color: '#25f4ee', label: 'tt' }
}

const SIZES = {
  sm: 'size-7 text-[10px]',
  md: 'size-10 text-xs',
  lg: 'size-14 text-sm'
}

const brand = computed(() => BRAND[props.platform] ?? { color: '#7c5cff', label: '?' })
const sizeClasses = computed(() => SIZES[props.size] ?? SIZES.md)
</script>

<template>
  <span
    class="inline-flex shrink-0 items-center justify-center rounded-full font-bold text-white transition-opacity"
    :class="[sizeClasses, muted && 'opacity-40 grayscale']"
    :style="{ backgroundColor: brand.color }"
    :title="username ? `${platform} - ${username}` : platform"
  >
    {{ brand.label }}
  </span>
</template>
