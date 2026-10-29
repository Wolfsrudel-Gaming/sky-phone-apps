<script setup lang="ts">
import { X } from 'lucide-vue-next'
import { t } from '../i18n'

defineProps<{ open: boolean; title: string }>()
defineEmits<{ close: [] }>()
</script>

<template>
  <Transition name="sheet">
    <div v-if="open" class="sheet" role="dialog" aria-modal="true" :aria-label="title">
      <button class="sheet__scrim" :aria-label="t('common.close')" @click="$emit('close')" />
      <div class="sheet__panel">
        <span class="sheet__grip" />
        <header class="sheet__header">
          <h2 class="sheet__title">{{ title }}</h2>
          <button class="icon-btn" :aria-label="t('common.close')" @click="$emit('close')">
            <X :size="20" />
          </button>
        </header>
        <div class="sheet__body">
          <slot />
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.sheet {
  position: absolute;
  inset: 0;
  z-index: 50;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
}

.sheet__scrim {
  position: absolute;
  inset: 0;
  background: var(--scrim);
}

.sheet__panel {
  position: relative;
  max-height: 88%;
  overflow-y: auto;
  padding: 8px var(--gutter) calc(var(--safe-bottom) + 12px);
  border-radius: var(--radius-xl) var(--radius-xl) 0 0;
  background: var(--bg-elevated);
  box-shadow: var(--shadow);
}

.sheet__grip {
  display: block;
  width: 38px;
  height: 5px;
  margin: 0 auto 6px;
  border-radius: 3px;
  background: var(--line-strong);
}

.sheet__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.sheet__title {
  margin: 0;
  font-size: 19px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.sheet-enter-active,
.sheet-leave-active {
  transition: opacity 200ms var(--ease);
}

.sheet-enter-active .sheet__panel,
.sheet-leave-active .sheet__panel {
  transition: transform 260ms var(--ease);
}

.sheet-enter-from,
.sheet-leave-to {
  opacity: 0;
}

.sheet-enter-from .sheet__panel,
.sheet-leave-to .sheet__panel {
  transform: translateY(100%);
}
</style>
