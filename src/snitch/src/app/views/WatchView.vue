<script setup lang="ts">
import { ChevronLeft, Eye, Gift, RefreshCw, Volume2, WifiOff } from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { nui, rpc } from '@/shared/nui'
import type { AppPush, ChatMessage, StreamInfo } from '@/shared/types'
import { onPhoneMessage, setStatusBarBackground } from '../bridge'
import ChatInput from '../components/ChatInput.vue'
import ChatList from '../components/ChatList.vue'
import DonateSheet from '../components/DonateSheet.vue'
import DonationAlerts from '../components/DonationAlerts.vue'
import LiveBadge from '../components/LiveBadge.vue'
import UserAvatar from '../components/UserAvatar.vue'
import { clock, compactNumber } from '../format'
import { categoryLabel, errorText, reasonText, t } from '../i18n'
import { type ViewerStatus, ViewerConnection } from '../rtc'
import { useSnitch } from '../store'

const CHAT_LIMIT = 150

const props = defineProps<{ streamId: number }>()
const store = useSnitch()

const stream = ref<StreamInfo | null>(null)
const messages = ref<ChatMessage[]>([])
const status = ref<ViewerStatus | 'joining'>('joining')
const ended = ref<string | null>(null)
const joinError = ref('')
const paused = ref(false)
const viewers = ref(0)
const uptime = ref(0)
const donateOpen = ref(false)
const needsSound = ref(false)
const video = ref<HTMLVideoElement | null>(null)

let connection: ViewerConnection | null = null
let startedAt = 0
let ticker = 0
let unsubscribe: (() => void) | null = null

const categoryName = computed(() => {
  const id = stream.value?.category ?? ''
  return categoryLabel(store.config?.categories.find((entry) => entry.id === id)?.label, id)
})

const overlay = computed(() => {
  if (ended.value) return 'ended'
  if (joinError.value) return 'error'
  if (status.value === 'failed') return 'failed'
  if (paused.value) return 'paused'
  if (status.value !== 'connected') return 'connecting'
  return null
})

async function attachMedia(media: MediaStream): Promise<void> {
  const element = video.value
  if (!element) return
  if (element.srcObject !== media) element.srcObject = media
  try {
    element.muted = false
    await element.play()
    needsSound.value = false
  } catch {
    // Autoplay with sound can be blocked until the next tap.
    element.muted = true
    needsSound.value = true
    await element.play().catch(() => undefined)
  }
}

function enableSound(): void {
  const element = video.value
  if (!element) return
  element.muted = false
  void element.play().then(() => {
    needsSound.value = false
  })
}

function handlePush(payload: unknown): void {
  const message = payload as AppPush
  if (!message || typeof message !== 'object') return
  if ('streamId' in message && message.streamId !== props.streamId) return

  switch (message.type) {
    case 'chat':
      messages.value.push(...message.messages)
      if (messages.value.length > CHAT_LIMIT) messages.value.splice(0, messages.value.length - CHAT_LIMIT)
      break
    case 'room:state':
      viewers.value = message.state.viewers
      paused.value = message.state.paused
      break
    case 'room:ended':
      ended.value = reasonText(message.reason)
      connection?.close()
      connection = null
      break
    case 'rtc:signal':
      void connection?.handleSignal(message.signal)
      break
  }
}

async function join(): Promise<void> {
  joinError.value = ''
  status.value = 'joining'
  const result = await nui<{ stream: StreamInfo; history: ChatMessage[]; iceServers: RTCIceServer[] }>(
    'watch:join',
    { streamId: props.streamId },
  )
  if (!result.ok) {
    joinError.value = errorText(result.error)
    return
  }
  stream.value = result.data.stream
  messages.value = result.data.history.slice(-CHAT_LIMIT)
  viewers.value = result.data.stream.viewers
  paused.value = result.data.stream.paused
  startedAt = Date.now() / 1000 - result.data.stream.uptime
  uptime.value = result.data.stream.uptime

  connection = new ViewerConnection(
    props.streamId,
    result.data.iceServers,
    (next) => {
      status.value = next
    },
    (media) => void attachMedia(media),
  )
  void connection.start()
}

async function sendChat(text: string): Promise<void> {
  const result = await rpc('chat:send', { streamId: props.streamId, text })
  if (!result.ok) store.showToast(errorText(result.error), 'error')
}

onMounted(() => {
  setStatusBarBackground('#000000')
  unsubscribe = onPhoneMessage(handlePush)
  ticker = window.setInterval(() => {
    if (startedAt && !ended.value) uptime.value = Date.now() / 1000 - startedAt
  }, 1000)
  void join()
})

onBeforeUnmount(() => {
  setStatusBarBackground(null)
  unsubscribe?.()
  window.clearInterval(ticker)
  connection?.close()
  connection = null
  if (!ended.value) void nui('watch:leave')
})
</script>

