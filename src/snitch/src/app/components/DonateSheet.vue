<script setup lang="ts">
import { Landmark } from 'lucide-vue-next'
import { computed, ref, watch } from 'vue'
import { rpc } from '@/shared/nui'
import { calculateSplit } from '@/shared/split'
import type { AppConfig } from '@/shared/types'
import { money } from '../format'
import { errorText, t } from '../i18n'
import { useSnitch } from '../store'
import BottomSheet from './BottomSheet.vue'

const props = defineProps<{
  open: boolean
  streamId: number
  streamer: string
  config: AppConfig['donations']
}>()
const emit = defineEmits<{ close: [] }>()

const store = useSnitch()
const selected = ref<number | null>(props.config.presets[1] ?? props.config.presets[0] ?? null)
const custom = ref('')
const message = ref('')
const sending = ref(false)
const error = ref('')

const amount = computed(() => {
  if (custom.value.trim() !== '') {
    const value = Number(custom.value.replace(/[^\d]/g, ''))
    return Number.isFinite(value) ? value : 0
  }
  return selected.value ?? 0
})

const valid = computed(
  () => amount.value >= props.config.minimum && amount.value <= props.config.maximum,
)

const split = computed(() =>
  calculateSplit(amount.value, props.config.feePercent, props.config.taxPercent, props.config.taxBase),
)

watch(
  () => props.open,
  (open) => {
    if (!open) return
    error.value = ''
    message.value = ''
  },
)

function pick(preset: number): void {
  selected.value = preset
  custom.value = ''
}

async function donate(): Promise<void> {
  if (!valid.value || sending.value) return
  sending.value = true
  error.value = ''
  const result = await rpc('donate', {
    streamId: props.streamId,
    amount: amount.value,
    message: message.value.trim(),
  })
  sending.value = false
  if (!result.ok) {
    error.value = errorText(result.error)
    return
  }
  store.showToast(t('donate.success'), 'success')
  emit('close')
}
</script>

<template>
  <BottomSheet :open="open" :title="t('donate.title', { name: streamer })" @close="emit('close')">
    <div class="donate">
      <div class="donate__presets">
        <button
          v-for="preset in config.presets"
          :key="preset"
          class="donate__preset"
          :class="{ 'donate__preset--active': custom === '' && selected === preset }"
          @click="pick(preset)"
        >
          {{ money(preset) }}
        </button>
      </div>

      <label class="field">
        <span class="field__label">{{ t('donate.custom') }}</span>
        <input
          v-model="custom"
          class="field__input donate__custom"
          inputmode="numeric"
          :placeholder="t('donate.range', { min: money(config.minimum), max: money(config.maximum) })"
        />
      </label>

      <label class="field">
        <span class="field__label">{{ t('donate.message') }}</span>
        <input
          v-model="message"
          class="field__input"
          :maxlength="config.messageMaxLength"
          :placeholder="t('donate.messagePlaceholder')"
        />
      </label>

      <dl class="donate__split">
        <div>
          <dt>{{ t('donate.fee', { percent: config.feePercent }) }}</dt>
          <dd>−{{ money(split.fee) }}</dd>
        </div>
        <div>
          <dt>{{ t('donate.tax', { percent: config.taxPercent }) }}</dt>
          <dd>−{{ money(split.tax) }}</dd>
        </div>
        <div class="donate__net">
          <dt>{{ t('donate.streamerGets') }}</dt>
          <dd>{{ money(split.net) }}</dd>
        </div>
      </dl>

      <p v-if="error" class="form-error">{{ error }}</p>

      <button class="btn btn--primary btn--block" :disabled="!valid || sending" @click="donate">
        {{ t('donate.confirm', { amount: money(amount) }) }}
      </button>
      <p class="donate__note">
        <Landmark :size="14" />
        {{ t('donate.bankNote') }}
      </p>
    </div>
  </BottomSheet>
</template>

<style scoped>
.donate__presets {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  margin-bottom: 16px;
}

.donate__preset {
  min-height: 48px;
  border-radius: var(--radius-m);
  background: var(--surface-2);
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  border: 2px solid transparent;
  transition:
    border-color 160ms var(--ease),
    background-color 160ms var(--ease);
}

.donate__preset--active {
  border-color: var(--brand);
  background: var(--brand-soft);
}

.donate__custom {
  font-variant-numeric: tabular-nums;
}

.donate__split {
  margin: 4px 0 16px;
  padding: 12px 14px;
  border-radius: var(--radius-m);
  background: var(--surface-2);
}

.donate__split div {
  display: flex;
  justify-content: space-between;
  padding: 3px 0;
  font-size: 14px;
}

.donate__split dt {
  color: var(--text-2);
}

.donate__split dd {
  margin: 0;
  font-variant-numeric: tabular-nums;
  color: var(--text-2);
}

.donate__split .donate__net {
  margin-top: 6px;
  padding-top: 9px;
  border-top: 1px solid var(--line);
  font-weight: 800;
}

.donate__net dt,
.donate__net dd {
  color: var(--text);
}

.donate__note {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin: 10px 0 0;
  color: var(--text-3);
  font-size: 12px;
}
</style>
