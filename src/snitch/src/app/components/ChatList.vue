<script setup lang="ts">
import { ArrowDown, Gift } from 'lucide-vue-next'
import { nextTick, onMounted, ref, watch } from 'vue'
import type { ChatMessage } from '@/shared/types'
import { money } from '../format'
import { t } from '../i18n'

const props = defineProps<{ messages: ChatMessage[] }>()

const list = ref<HTMLElement | null>(null)
const pinned = ref(true)
const unread = ref(0)

function atBottom(): boolean {
  const element = list.value
  if (!element) return true
  return element.scrollHeight - element.scrollTop - element.clientHeight < 32
}

function scrollToBottom(): void {
  const element = list.value
  if (!element) return
  element.scrollTop = element.scrollHeight
  pinned.value = true
  unread.value = 0
}

function onScroll(): void {
  pinned.value = atBottom()
  if (pinned.value) unread.value = 0
}

watch(
  () => props.messages.length,
  async (length, previous) => {
    if (pinned.value) {
      await nextTick()
      scrollToBottom()
    } else if (length > previous) {
      unread.value += length - previous
    }
  },
)

onMounted(scrollToBottom)
</script>

<template>
  <div class="chat">
    <ol ref="list" class="chat__list" aria-live="polite" @scroll.passive="onScroll">
      <li class="chat__system">{{ t('watch.welcome') }}</li>
      <li
        v-for="message in messages"
        :key="message.id"
        class="chat__item"
        :class="{ 'chat__item--donation': message.kind === 'donation' }"
      >
        <template v-if="message.kind === 'donation'">
          <span class="chat__donation-head">
            <Gift :size="15" :stroke-width="2.4" />
            <strong class="chat__name">{{ message.user.username }}</strong>
            {{ t('watch.donated', { amount: money(message.amount ?? 0) }) }}
          </span>
          <span v-if="message.text" class="chat__text">{{ message.text }}</span>
        </template>
        <template v-else>
          <strong class="chat__name" :class="`chat__name--${message.user.avatarColor}`">
            <span v-if="message.user.role === 'host'" class="chat__badge">{{ t('watch.streamer') }}</span>
            {{ message.user.username }}
          </strong>
          <span class="chat__text">{{ message.text }}</span>
        </template>
      </li>
    </ol>
    <button v-if="unread > 0" class="chat__unread" @click="scrollToBottom">
      <ArrowDown :size="15" :stroke-width="2.6" />
      {{ unread }}
    </button>
  </div>
</template>

<style scoped>
.chat {
  position: relative;
  flex: 1;
  min-height: 0;
}

.chat__list {
  height: 100%;
  margin: 0;
  padding: 10px var(--gutter) 6px;
  overflow-y: auto;
  list-style: none;
  overscroll-behavior: contain;
  user-select: text;
}

.chat__system {
  margin-bottom: 8px;
  color: var(--text-3);
  font-size: 13px;
}

.chat__item {
  padding: 3px 0;
  font-size: 14px;
  line-height: 1.45;
  word-wrap: break-word;
}

.chat__item--donation {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin: 6px 0;
  padding: 9px 11px;
  border-radius: var(--radius-s);
  background: var(--brand-soft);
  border: 1px solid rgba(255, 210, 63, 0.35);
}

.chat__donation-head {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
  color: var(--text);
  font-weight: 600;
}

.chat__donation-head svg {
  color: var(--brand);
}

.chat__name {
  margin-right: 6px;
  font-weight: 700;
}

.chat__name--sunset {
  color: #ff8a5c;
}

.chat__name--ocean {
  color: #5cc8ff;
}

.chat__name--lime {
  color: #9be15c;
}

.chat__name--grape {
  color: #c08bff;
}

.chat__name--ember {
  color: #ffc94a;
}

.chat__name--steel {
  color: #a9b3c6;
}

:global([data-scheme='light'] .chat__name--sunset) {
  color: #d4501c;
}

:global([data-scheme='light'] .chat__name--ocean) {
  color: #1f6fd1;
}

:global([data-scheme='light'] .chat__name--lime) {
  color: #3f8411;
}

:global([data-scheme='light'] .chat__name--grape) {
  color: #7b3fd6;
}

:global([data-scheme='light'] .chat__name--ember) {
  color: #b77700;
}

:global([data-scheme='light'] .chat__name--steel) {
  color: #56627a;
}

.chat__donation-head .chat__name {
  margin-right: 0;
}

.chat__badge {
  display: inline-block;
  margin-right: 4px;
  padding: 1px 5px;
  border-radius: 4px;
  background: var(--live);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  vertical-align: 1px;
}

.chat__text {
  color: var(--text);
}

.chat__unread {
  position: absolute;
  left: 50%;
  bottom: 8px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  height: 30px;
  padding: 0 12px;
  border-radius: 999px;
  background: var(--brand);
  color: var(--brand-ink);
  font-size: 13px;
  font-weight: 800;
  box-shadow: var(--shadow);
  transform: translateX(-50%);
}
</style>
