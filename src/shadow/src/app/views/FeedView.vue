<script setup lang="ts">
import { ChevronLeft, MessageSquareLock } from 'lucide-vue-next'
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import Composer from '../components/Composer.vue'
import { errorText, label, relative, t } from '../i18n'
import { go, readOnly, rpc, state } from '../state'
import type { Message } from '../types'

const props = defineProps<{ channel: string }>()

const messages = ref<Message[]>([])
const error = ref('')
const list = ref<HTMLElement | null>(null)
let timer = 0

const title = computed(() => {
  const channel = state.status?.config.channels.find((entry) => entry.id === props.channel)
  return channel ? label(channel.label, channel.id) : props.channel
})

async function load(): Promise<void> {
  const after = messages.value.length ? messages.value[messages.value.length - 1].id : 0
  const result = await rpc<{ messages: Message[] }>('channel:read', { channel: props.channel, after })
  if (!result.ok || !result.data.messages.length) return
  const element = list.value
  const pinned = !element || element.scrollHeight - element.scrollTop - element.clientHeight < 40
  messages.value.push(...result.data.messages)
  if (messages.value.length > 200) messages.value.splice(0, messages.value.length - 200)
  if (pinned) {
    await nextTick()
    list.value?.scrollTo(0, list.value.scrollHeight)
  }
}

async function send(body: string, ad: boolean): Promise<void> {
  const result = await rpc('channel:post', { channel: props.channel, body, ad })
  error.value = result.ok ? '' : errorText(result.error)
  if (result.ok) await load()
}

async function reply(message: Message): Promise<void> {
  const result = await rpc<{ threadId: number }>('thread:open', { messageId: message.id })
  if (!result.ok) {
    error.value = errorText(result.error)
    return
  }
  go({ name: 'thread', threadId: result.data.threadId })
}

onMounted(() => {
  void load()
  timer = window.setInterval(load, 4000)
})
onBeforeUnmount(() => window.clearInterval(timer))
</script>

<template>
  <section class="screen">
    <header class="header">
      <button class="icon-btn" :aria-label="t('common.back')" @click="go({ name: 'channels' })">
        <ChevronLeft :size="24" />
      </button>
      <h1># {{ title }}</h1>
    </header>
    <div ref="list" class="scroll feed">
      <p class="hint feed__note">{{ t('feed.expire', { hours: state.status?.config.lifetimeHours ?? 72 }) }}</p>
      <p v-if="!messages.length" class="muted feed__empty">{{ t('feed.empty') }}</p>
      <article v-for="message in messages" :key="message.id" class="post" :class="{ 'post--ad': message.isAd }">
        <header class="post__head">
          <span class="post__alias" :class="{ 'post__alias--mine': message.mine }">{{ message.alias }}</span>
          <span v-if="message.mine" class="post__tag">{{ t('feed.you') }}</span>
          <span v-if="message.isAd" class="post__tag post__tag--ad">{{ t('feed.ad') }}</span>
          <span class="post__time">{{ relative(message.createdAt) }}</span>
        </header>
        <p class="post__body">{{ message.body }}</p>
        <button v-if="!message.mine && !readOnly()" class="post__reply" @click="reply(message)">
          <MessageSquareLock :size="15" /> {{ t('feed.reply') }}
        </button>
      </article>
    </div>
    <p v-if="error" class="error feed__error">{{ error }}</p>
    <Composer
      v-if="!readOnly()"
      :placeholder="t('feed.placeholder')"
      :max-length="state.status?.config.messageMaxLength ?? 500"
      allow-ad
      :ad-label="t('feed.ad')"
      @send="send"
    />
  </section>
</template>

<style scoped>
.feed__note {
  margin: 0 0 12px;
  font-family: var(--mono);
  font-size: 11px;
  text-align: center;
}

.feed__empty {
  margin-top: 40px;
  text-align: center;
}

.feed__error {
  padding: 0 var(--gutter);
}

.post {
  margin-bottom: 10px;
  padding: 12px 14px;
  border-radius: 14px;
  background: var(--surface);
  border: 1px solid var(--line);
}

.post--ad {
  border-color: rgba(255, 179, 64, 0.4);
  background: linear-gradient(180deg, rgba(255, 179, 64, 0.07), var(--surface) 70%);
}

.post__head {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
}

.post__alias {
  font-family: var(--mono);
  font-weight: 700;
  color: var(--accent);
}

.post__alias--mine {
  color: var(--text);
}

.post__tag {
  padding: 1px 6px;
  border-radius: 4px;
  background: var(--surface-2);
  color: var(--text-2);
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
}

.post__tag--ad {
  background: rgba(255, 179, 64, 0.16);
  color: var(--ad);
}

.post__time {
  margin-left: auto;
  color: var(--text-3);
}

.post__body {
  margin: 6px 0 0;
  line-height: 1.45;
  white-space: pre-wrap;
  word-wrap: break-word;
  user-select: text;
}

.post__reply {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  margin-top: 10px;
  color: var(--accent);
  font-size: 13px;
  font-weight: 700;
}
</style>
