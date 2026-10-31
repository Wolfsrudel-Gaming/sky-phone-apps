<script setup lang="ts">
import { ChevronLeft } from 'lucide-vue-next'
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import Composer from '../components/Composer.vue'
import { clockTime, errorText, t } from '../i18n'
import { go, readOnly, rpc, state } from '../state'
import type { Message } from '../types'

const props = defineProps<{ threadId: number }>()

const alias = ref('')
const topic = ref('')
const messages = ref<Message[]>([])
const error = ref('')
const list = ref<HTMLElement | null>(null)
let timer = 0

async function load(): Promise<void> {
  const after = messages.value.length ? messages.value[messages.value.length - 1].id : 0
  const result = await rpc<{ thread: { alias: string; topic: string }; messages: Message[] }>('thread:read', {
    threadId: props.threadId,
    after,
  })
  if (!result.ok) {
    error.value = errorText(result.error)
    return
  }
  alias.value = result.data.thread.alias
  topic.value = result.data.thread.topic
  if (!result.data.messages.length) return
  messages.value.push(...result.data.messages)
  await nextTick()
  list.value?.scrollTo(0, list.value.scrollHeight)
}

async function send(body: string): Promise<void> {
  const result = await rpc('thread:send', { threadId: props.threadId, body })
  error.value = result.ok ? '' : errorText(result.error)
  if (result.ok) await load()
}

onMounted(() => {
  void load()
  timer = window.setInterval(load, 3000)
})
onBeforeUnmount(() => window.clearInterval(timer))
</script>

<template>
  <section class="screen">
    <header class="header">
      <button class="icon-btn" :aria-label="t('common.back')" @click="go({ name: 'threads' })">
        <ChevronLeft :size="24" />
      </button>
      <h1>{{ alias }}</h1>
    </header>
    <p v-if="topic" class="topic">„{{ topic }}“</p>
    <div ref="list" class="scroll dm">
      <div v-for="message in messages" :key="message.id" class="bubble" :class="{ 'bubble--mine': message.mine }">
        <p>{{ message.body }}</p>
        <span>{{ clockTime(message.createdAt) }}</span>
      </div>
    </div>
    <p v-if="error" class="error dm__error">{{ error }}</p>
    <Composer
      v-if="!readOnly()"
      :placeholder="t('thread.placeholder')"
      :max-length="state.status?.config.messageMaxLength ?? 500"
      @send="send"
    />
  </section>
</template>

<style scoped>
.topic {
  margin: 0 var(--gutter) 8px;
  overflow: hidden;
  color: var(--text-3);
  font-size: 13px;
  font-style: italic;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.dm {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.dm__error {
  padding: 0 var(--gutter);
}

.bubble {
  align-self: flex-start;
  max-width: 82%;
  padding: 9px 12px;
  border-radius: 16px 16px 16px 4px;
  background: var(--surface-2);
}

.bubble--mine {
  align-self: flex-end;
  border-radius: 16px 16px 4px 16px;
  background: var(--accent);
  color: var(--accent-ink);
}

.bubble p {
  margin: 0;
  white-space: pre-wrap;
  word-wrap: break-word;
  user-select: text;
}

.bubble span {
  display: block;
  margin-top: 2px;
  font-size: 10px;
  opacity: 0.6;
  text-align: right;
}
</style>
