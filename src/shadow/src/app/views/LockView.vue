<script setup lang="ts">
import { Delete, Lock, ShieldAlert } from 'lucide-vue-next'
import { computed, onBeforeUnmount, ref } from 'vue'
import { clockTime, errorText, t } from '../i18n'
import { refreshStatus, rpc, state } from '../state'

const pin = ref('')
const message = ref('')
const busy = ref(false)
const extractLeft = ref<number | null>(null)
let extractTimer = 0

const length = computed(() => state.status?.config.pinLength ?? 4)
const lockedUntil = computed(() => state.status?.lockedUntil ?? 0)
const canExtract = computed(() => state.status?.police && state.status?.foreignPhone)

async function submit(): Promise<void> {
  busy.value = true
  const result = await rpc('pin:verify', { pin: pin.value })
  busy.value = false
  pin.value = ''
  if (result.ok) {
    message.value = ''
    await refreshStatus()
    return
  }
  if (result.error === 'wrong_pin') message.value = t('lock.wrong', { count: result.remaining ?? 0 })
  else if (result.error === 'wiped') message.value = t('lock.wiped')
  else if (result.error === 'pin_locked') {
    await refreshStatus()
    message.value = t('lock.locked', { time: clockTime(lockedUntil.value) })
  } else message.value = errorText(result.error)
}

function press(digit: string): void {
  if (busy.value || pin.value.length >= length.value) return
  pin.value += digit
  if (pin.value.length === length.value) void submit()
}

async function extract(): Promise<void> {
  const result = await rpc<{ seconds: number }>('extract:start')
  if (!result.ok) {
    message.value = errorText(result.error)
    return
  }
  extractLeft.value = result.data.seconds
  extractTimer = window.setInterval(async () => {
    if (extractLeft.value === null) return
    extractLeft.value -= 1
    if (extractLeft.value > 0) return
    window.clearInterval(extractTimer)
    const finished = await rpc('extract:finish')
    extractLeft.value = null
    if (finished.ok) await refreshStatus()
    else message.value = errorText(finished.error)
  }, 1000)
}

onBeforeUnmount(() => window.clearInterval(extractTimer))
</script>

<template>
  <section class="screen lock">
    <div class="lock__top">
      <span class="lock__icon"><Lock :size="26" /></span>
      <h1>{{ t('lock.enterPin') }}</h1>
      <div class="lock__dots" aria-hidden="true">
        <span v-for="index in length" :key="index" :class="{ 'lock__dot--on': index <= pin.length }" class="lock__dot" />
      </div>
      <p v-if="message" class="error">{{ message }}</p>
      <p v-else-if="lockedUntil" class="error">{{ t('lock.locked', { time: clockTime(lockedUntil) }) }}</p>
    </div>

    <div class="lock__pad">
      <button v-for="digit in ['1', '2', '3', '4', '5', '6', '7', '8', '9']" :key="digit" class="lock__key" @click="press(digit)">
        {{ digit }}
      </button>
      <span />
      <button class="lock__key" @click="press('0')">0</button>
      <button class="lock__key lock__key--plain" :aria-label="t('common.back')" @click="pin = pin.slice(0, -1)">
        <Delete :size="22" />
      </button>
    </div>

    <div v-if="canExtract" class="lock__police">
      <p class="hint">{{ t('lock.extractHint') }}</p>
      <button class="btn btn--police btn--block" :disabled="extractLeft !== null" @click="extract">
        <ShieldAlert :size="18" />
        {{ extractLeft !== null ? t('lock.extracting', { seconds: extractLeft }) : t('lock.extract') }}
      </button>
    </div>
  </section>
</template>

<style scoped>
.lock {
  justify-content: space-between;
  padding: calc(var(--safe-top) + 40px) 32px calc(var(--safe-bottom) + 16px);
}

.lock__top {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
}

.lock__icon {
  color: var(--accent);
}

.lock__top h1 {
  margin: 14px 0 20px;
  font-family: var(--mono);
  font-size: 18px;
}

.lock__dots {
  display: flex;
  gap: 16px;
}

.lock__dot {
  width: 13px;
  height: 13px;
  border-radius: 50%;
  border: 2px solid var(--text-3);
  transition: background-color 120ms;
}

.lock__dot--on {
  border-color: var(--accent);
  background: var(--accent);
}

.lock__pad {
  display: grid;
  grid-template-columns: repeat(3, 72px);
  justify-content: center;
  gap: 16px 26px;
}

.lock__key {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  background: var(--surface-2);
  font-family: var(--mono);
  font-size: 26px;
  transition: background-color 120ms;
}

.lock__key:active {
  background: var(--accent-soft);
}

.lock__key--plain {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: none;
}

.lock__police .hint {
  margin-bottom: 10px;
  text-align: center;
}
</style>
