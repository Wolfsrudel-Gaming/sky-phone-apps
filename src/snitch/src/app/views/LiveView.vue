<script setup lang="ts">
import { Camera, Eye, Mic, MicOff, Power, Radio, SwitchCamera, Users } from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { nui, rpc } from '@/shared/nui'
import type { LiveState } from '@/shared/types'
import { setStatusBarBackground } from '../bridge'
import ChatInput from '../components/ChatInput.vue'
import ChatList from '../components/ChatList.vue'
import DonationAlerts from '../components/DonationAlerts.vue'
import GamePreview from '../components/GamePreview.vue'
import LiveBadge from '../components/LiveBadge.vue'
import { clock, compactNumber, duration, money } from '../format'
import { errorText, t } from '../i18n'
import { useSnitch } from '../store'

const store = useSnitch()
const live = computed(() => store.live)
const now = ref(Date.now() / 1000)
const confirmEnd = ref(false)
const busy = ref(false)
const pausedSince = ref<number | null>(null)
let ticker = 0
let confirmTimer = 0

const uptime = computed(() => (live.value ? now.value - live.value.startedAt : 0))
const pauseLeft = computed(() => {
  const timeout = store.config?.pauseTimeoutSeconds ?? 180
  if (pausedSince.value === null) return timeout
  return Math.max(0, timeout - (now.value - pausedSince.value))
})

watch(
  () => live.value?.state.paused,
  (paused) => {
    pausedSince.value = paused ? Date.now() / 1000 : null
  },
  { immediate: true },
)

function applyState(result: { ok: boolean; data?: LiveState; error?: string }): void {
  if (!result.ok) {
    store.showToast(errorText(result.error), 'error')
    return
  }
  if (store.live && result.data) store.live.state = result.data
}

async function toggleMute(): Promise<void> {
  if (!live.value) return
  applyState(await nui<LiveState>('live:mute', { muted: !live.value.state.muted }))
}

async function flipCamera(): Promise<void> {
  if (!live.value) return
  applyState(await nui<LiveState>('live:camera', { front: !live.value.state.front }))
}

async function resume(): Promise<void> {
  busy.value = true
  applyState(await nui<LiveState>('live:resume'))
  busy.value = false
}

async function end(): Promise<void> {
  if (!confirmEnd.value) {
    confirmEnd.value = true
    window.clearTimeout(confirmTimer)
    confirmTimer = window.setTimeout(() => {
      confirmEnd.value = false
    }, 3000)
    return
  }
  busy.value = true
  await nui('live:end')
  busy.value = false
  // The summary normally arrives as a push; fall back if it does not.
  window.setTimeout(() => {
    if (store.live) store.finishLive('ended', null)
  }, 2500)
}

async function sendChat(text: string): Promise<void> {
  if (!live.value) return
  const result = await rpc('chat:send', { streamId: live.value.stream.id, text })
  if (!result.ok) store.showToast(errorText(result.error), 'error')
}

onMounted(() => {
  setStatusBarBackground('#000000')
  ticker = window.setInterval(() => {
    now.value = Date.now() / 1000
  }, 1000)
})

onBeforeUnmount(() => {
  setStatusBarBackground(null)
  window.clearInterval(ticker)
  window.clearTimeout(confirmTimer)
})
</script>

