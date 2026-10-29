<script setup lang="ts">
import { t } from '../i18n'

withDefaults(defineProps<{ label?: string }>(), { label: undefined })
</script>

<template>
  <span class="live-badge">
    <span class="live-dot" />
    {{ label ?? t('live.badge') }}
  </span>
</template>

<style scoped>
.live-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 24px;
  padding: 0 9px;
  border-radius: 6px;
  background: var(--live);
  color: #fff;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0.04em;
  font-variant-numeric: tabular-nums;
}

.live-badge .live-dot {
  width: 6px;
  height: 6px;
  background: #fff;
}
</style>
