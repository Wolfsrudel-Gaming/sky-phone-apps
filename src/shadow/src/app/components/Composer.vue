<script setup lang="ts">
import { Megaphone, SendHorizontal } from 'lucide-vue-next'
import { ref } from 'vue'

const props = defineProps<{ placeholder: string; maxLength: number; allowAd?: boolean; adLabel?: string }>()
const emit = defineEmits<{ send: [body: string, ad: boolean] }>()

const body = ref('')
const ad = ref(false)

function submit(): void {
  const text = body.value.trim()
  if (!text) return
  emit('send', text, props.allowAd === true && ad.value)
  body.value = ''
  ad.value = false
}
</script>

<template>
  <form class="composer" @submit.prevent="submit">
    <button
      v-if="allowAd"
      type="button"
      class="composer__ad"
      :class="{ 'composer__ad--on': ad }"
      :aria-pressed="ad"
      :title="adLabel"
      @click="ad = !ad"
    >
      <Megaphone :size="18" />
    </button>
    <input v-model="body" class="composer__input" :placeholder="placeholder" :maxlength="maxLength" autocomplete="off" />
    <button class="composer__send" type="submit" :disabled="!body.trim()" :aria-label="placeholder">
      <SendHorizontal :size="19" />
    </button>
  </form>
</template>

<style scoped>
.composer {
  display: flex;
  gap: 8px;
  align-items: center;
  padding: 8px var(--gutter) calc(var(--safe-bottom) + 6px);
  border-top: 1px solid var(--line);
  background: var(--bg);
}

.composer__input {
  flex: 1;
  min-width: 0;
  height: 44px;
  padding: 0 14px;
  border-radius: 12px;
  border: 1px solid var(--line);
  background: var(--surface);
  outline: none;
}

.composer__input:focus {
  border-color: var(--accent);
}

.composer__send,
.composer__ad {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 12px;
}

.composer__send {
  background: var(--accent);
  color: var(--accent-ink);
}

.composer__send:disabled {
  opacity: 0.35;
}

.composer__ad {
  background: var(--surface-2);
  color: var(--text-3);
}

.composer__ad--on {
  background: rgba(255, 179, 64, 0.16);
  color: var(--ad);
}
</style>