<template>
  <section v-if="live" class="screen live">
    <div class="live__stage">
      <div class="live__frame">
        <div class="live__backdrop" aria-hidden="true">
          <Radio :size="40" />
        </div>
        <GamePreview :active="!live.state.paused" />

        <div class="live__top">
          <LiveBadge :label="`${t('live.badge')} ${clock(uptime)}`" />
          <span class="live__pill"><Eye :size="14" :stroke-width="2.4" /> {{ compactNumber(live.viewers) }}</span>
          <span class="live__pill"><Users :size="14" :stroke-width="2.4" /> {{ t('live.connected', { count: live.connections }) }}</span>
        </div>

        <div v-if="live.state.paused" class="live__paused">
          <strong>{{ t('live.pausedTitle') }}</strong>
          <span>{{ t('live.pausedText', { time: duration(pauseLeft) }) }}</span>
          <button class="btn btn--primary live__resume" :disabled="busy" @click="resume">
            <Camera :size="18" /> {{ t('live.resume') }}
          </button>
        </div>

        <DonationAlerts :messages="live.chat" />
      </div>
    </div>

    <div class="live__dashboard">
      <div class="live__earned">
        <span class="live__earned-label">{{ t('live.earned') }}</span>
        <strong class="live__earned-value">{{ money(live.earnings.net) }}</strong>
        <span class="live__earned-sub">{{ t('live.gross', { amount: money(live.earnings.gross) }) }}</span>
      </div>
      <div class="live__controls">
        <button
          class="live__control"
          :class="{ 'live__control--off': live.state.muted || !live.state.audio }"
          :disabled="!live.state.audio"
          :aria-label="live.state.muted ? t('live.unmute') : t('live.mute')"
          @click="toggleMute"
        >
          <MicOff v-if="live.state.muted || !live.state.audio" :size="20" />
          <Mic v-else :size="20" />
        </button>
        <button class="live__control" :aria-label="t('live.flip')" :disabled="live.state.paused" @click="flipCamera">
          <SwitchCamera :size="20" />
        </button>
        <button
          class="live__control live__control--end"
          :class="{ 'live__control--confirm': confirmEnd }"
          :disabled="busy"
          @click="end"
        >
          <Power :size="18" :stroke-width="2.6" />
          <span>{{ confirmEnd ? t('live.endConfirm') : t('live.end') }}</span>
        </button>
      </div>
    </div>
    <p v-if="!live.state.audio" class="live__no-audio">{{ t('live.noAudio') }}</p>

    <ChatList :messages="live.chat" />
    <ChatInput
      :placeholder="t('live.chatPlaceholder')"
      :max-length="store.config?.chatMaxLength ?? 200"
      @send="sendChat"
    />
  </section>
</template>

<style scoped>
.live {
  background: var(--bg);
}

.live__stage {
  flex: none;
  padding-top: var(--safe-top);
  background: #000;
}

.live__frame {
  position: relative;
  aspect-ratio: 16 / 9;
  overflow: hidden;
  background:
    radial-gradient(circle at 20% 10%, rgba(255, 51, 85, 0.35), transparent 55%),
    radial-gradient(circle at 85% 90%, rgba(255, 210, 63, 0.25), transparent 50%),
    #0b0a0f;
}

.live__backdrop {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.18);
}

.live__top {
  position: absolute;
  top: 10px;
  left: 10px;
  right: 10px;
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

.live__pill {
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

.live__paused {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 0 20px;
  background: rgba(8, 7, 12, 0.8);
  color: #fff;
  font-size: 13px;
  text-align: center;
}

.live__paused strong {
  font-size: 18px;
}

.live__resume {
  min-height: 40px;
  margin-top: 6px;
  font-size: 14px;
}

.live__dashboard {
  display: flex;
  gap: 12px;
  align-items: center;
  justify-content: space-between;
  padding: 12px var(--gutter);
  border-bottom: 1px solid var(--line);
}

.live__earned {
  display: flex;
  min-width: 0;
  flex-direction: column;
}

.live__earned-label {
  color: var(--text-3);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.live__earned-value {
  color: var(--success);
  font-size: 24px;
  font-weight: 900;
  letter-spacing: -0.03em;
  font-variant-numeric: tabular-nums;
}

.live__earned-sub {
  color: var(--text-2);
  font-size: 12px;
}

.live__controls {
  display: flex;
  gap: 8px;
}

.live__control {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-width: 44px;
  height: 44px;
  padding: 0 12px;
  border-radius: 14px;
  background: var(--surface-2);
  color: var(--text);
  font-size: 13px;
  font-weight: 800;
  transition:
    background-color 160ms var(--ease),
    transform 120ms var(--ease);
}

.live__control:active:not(:disabled) {
  transform: scale(0.94);
}

.live__control:disabled {
  opacity: 0.45;
}

.live__control--off {
  background: rgba(255, 84, 112, 0.16);
  color: var(--danger);
}

.live__control--end {
  background: var(--live);
  color: #fff;
}

.live__control--confirm {
  background: #fff;
  color: var(--live);
}

.live__no-audio {
  margin: 0;
  padding: 8px var(--gutter);
  background: rgba(255, 84, 112, 0.1);
  color: var(--danger);
  font-size: 12px;
  font-weight: 600;
}
</style>
