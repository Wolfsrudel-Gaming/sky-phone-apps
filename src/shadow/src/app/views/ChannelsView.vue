<script setup lang="ts">
import { ChevronRight, Hash, TriangleAlert } from 'lucide-vue-next'
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { label, relative, t } from '../i18n'
import { go, readOnly, rpc, state } from '../state'
import type { ChannelInfo } from '../types'

const channels = ref<ChannelInfo[]>([])
let timer = 0

async function load(): Promise<void> {
  const result = await rpc<{ channels: ChannelInfo[] }>('channels:list')
  if (result.ok) channels.value = result.data.channels
}

onMounted(() => {
  void load()
  timer = window.setInterval(load, 15000)
})
onBeforeUnmount(() => window.clearInterval(timer))
</script>

<template>
  <section class="screen">
    <header class="header">
      <h1>{{ state.status?.config.appName ?? 'Shadow' }}</h1>
      <span v-if="state.status?.alias" class="alias">{{ state.status.alias }}</span>
    </header>
    <p v-if="!readOnly() && !state.status?.hasPin" class="banner banner--warn">
      <TriangleAlert :size="16" /> {{ t('channels.noPin') }}
      <button @click="go({ name: 'settings' })">{{ t('channels.setPin') }}</button>
    </p>
    <div class="scroll">
      <button v-for="channel in channels" :key="channel.id" class="channel" @click="go({ name: 'feed', channel: channel.id })">
        <span class="channel__icon"><Hash :size="18" /></span>
        <span class="channel__text">
          <strong>{{ label(channel.label, channel.id) }}</strong>
          <span class="muted">
            {{ channel.count ? t('channels.today', { count: channel.count }) : t('channels.quiet') }}
            <template v-if="channel.lastAt"> · {{ relative(channel.lastAt) }}</template>
          </span>
        </span>
        <span v-if="channel.lastAt && Date.now() / 1000 - channel.lastAt < 900" class="channel__hot" />
        <ChevronRight :size="18" class="channel__chevron" />
      </button>
    </div>
  </section>
</template>

<style scoped>
.alias {
  max-width: 45%;
  overflow: hidden;
  padding: 5px 10px;
  border-radius: 999px;
  background: var(--accent-soft);
  color: var(--accent);
  font-family: var(--mono);
  font-size: 12px;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.channel {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 14px 4px;
  border-bottom: 1px solid var(--line);
  text-align: left;
}

.channel__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: var(--surface-2);
  color: var(--accent);
}

.channel__text {
  display: flex;
  flex: 1;
  flex-direction: column;
  font-size: 13px;
}

.channel__text strong {
  font-size: 16px;
}

.channel__hot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--accent);
  box-shadow: 0 0 10px var(--accent);
}

.channel__chevron {
  color: var(--text-3);
}
</style>
