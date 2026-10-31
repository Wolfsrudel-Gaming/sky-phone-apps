<script setup lang="ts">
import { Hash, MessageSquareLock, UserRound } from 'lucide-vue-next'
import { computed } from 'vue'
import { errorText, t } from './i18n'
import { go, readOnly, refreshStatus, state } from './state'
import ChannelsView from './views/ChannelsView.vue'
import FeedView from './views/FeedView.vue'
import LockView from './views/LockView.vue'
import SettingsView from './views/SettingsView.vue'
import ThreadsView from './views/ThreadsView.vue'
import ThreadView from './views/ThreadView.vue'

const tab = computed(() => {
  const name = state.screen.name
  if (name === 'channels' || name === 'feed') return 'channels'
  if (name === 'threads' || name === 'thread') return 'threads'
  return name
})
const showTabs = computed(() => ['channels', 'threads', 'settings'].includes(state.screen.name))
</script>

<template>
  <main class="app">
    <div v-if="state.screen.name === 'boot'" class="boot">
      <p v-if="state.bootError" class="error">{{ errorText(state.bootError) }}</p>
      <button v-if="state.bootError" class="btn btn--ghost" @click="refreshStatus()">↻</button>
      <span v-else class="boot__cursor">_</span>
    </div>
    <template v-else>
      <LockView v-if="state.screen.name === 'lock'" />
      <ChannelsView v-else-if="state.screen.name === 'channels'" />
      <FeedView v-else-if="state.screen.name === 'feed'" :key="state.screen.channel" :channel="state.screen.channel" />
      <ThreadsView v-else-if="state.screen.name === 'threads'" />
      <ThreadView v-else-if="state.screen.name === 'thread'" :key="state.screen.threadId" :thread-id="state.screen.threadId" />
      <SettingsView v-else-if="state.screen.name === 'settings'" />

      <p v-if="readOnly() && state.screen.name !== 'lock'" class="banner banner--police police">{{ t('readonly') }}</p>
      <nav v-if="showTabs" class="tabs">
        <button :class="{ active: tab === 'channels' }" @click="go({ name: 'channels' })">
          <Hash :size="21" /> {{ t('tabs.channels') }}
        </button>
        <button :class="{ active: tab === 'threads' }" @click="go({ name: 'threads' })">
          <MessageSquareLock :size="21" /> {{ t('tabs.messages') }}
        </button>
        <button v-if="!readOnly()" :class="{ active: tab === 'settings' }" @click="go({ name: 'settings' })">
          <UserRound :size="21" /> {{ t('tabs.settings') }}
        </button>
      </nav>
    </template>
  </main>
</template>

<style scoped>
.app {
  position: relative;
  display: flex;
  height: 100%;
  flex-direction: column;
}

.app > .screen {
  position: relative;
  flex: 1;
  min-height: 0;
}

.police {
  justify-content: center;
  margin-top: 6px;
}

.boot {
  display: flex;
  flex: 1;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

.boot__cursor {
  color: var(--accent);
  font-family: var(--mono);
  font-size: 28px;
  animation: blink 1s steps(1) infinite;
}

@keyframes blink {
  50% {
    opacity: 0;
  }
}

.tabs {
  display: flex;
  padding: 6px 8px var(--safe-bottom);
  border-top: 1px solid var(--line);
  background: var(--bg);
}

.tabs button {
  display: flex;
  flex: 1;
  flex-direction: column;
  align-items: center;
  gap: 3px;
  min-height: 52px;
  padding-top: 6px;
  color: var(--text-3);
  font-size: 11px;
  font-weight: 600;
}

.tabs button.active {
  color: var(--accent);
}
</style>
