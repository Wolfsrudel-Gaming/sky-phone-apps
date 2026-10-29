<script setup lang="ts">
import { Gift } from 'lucide-vue-next'
import { onBeforeUnmount, ref, watch } from 'vue'
import type { ChatMessage } from '@/shared/types'
import { money } from '../format'
import { t } from '../i18n'

// Shows new donations as a banner over the video, one after another.
// Drawn here instead of into the video: sharp at any size and costs no bandwidth.

const props = defineProps<{ messages: ChatMessage[] }>()

const SHOW_MS = 4800
const queue: ChatMessage[] = []
const current = ref<ChatMessage | null>(null)
let lastSeen = props.messages.length ? props.messages[props.messages.length - 1].id : 0
let timer = 0

function next(): void {
  current.value = queue.shift() ?? null
  if (current.value) timer = window.setTimeout(next, SHOW_MS)
}

watch(
  () => props.messages.length,
  () => {
    for (const message of props.messages) {
      if (message.id <= lastSeen) continue
      lastSeen = message.id
      if (message.kind === 'donation') queue.push(message)
    }
    if (!current.value && queue.length) next()
  },
)

onBeforeUnmount(() => window.clearTimeout(timer))
</script>

<template>
  <Transition name="alert">
    <div v-if="current" :key="current.id" class="alert" role="status">
      <span class="alert__icon"><Gift :size="20" :stroke-width="2.4" /></span>
      <span class="alert__body">
        <span class="alert__head">
          <strong>{{ current.user.username }}</strong>
          {{ t('watch.donated', { amount: money(current.amount ?? 0) }) }}
        </span>
        <span v-if="current.text" class="alert__text">{{ current.text }}</span>
      </span>
    </div>
  </Transition>
</template>

<style scoped>
.alert {
  position: absolute;
  left: 12px;
  right: 12px;
  bottom: 12px;
  z-index: 5;
  display: flex;
  gap: 10px;
  align-items: center;
  padding: 10px 12px;
  border-radius: var(--radius-m);
  background: linear-gradient(120deg, rgba(255, 210, 63, 0.96), rgba(255, 150, 40, 0.96));
  color: var(--brand-ink);
  box-shadow: 0 10px 28px rgba(255, 170, 30, 0.35);
}

.alert__icon {
  display: inline-flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: rgba(27, 21, 5, 0.12);
  animation: alert-pop 600ms var(--ease);
}

.alert__body {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.alert__head {
  font-size: 14px;
  font-weight: 600;
}

.alert__text {
  overflow: hidden;
  font-size: 13px;
  white-space: nowrap;
  text-overflow: ellipsis;
  opacity: 0.85;
}

@keyframes alert-pop {
  0% {
    transform: scale(0.4) rotate(-20deg);
  }
  60% {
    transform: scale(1.15) rotate(6deg);
  }
  100% {
    transform: scale(1) rotate(0);
  }
}

.alert-enter-active,
.alert-leave-active {
  transition:
    opacity 260ms var(--ease),
    transform 320ms var(--ease);
}

.alert-enter-from {
  opacity: 0;
  transform: translateY(16px) scale(0.96);
}

.alert-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>
