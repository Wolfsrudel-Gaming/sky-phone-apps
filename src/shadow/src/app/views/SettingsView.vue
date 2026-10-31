<script setup lang="ts">
import { Dices, ShieldCheck, ShieldOff } from 'lucide-vue-next'
import { computed, ref } from 'vue'
import { clockTime, errorText, t } from '../i18n'
import { readOnly, refreshStatus, rpc, state } from '../state'

const config = computed(() => state.status?.config)
const alias = ref(state.status?.alias ?? '')
const pin = ref('')
const message = ref('')
const error = ref('')

const canChangeAlias = computed(() => (state.status?.aliasChangeAt ?? 0) <= Date.now() / 1000)

async function saveAlias(): Promise<void> {
  const result = await rpc<{ alias: string }>('alias:set', { alias: alias.value })
  report(result.ok, result.ok ? undefined : result.error)
  if (result.ok) {
    alias.value = result.data.alias
    await refreshStatus()
  }
}

async function savePin(value: string | false): Promise<void> {
  const result = await rpc('pin:set', { pin: value })
  report(result.ok, result.ok ? undefined : result.error)
  pin.value = ''
  if (result.ok) await refreshStatus()
}

function report(ok: boolean, code?: string): void {
  message.value = ok ? t('common.saved') : ''
  error.value = ok ? '' : errorText(code)
}
</script>

<template>
  <section class="screen">
    <header class="header"><h1>{{ t('settings.title') }}</h1></header>
    <div v-if="config && !readOnly()" class="scroll">
      <span class="label">{{ t('settings.alias') }}</span>
      <template v-if="config.aliasMode === 'custom'">
        <input v-model="alias" class="input mono" :maxlength="config.aliasMaxLength" :disabled="!canChangeAlias" />
        <button class="btn btn--ghost btn--block row" :disabled="!canChangeAlias || alias === state.status?.alias" @click="saveAlias">
          {{ t('common.save') }}
        </button>
      </template>
      <template v-else>
        <p class="current mono">{{ state.status?.alias }}</p>
        <button class="btn btn--ghost btn--block" :disabled="!canChangeAlias" @click="saveAlias">
          <Dices :size="18" /> {{ t('settings.aliasRandom') }}
        </button>
      </template>
      <p class="hint">
        {{ canChangeAlias ? t('settings.aliasHint') : t('settings.aliasNext', { time: clockTime(state.status?.aliasChangeAt ?? 0) }) }}
      </p>

      <span class="label">{{ t('settings.pin') }}</span>
      <p class="pin-state" :class="{ 'pin-state--on': state.status?.hasPin }">
        <ShieldCheck v-if="state.status?.hasPin" :size="18" />
        <ShieldOff v-else :size="18" />
        {{ state.status?.hasPin ? t('settings.pinOn') : t('settings.pinOff') }}
      </p>
      <input
        v-model="pin"
        class="input mono"
        inputmode="numeric"
        type="password"
        :maxlength="config.pinLength"
        :placeholder="t('settings.pinNew', { length: config.pinLength })"
        @input="pin = pin.replace(/\D/g, '')"
      />
      <button class="btn btn--accent btn--block row" :disabled="pin.length !== config.pinLength" @click="savePin(pin)">
        {{ t('common.save') }}
      </button>
      <button v-if="state.status?.hasPin" class="btn btn--ghost btn--block row" @click="savePin(false)">
        {{ t('settings.pinRemove') }}
      </button>
      <p class="hint">{{ t('settings.wipeNote') }}</p>

      <p v-if="message" class="saved">{{ message }}</p>
      <p v-if="error" class="error">{{ error }}</p>
    </div>
  </section>
</template>

<style scoped>
.mono {
  font-family: var(--mono);
}

.row {
  margin-top: 8px;
}

.current {
  margin: 0 0 10px;
  color: var(--accent);
  font-size: 18px;
}

.pin-state {
  display: flex;
  gap: 8px;
  align-items: center;
  margin: 0 0 10px;
  color: var(--ad);
  font-size: 13px;
}

.pin-state--on {
  color: var(--accent);
}

.saved {
  margin-top: 12px;
  color: var(--accent);
  font-size: 13px;
}
</style>
