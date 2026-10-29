<script setup lang="ts">
import { Compass, Radio, User, Wallet } from 'lucide-vue-next'
import { t } from '../i18n'
import { type Tab, useSnitch } from '../store'

const store = useSnitch()

const tabs = [
  { id: 'discover', icon: Compass, label: () => t('tabs.discover') },
  { id: 'live', icon: Radio, label: () => t('tabs.live') },
  { id: 'earnings', icon: Wallet, label: () => t('tabs.earnings') },
  { id: 'profile', icon: User, label: () => t('tabs.profile') },
] as const satisfies ReadonlyArray<{ id: Tab; icon: unknown; label: () => string }>
</script>

<template>
  <nav class="tabbar" :aria-label="t('tabs.discover')">
    <button
      v-for="tab in tabs"
      :key="tab.id"
      class="tabbar__item"
      :class="{
        'tabbar__item--active': store.tab === tab.id,
        'tabbar__item--live': tab.id === 'live' && store.live,
      }"
      :aria-current="store.tab === tab.id ? 'page' : undefined"
      @click="store.openTab(tab.id)"
    >
      <span class="tabbar__icon">
        <component :is="tab.icon" :size="23" :stroke-width="store.tab === tab.id ? 2.4 : 2" />
        <span v-if="tab.id === 'live' && store.live" class="tabbar__dot" />
      </span>
      <span class="tabbar__label">{{ tab.label() }}</span>
    </button>
  </nav>
</template>

<style scoped>
.tabbar {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 20;
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  padding: 6px 8px var(--safe-bottom);
  background: var(--bar);
  backdrop-filter: blur(18px);
  border-top: 1px solid var(--line);
}

.tabbar__item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 3px;
  min-height: 52px;
  padding-top: 6px;
  color: var(--text-3);
  font-size: 11px;
  font-weight: 600;
  transition: color 160ms var(--ease);
}

.tabbar__item--active {
  color: var(--text);
}

.tabbar__item--live {
  color: var(--live);
}

.tabbar__icon {
  position: relative;
  display: inline-flex;
}

.tabbar__dot {
  position: absolute;
  top: -2px;
  right: -4px;
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: var(--live);
  border: 2px solid var(--bg-elevated);
  animation: live-pulse 1.6s ease-in-out infinite;
}
</style>
