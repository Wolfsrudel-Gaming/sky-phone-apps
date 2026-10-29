<script setup lang="ts">
import { Clock, Info } from 'lucide-vue-next'
import { computed, onMounted, ref } from 'vue'
import { rpc } from '@/shared/nui'
import type { EarningsSummary } from '@/shared/types'
import UserAvatar from '../components/UserAvatar.vue'
import { duration, money, shortDate, weekday } from '../format'
import { categoryLabel, errorText, t } from '../i18n'
import { useSnitch } from '../store'

const store = useSnitch()
const summary = ref<EarningsSummary | null>(null)
const error = ref('')

/** Fills the last 14 days so days without donations still get a bar. */
const days = computed(() => {
  const byDay = new Map((summary.value?.days ?? []).map((day) => [day.day, day.net]))
  const result: Array<{ day: string; net: number }> = []
  const today = new Date()
  for (let offset = 13; offset >= 0; offset -= 1) {
    const date = new Date(today.getFullYear(), today.getMonth(), today.getDate() - offset)
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
    result.push({ day: key, net: byDay.get(key) ?? 0 })
  }
  return result
})
const maxDay = computed(() => Math.max(1, ...days.value.map((day) => day.net)))

const shares = computed(() => {
  const totals = summary.value?.totals
  if (!totals || totals.gross === 0) return null
  return {
    net: (totals.net / totals.gross) * 100,
    tax: (totals.tax / totals.gross) * 100,
    fee: (totals.fee / totals.gross) * 100,
  }
})

function categoryName(id: string): string {
  return categoryLabel(store.config?.categories.find((entry) => entry.id === id)?.label, id)
}

onMounted(async () => {
  const result = await rpc<EarningsSummary>('earnings:summary')
  if (!result.ok) {
    error.value = errorText(result.error)
    return
  }
  summary.value = result.data
})
</script>

<template>
  <section class="screen screen--tabs">
    <div class="screen__scroll">
      <header class="page-header">
        <h1 class="page-title">{{ t('earnings.title') }}</h1>
      </header>

      <p v-if="error" class="form-error">{{ error }}</p>

      <template v-if="summary">
        <div class="card earnings__hero">
          <span class="earnings__label">{{ t('earnings.net') }}</span>
          <strong class="earnings__net">{{ money(summary.totals.net) }}</strong>
          <div v-if="shares" class="earnings__bar" aria-hidden="true">
            <span class="earnings__bar-net" :style="{ width: `${shares.net}%` }" />
            <span class="earnings__bar-tax" :style="{ width: `${shares.tax}%` }" />
            <span class="earnings__bar-fee" :style="{ width: `${shares.fee}%` }" />
          </div>
          <dl class="earnings__legend">
            <div class="earnings__legend-total">
              <dt>{{ t('earnings.gross') }} · {{ t('earnings.donationCount', { count: summary.totals.donations }) }}</dt>
              <dd>{{ money(summary.totals.gross) }}</dd>
            </div>
            <div>
              <dt><span class="earnings__swatch earnings__swatch--net" />{{ t('earnings.net') }}</dt>
              <dd>{{ money(summary.totals.net) }}</dd>
            </div>
            <div>
              <dt><span class="earnings__swatch earnings__swatch--fee" />{{ t('earnings.fee') }} · {{ summary.feePercent }} %</dt>
              <dd>−{{ money(summary.totals.fee) }}</dd>
            </div>
            <div>
              <dt><span class="earnings__swatch earnings__swatch--tax" />{{ t('earnings.tax') }} · {{ summary.taxPercent }} %</dt>
              <dd>−{{ money(summary.totals.tax) }}</dd>
            </div>
          </dl>
        </div>

        <p v-if="summary.totals.pending > 0" class="notice earnings__pending">
          <Clock :size="16" /> {{ t('earnings.pending', { amount: money(summary.totals.pending) }) }}
        </p>

        <h2 class="section-title">{{ t('earnings.days') }}</h2>
        <div class="card earnings__chart">
          <div v-for="day in days" :key="day.day" class="earnings__column" :title="`${day.day}: ${money(day.net)}`">
            <span class="earnings__column-bar" :style="{ height: `${Math.max(3, (day.net / maxDay) * 100)}%` }" :class="{ 'earnings__column-bar--empty': day.net === 0 }" />
            <span class="earnings__column-label">{{ weekday(day.day) }}</span>
          </div>
        </div>

        <template v-if="summary.supporters.length">
          <h2 class="section-title">{{ t('earnings.supporters') }}</h2>
          <ol class="card earnings__supporters">
            <li v-for="(supporter, index) in summary.supporters" :key="supporter.username">
              <span class="earnings__rank">{{ index + 1 }}</span>
              <UserAvatar :name="supporter.username" :color="supporter.avatarColor" :size="32" />
              <span class="earnings__supporter">@{{ supporter.username }}</span>
              <strong>{{ money(supporter.total) }}</strong>
            </li>
          </ol>
        </template>

        <h2 class="section-title">{{ t('earnings.streams') }}</h2>
        <p v-if="!summary.streams.length" class="muted">{{ t('earnings.noStreams') }}</p>
        <ul v-else class="earnings__streams">
          <li v-for="stream in summary.streams" :key="stream.id" class="card earnings__stream">
            <div class="earnings__stream-head">
              <strong>{{ stream.title }}</strong>
              <span class="earnings__stream-net">{{ money(stream.net) }}</span>
            </div>
            <span class="muted small">
              {{ shortDate(stream.startedAt) }} · {{ duration(stream.endedAt - stream.startedAt) }} ·
              {{ categoryName(stream.category) }}
            </span>
            <span class="muted small">
              {{ t('earnings.donationCount', { count: stream.donations }) }} · {{ money(stream.gross) }} ·
              {{ t('summary.peak') }} {{ stream.peakViewers }}
            </span>
          </li>
        </ul>

        <p class="notice earnings__note"><Info :size="16" /> {{ t('earnings.payoutNote') }}</p>
      </template>

      <div v-else-if="!error" class="earnings__loading"><span class="spinner" /></div>
    </div>
  </section>
