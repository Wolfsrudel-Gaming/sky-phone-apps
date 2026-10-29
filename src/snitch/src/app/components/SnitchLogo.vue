<script setup lang="ts">
withDefaults(defineProps<{ size?: number; wordmark?: boolean }>(), { size: 28, wordmark: true })
</script>

<template>
  <span class="logo" :style="{ '--logo-size': `${size}px` }">
    <svg class="logo__mark" viewBox="0 0 64 64" aria-hidden="true">
      <rect width="64" height="64" rx="16" fill="var(--brand)" />
      <path
        d="M10 32c5.5-9.5 13.3-14.5 22-14.5S48.5 22.5 54 32c-5.5 9.5-13.3 14.5-22 14.5S15.5 41.5 10 32Z"
        fill="var(--brand-ink)"
      />
      <circle cx="32" cy="32" r="8.5" fill="var(--brand)" />
      <circle cx="32" cy="32" r="4" fill="var(--brand-ink)" />
      <circle cx="51" cy="13" r="5" fill="var(--live)" />
    </svg>
    <span v-if="wordmark" class="logo__word">snitch</span>
  </span>
</template>

<style scoped>
.logo {
  display: inline-flex;
  align-items: center;
  gap: calc(var(--logo-size) * 0.32);
}

.logo__mark {
  width: var(--logo-size);
  height: var(--logo-size);
  flex: none;
}

.logo__word {
  font-size: calc(var(--logo-size) * 0.9);
  font-weight: 900;
  letter-spacing: -0.05em;
  line-height: 1;
}
</style>