<template>
  <section class="screen watch">
    <div class="watch__stage">
      <video ref="video" class="watch__video" playsinline autoplay />

      <div class="watch__top">
        <button class="icon-btn icon-btn--glass" :aria-label="t('common.back')" @click="store.back()">
          <ChevronLeft :size="24" />
        </button>
        <span v-if="stream && !ended" class="watch__pills">
          <LiveBadge :label="`${t('live.badge')} ${clock(uptime)}`" />
          <span class="watch__pill"><Eye :size="14" :stroke-width="2.4" /> {{ compactNumber(viewers) }}</span>
        </span>
      </div>

      <button v-if="needsSound && overlay === null" class="watch__sound" @click="enableSound">
        <Volume2 :size="18" />
      </button>

      <div v-if="overlay" class="watch__overlay">
        <template v-if="overlay === 'connecting'">
          <span class="spinner" />
          <span>{{ status === 'reconnecting' ? t('watch.reconnecting') : t('watch.connecting') }}</span>
        </template>
        <template v-else-if="overlay === 'paused'">
          <strong class="watch__overlay-title">{{ t('watch.paused') }}</strong>
          <span>{{ t('watch.pausedText') }}</span>
        </template>
        <template v-else-if="overlay === 'failed'">
          <WifiOff :size="28" />
          <span>{{ t('watch.noConnection') }}</span>
          <button class="btn btn--ghost watch__retry" @click="connection?.restart()">
            <RefreshCw :size="16" /> {{ t('common.retry') }}
          </button>
        </template>
        <template v-else-if="overlay === 'ended'">
          <strong class="watch__overlay-title">{{ t('watch.ended') }}</strong>
          <span>{{ ended }} {{ t('watch.endedText') }}</span>
          <button class="btn btn--primary watch__retry" @click="store.back()">{{ t('watch.backToDiscover') }}</button>
        </template>
        <template v-else>
          <strong class="watch__overlay-title">{{ joinError }}</strong>
          <button class="btn btn--primary watch__retry" @click="store.back()">{{ t('watch.backToDiscover') }}</button>
        </template>
      </div>

      <DonationAlerts v-if="stream" :messages="messages" />
    </div>

    <div v-if="stream" class="watch__info">
      <UserAvatar :name="stream.streamer.username" :color="stream.streamer.avatarColor" :size="42" :live="!ended" />
      <div class="watch__meta">
        <strong class="watch__title">{{ stream.title }}</strong>
        <span class="watch__sub">@{{ stream.streamer.username }} · {{ categoryName }}</span>
      </div>
      <button
        v-if="store.config && !ended"
        class="btn btn--primary watch__donate"
        @click="donateOpen = true"
      >
        <Gift :size="18" :stroke-width="2.4" />
        {{ t('watch.donate') }}
      </button>
    </div>

    <ChatList :messages="messages" />
    <ChatInput
      :placeholder="t('watch.chatPlaceholder')"
      :max-length="store.config?.chatMaxLength ?? 200"
      :disabled="!stream || !!ended"
      @send="sendChat"
    />

    <DonateSheet
      v-if="stream && store.config"
      :open="donateOpen"
      :stream-id="streamId"
      :streamer="stream.streamer.username"
      :config="store.config.donations"
      @close="donateOpen = false"
    />
  </section>
</template>

<style scoped>
.watch {
  background: var(--bg);
}

.watch__stage {
  position: relative;
  flex: none;
  padding-top: var(--safe-top);
  background: #000;
}

.watch__video {
  display: block;
  width: 100%;
  aspect-ratio: 16 / 9;
  background: #000;
  object-fit: contain;
}

.watch__top {
  position: absolute;
  top: calc(var(--safe-top) + 8px);
  left: 8px;
  right: 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.watch__pills {
  display: inline-flex;
  gap: 6px;
}

.watch__pill {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  height: 24px;
  padding: 0 8px;
  border-radius: 6px;
  background: var(--glass);
  backdrop-filter: blur(10px);
  color: #fff;
  font-size: 12px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.watch__sound {
  position: absolute;
  right: 10px;
  bottom: 10px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--brand);
  color: var(--brand-ink);
  box-shadow: var(--shadow);
  animation: live-pulse 1.6s ease-in-out infinite;
}

.watch__overlay {
  position: absolute;
  inset: var(--safe-top) 0 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 0 24px;
  background: rgba(8, 7, 12, 0.72);
  backdrop-filter: blur(6px);
  color: #fff;
  font-size: 14px;
  text-align: center;
}

.watch__overlay-title {
  font-size: 20px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.watch__retry {
  min-height: 40px;
  margin-top: 6px;
  font-size: 14px;
}

.watch__info {
  display: flex;
  gap: 12px;
  align-items: center;
  padding: 12px var(--gutter);
  border-bottom: 1px solid var(--line);
}

.watch__meta {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
}

.watch__title {
  overflow: hidden;
  font-size: 15px;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.watch__sub {
  overflow: hidden;
  color: var(--text-2);
  font-size: 13px;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.watch__donate {
  min-height: 40px;
  padding: 0 14px;
  font-size: 14px;
}
</style>