</template>

<style scoped>
.earnings__hero {
  display: flex;
  flex-direction: column;
  padding: 18px;
  background:
    radial-gradient(circle at 100% 0%, rgba(47, 211, 139, 0.16), transparent 55%),
    var(--surface);
}

.earnings__label {
  color: var(--text-3);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.earnings__net {
  margin: 2px 0 14px;
  color: var(--success);
  font-size: 36px;
  font-weight: 900;
  letter-spacing: -0.04em;
  font-variant-numeric: tabular-nums;
}

.earnings__bar {
  display: flex;
  height: 10px;
  margin-bottom: 12px;
  overflow: hidden;
  border-radius: 5px;
  background: var(--surface-2);
}

.earnings__bar-net {
  background: var(--success);
}

.earnings__bar-tax {
  background: #5c8dff;
}

.earnings__bar-fee {
  background: var(--text-3);
}

.earnings__legend {
  margin: 0;
}

.earnings__legend div {
  display: flex;
  justify-content: space-between;
  padding: 3px 0;
  font-size: 13px;
}

.earnings__legend dt {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  color: var(--text-2);
}

.earnings__legend dd {
  margin: 0;
  font-variant-numeric: tabular-nums;
}

.earnings__swatch {
  width: 8px;
  height: 8px;
  border-radius: 2px;
}

.earnings__swatch--net {
  background: var(--success);
}

.earnings__legend .earnings__legend-total {
  margin-bottom: 4px;
  padding-bottom: 7px;
  border-bottom: 1px solid var(--line);
  font-weight: 700;
}

.earnings__legend-total dt {
  color: var(--text);
}

.earnings__swatch--fee {
  background: var(--text-3);
}

.earnings__swatch--tax {
  background: #5c8dff;
}

.earnings__pending {
  margin: 12px 0 0;
}

.earnings__chart {
  display: grid;
  grid-template-columns: repeat(14, 1fr);
  gap: 5px;
  align-items: end;
  height: 140px;
  padding: 14px 12px 10px;
}

.earnings__column {
  display: flex;
  height: 100%;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  gap: 6px;
}

.earnings__column-bar {
  width: 100%;
  min-height: 3px;
  border-radius: 4px;
  background: linear-gradient(180deg, var(--brand), var(--brand-strong));
}

.earnings__column-bar--empty {
  background: var(--surface-3);
}

.earnings__column-label {
  color: var(--text-3);
  font-size: 10px;
  font-weight: 600;
}

.earnings__supporters {
  margin: 0;
  padding: 6px 14px;
  list-style: none;
}

.earnings__supporters li {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 0;
}

.earnings__supporters li + li {
  border-top: 1px solid var(--line);
}

.earnings__rank {
  width: 16px;
  color: var(--text-3);
  font-weight: 800;
  text-align: center;
}

.earnings__supporter {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  font-weight: 600;
  text-overflow: ellipsis;
}

.earnings__streams {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.earnings__stream {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 12px 14px;
}

.earnings__stream-head {
  display: flex;
  justify-content: space-between;
  gap: 10px;
}

.earnings__stream-head strong {
  overflow: hidden;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.earnings__stream-net {
  flex: none;
  color: var(--success);
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

.earnings__note {
  margin: 20px 0 0;
}

.earnings__loading {
  display: flex;
  justify-content: center;
  padding: 60px 0;
}

.earnings__loading .spinner {
  border-color: var(--surface-3);
  border-top-color: var(--brand);
}
</style>
