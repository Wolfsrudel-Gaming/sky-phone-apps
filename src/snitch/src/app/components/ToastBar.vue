<script setup lang="ts">
import { CircleAlert, CircleCheck, Info } from 'lucide-vue-next'
import { useSnitch } from '../store'

const store = useSnitch()
</script>

<template>
  <Transition name="toast">
    <div v-if="store.toast" class="toast" :class="`toast--${store.toast.kind}`" role="status">
      <CircleCheck v-if="store.toast.kind === 'success'" :size="18" />
      <CircleAlert v-else-if="store.toast.kind === 'error'" :size="18" />
      <Info v-else :size="18" />
      <span>{{ store.toast.text }}</span>
    </div>
  </Transition>
</template>

<style scoped>
.toast {
  position: absolute;
  top: calc(var(--safe-top) + 8px);
  left: var(--gutter);
  right: var(--gutter);
  z-index: 100;
  display: flex;
  gap: 10px;
  align-items: center;
  padding: 12px 14px;
  border-radius: var(--radius-m);
  background: var(--bg-elevated);
  border: 1px solid var(--line-strong);
  box-shadow: var(--shadow);
  font-size: 14px;
  font-weight: 600;
}

.toast--success svg {
  color: var(--success);
}

.toast--error svg {
  color: var(--danger);
}

.toast svg {
  flex: none;
  color: var(--text-2);
}

.toast-enter-active,
.toast-leave-active {
  transition:
    opacity 200ms var(--ease),
    transform 240ms var(--ease);
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(-10px);
}
</style>
