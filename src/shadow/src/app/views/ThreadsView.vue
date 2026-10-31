<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { relative, t } from '../i18n'
import { go, rpc } from '../state'
import type { ThreadSummary } from '../types'

const threads = ref<ThreadSummary[]>([])
const loaded = ref(false)
let timer = 0

async function load(): Promise<void> {
  const result = await rpc<{ threads: ThreadSummary[] }>('threads:list')
  loaded.value = true
  if (result.ok) threads.value = result.data.threads
}

onMounted(() => {
  void load()
  timer = window.setInterval(load, 8000)
})
onBeforeUnmount(() => window.clearInterval(timer))
</script>

<template>
  <section class="screen">
    <header class="header"><h1>{{ t('threads.title') }}</h1></header>
    <div class="scroll">
      <p v-if="loaded && !threads.length" class="muted empty">{{ t('threads.empty') }}</p>
      <button v-for="thread in threads" :key="thread.id" class="thread" @click="go({ name: 'thread', threadId: thread.id })">
        <span class="thread__head">
          <strong>{{ thread.alias }}</strong>
          <span class="thread__time">{{ relative(thread.lastAt) }}</span>
        </span>
        <span class="thread__topic">„{{ thread.topic }}“</span>
        <span v-if="thread.lastBody" class="thread__last muted">{{ thread.lastBody }}</span>
      </button>
    </div>
  </section>
</template>

<style scoped>
.empty {
  margin-top: 40px;
  text-align: center;
}

.thread {
  display: flex;
  flex-direction: column;
  gap: 2px;
  width: 100%;
  padding: 14px 4px;
  border-bottom: 1px solid var(--line);
  text-align: left;
}

.thread__head {
  display: flex;
  justify-content: space-between;
}

.thread__head strong {
  color: var(--accent);
  font-family: var(--mono);
}

.thread__time {
  color: var(--text-3);
  font-size: 12px;
}

.thread__topic,
.thread__last {
  overflow: hidden;
  font-size: 13px;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.thread__topic {
  color: var(--text-3);
  font-style: italic;
}
</style>
