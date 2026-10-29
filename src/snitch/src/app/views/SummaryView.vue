<script setup lang="ts">
import { Clock, Eye, Gift, TrendingUp, Users, Wallet } from 'lucide-vue-next'
import { computed } from 'vue'
import { compactNumber, duration, money } from '../format'
import { reasonText, t } from '../i18n'
import { useSnitch } from '../store'

const store = useSnitch()
const summary = computed(() => store.summary)

function done(): void {
  store.summary = null
  store.openTab('discover')
}

function toEarnings(): void {
  store.summary = null
  store.openTab('earnings')
}
</script>

<template>
  <section class="screen">
    <div v-if="summary" class="screen__scroll summary">
      <div class="summary__hero">
        <span class="summary__icon"><TrendingUp :size="30" /></span>
        <h1 class="page-title">{{ t('summary.title') }}</h1>
        <p class="muted">{{ summary.title }}</p>
        <p v-if="summary.reason !== 'ended'" class="summary__reason">{{ reasonText(summary.reason) }}</p>
      </div>

      <div class="summary__earned card">
        <span class="summary__label">{{ t('summary.net') }}</span>
        <strong class="summary__net">{{ money(summary.net) }}</strong>
        <span class="muted small">{{ t('live.gross', { amount: money(summary.gross) }) }}</span>
      </div>

      <div class="summary__grid">
        <div class="card summary__stat">
          <Clock :size="18" />
          <strong>{{ duration(summary.duration) }}</strong>
          <span>{{ t('summary.duration') }}</span>
        </div>
        <div class="card summary__stat">
          <Eye :size="18" />
          <strong>{{ compactNumber(summary.peakViewers) }}</strong>
          <span>{{ t('summary.peak') }}</span>
        </div>
        <div class="card summary__stat">
          <Users :size="18" />
          <strong>{{ compactNumber(summary.uniqueViewers) }}</strong>
          <span>{{ t('summary.unique') }}</span>
        </div>
        <div class="card summary__stat">
          <Gift :size="18" />
          <strong>{{ summary.donations }}</strong>
          <span>{{ t('summary.donations') }}</span>
        </div>
      </div>

      <div class="summary__actions">
        <button class="btn btn--primary btn--block" @click="toEarnings">
          <Wallet :size="18" /> {{ t('summary.toEarnings') }}
        </button>
        <button class="btn btn--ghost btn--block" @click="done">{{ t('common.done') }}</button>
      </div>
    </div>
  </section>
</template>

<style scoped>
.summary__hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin: 24px 0 20px;
  text-align: center;
}

.summary__hero p {
  margin: 4px 0 0;
}

.summary__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 64px;
  height: 64px;
  margin-bottom: 14px;
  border-radius: 22px;
  background: var(--success-soft);
  color: var(--success);
}

.summary__reason {
  font-size: 13px;
  color: var(--text-3);
}

.summary__earned {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 12px;
  text-align: center;
}

.summary__label {
  color: var(--text-3);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.summary__net {
  color: var(--success);
  font-size: 38px;
  font-weight: 900;
  letter-spacing: -0.04em;
  font-variant-numeric: tabular-nums;
}

.summary__grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.summary__stat {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 14px;
}

.summary__stat svg {
  color: var(--text-3);
  margin-bottom: 4px;
}

.summary__stat strong {
  font-size: 20px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
}

.summary__stat span {
  color: var(--text-2);
  font-size: 12px;
}

.summary__actions {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-top: 24px;
}
</style>
