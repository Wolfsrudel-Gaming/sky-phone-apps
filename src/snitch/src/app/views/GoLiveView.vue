<script setup lang="ts">
import { Camera, Info, Mic, SwitchCamera, Users } from 'lucide-vue-next'
import { computed, ref } from 'vue'
import { nui } from '@/shared/nui'
import type { LiveState, StreamInfo } from '@/shared/types'
import { categoryLabel, errorText, t } from '../i18n'
import { useSnitch } from '../store'

const store = useSnitch()
const config = computed(() => store.config)

const title = ref('')
const category = ref(config.value?.categories[0]?.id ?? 'just_chatting')
const front = ref(false)
const busy = ref(false)
const error = ref('')

const valid = computed(() => title.value.trim().length > 0)

async function start(): Promise<void> {
  if (!valid.value || busy.value) return
  busy.value = true
  error.value = ''
  const result = await nui<{ stream: StreamInfo; state: LiveState }>(
    'live:start',
    { title: title.value.trim(), category: category.value, front: front.value },
    30000,
  )
  busy.value = false
  if (!result.ok) {
    error.value = errorText(result.error)
    return
  }
  store.startedLive(result.data.stream, result.data.state)
}
</script>

<template>
  <section class="screen screen--tabs">
    <div class="screen__scroll">
      <header class="page-header">
        <h1 class="page-title">{{ t('golive.title') }}</h1>
      </header>

      <form @submit.prevent="start">
        <label class="field">
          <span class="field__label">{{ t('golive.streamTitle') }}</span>
          <input
            v-model="title"
            class="field__input"
            :maxlength="config?.titleMaxLength ?? 80"
            :placeholder="t('golive.titlePlaceholder')"
          />
        </label>

        <span class="field__label">{{ t('golive.category') }}</span>
        <div class="chips golive__chips">
          <button
            v-for="entry in config?.categories ?? []"
            :key="entry.id"
            type="button"
            class="chip"
            :class="{ 'chip--active': category === entry.id }"
            @click="category = entry.id"
          >
            {{ categoryLabel(entry.label, entry.id) }}
          </button>
        </div>

        <span class="field__label">{{ t('golive.camera') }}</span>
        <div class="golive__cameras">
          <button
            type="button"
            class="golive__camera"
            :class="{ 'golive__camera--active': !front }"
            @click="front = false"
          >
            <Camera :size="22" />
            {{ t('golive.rear') }}
          </button>
          <button
            type="button"
            class="golive__camera"
            :class="{ 'golive__camera--active': front }"
            @click="front = true"
          >
            <SwitchCamera :size="22" />
            {{ t('golive.front') }}
          </button>
        </div>

        <ul class="golive__hints">
          <li class="notice"><Info :size="16" /> {{ t('golive.hintCamera') }}</li>
          <li class="notice"><Mic :size="16" /> {{ t('golive.hintMic') }}</li>
          <li class="notice">
            <Users :size="16" /> {{ t('golive.hintViewers', { count: config?.maxViewers ?? 5 }) }}
          </li>
        </ul>

        <p v-if="error" class="form-error">{{ error }}</p>
        <button class="btn btn--live btn--block golive__start" type="submit" :disabled="!valid || busy">
          <span class="live-dot" />
          {{ busy ? t('golive.starting') : t('golive.start') }}
        </button>
      </form>
    </div>
  </section>
</template>

<style scoped>
.golive__chips {
  margin-top: 6px;
  margin-bottom: 18px;
  flex-wrap: wrap;
  overflow: visible;
}

.golive__cameras {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin: 6px 0 18px;
}

.golive__camera {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 6px;
  padding: 14px 8px;
  border-radius: var(--radius-m);
  border: 2px solid transparent;
  background: var(--surface-2);
  color: var(--text-2);
  font-size: 14px;
  font-weight: 700;
  transition:
    border-color 160ms var(--ease),
    color 160ms var(--ease);
}

.golive__camera--active {
  border-color: var(--brand);
  color: var(--text);
  background: var(--brand-soft);
}

.golive__hints {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 0 0 20px;
  padding: 0;
  list-style: none;
}

.golive__start {
  min-height: 56px;
  font-size: 17px;
}
</style>
