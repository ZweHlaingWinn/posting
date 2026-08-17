<script setup>
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' }
})
</script>

<template>
  <div class="grid min-h-full place-items-center p-6">
    <div class="w-full max-w-[420px]">
      <div class="mb-6 flex items-center justify-center gap-2.5">
        <span class="grid size-8 place-items-center rounded-lg bg-brand text-sm font-bold text-white">
          S
        </span>
        <span class="text-[15px] font-semibold tracking-tight">Scheduler</span>
      </div>

      <div class="card p-8">
        <h1 class="text-xl font-semibold tracking-tight">{{ title }}</h1>
        <p v-if="subtitle" class="mt-1.5 mb-6 text-sm text-ink-muted">{{ subtitle }}</p>

        <slot />
      </div>

      <div class="mt-5 text-center text-[13px] text-ink-muted">
        <slot name="footer" />
      </div>
    </div>
  </div>
</template>
