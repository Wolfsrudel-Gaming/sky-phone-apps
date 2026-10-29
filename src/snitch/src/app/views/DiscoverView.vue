<script setup lang="ts">
import { RadioTower, RefreshCw } from 'lucide-vue-next'
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { rpc } from '@/shared/nui'
import type { StreamInfo } from '@/shared/types'
import SnitchLogo from '../components/SnitchLogo.vue'
import StreamCard from '../components/StreamCard.vue'
import UserAvatar from '../components/UserAvatar.vue'
import { categoryLabel, t } from '../i18n'
import { useSnitch } from '../store'
import { refreshThumbnails } from '../thumbnails'

const REFRESH_MS = 10000

const store = useSnitch()
const streams = ref<StreamInfo[]>([])
const loaded = ref(false)
const refreshing = ref(false)
const category = ref<string | null>(null)
let timer = 0

const categories = computed(() => store.config?.categories ?? [])
const visible = computed(() =>
  category.value ? streams.value.filter((stream) => stream.category === category.value) : streams.value,
)

function categoryName(id: string): string {
  return categoryLabel(categories.value.find((entry) => entry.id === id)?.label, id)
}

async function load(manual = false): Promise<void> {
  if (refreshing.value) return
  refreshing.value = manual
  const result = await rpc<{ streams: StreamInfo[] }>('streams:list')
  refreshing.value = false
  loaded.value = true
  if (!result.ok) return
  streams.value = result.data.streams
  void refreshThumbnails(result.data.streams)
}

onMounted(() => {
  void load()
  timer = window.setInterval(() => void load(), REFRESH_MS)
})

onBeforeUnmount(() => window.clearInterval(timer))
</script>

<template>
  <section class="screen screen--tabs">
    <div class="screen__scroll">
      <header class="page-header">
        <SnitchLogo :size="30" />
        <span class="discover__actions">
          <button
            class="icon-btn"
            :class="{ 'discover__refresh--spin': refreshing }"
            :aria-label="t('common.retry')"
            @click="load(true)"
          >
            <RefreshCw :size="20" />
          </button>
          <button
            v-if="store.account"
            class="discover__me"
            :aria-label="t('tabs.profile')"
            @click="store.openTab('profile')"
          >
            <UserAvatar :name="store.account.username" :color="store.account.avatarColor" :size="34" />
          </button>
        </span>
      </header>

      <div class="chips" role="tablist">
        <button
          class="chip"
          :class="{ 'chip--active': category === null }"
          role="tab"
          :aria-selected="category === null"
          @click="category = null"
        >
          {{ t('discover.all') }}
        </button>
        <button
          v-for="entry in categories"
          :key="entry.id"
          class="chip"
          :class="{ 'chip--active': category === entry.id }"
          role="tab"
          :aria-selected="category === entry.id"
          @click="category = entry.id"
        >
          {{ categoryLabel(entry.label, entry.id) }}
        </button>
      </div>

      <h2 v-if="visible.length" class="section-title">
        {{ t('discover.liveNow') }} · {{ visible.length }}
      </h2>

      <div v-if="visible.length" class="discover__list">
        <StreamCard
          v-for="stream in visible"
          :key="stream.id"
          :stream="stream"
          :category-name="categoryName(stream.category)"
          @open="store.go({ name: 'watch', streamId: stream.id })"
        />
      </div>

      <div v-else-if="loaded" class="discover__empty">
        <span class="discover__empty-icon"><RadioTower :size="30" /></span>
        <h2>{{ category ? t('discover.emptyCategory') : t('discover.emptyTitle') }}</h2>
        <p v-if="!category" class="muted">{{ t('discover.emptyText') }}</p>
        <button class="btn btn--primary" @click="store.openTab('live')">{{ t('discover.goLive') }}</button>
      </div>

      <div v-else class="discover__skeletons" aria-hidden="true">
        <span v-for="index in 2" :key="index" class="discover__skeleton" />
      </div>
    </div>
  </section>
</template>

<style scoped>
.discover__actions {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.discover__me {
  display: inline-flex;
  padding: 2px;
  border-radius: 50%;
}

.discover__refresh--spin svg {
  animation: spin 0.8s linear infinite;
}

.discover__list {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.discover__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-top: 56px;
  padding: 0 12px;
  text-align: center;
}

.discover__empty h2 {
  margin: 16px 0 6px;
  font-size: 19px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.discover__empty p {
  margin: 0 0 20px;
}

.discover__empty-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 72px;
  height: 72px;
  border-radius: 24px;
  background: var(--brand-soft);
  color: var(--brand);
}

.discover__skeletons {
  display: flex;
  flex-direction: column;
  gap: 20px;
  margin-top: 24px;
}

.discover__skeleton {
  display: block;
  aspect-ratio: 16 / 9;
  border-radius: var(--radius-l);
  background: linear-gradient(100deg, var(--surface) 30%, var(--surface-2) 50%, var(--surface) 70%);
  background-size: 200% 100%;
  animation: shimmer 1.4s linear infinite;
}

@keyframes shimmer {
  to {
    background-position: -200% 0;
  }
}
</style>
