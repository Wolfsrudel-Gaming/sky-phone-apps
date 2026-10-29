<script setup lang="ts">
import { SendHorizontal } from 'lucide-vue-next'
import { computed, ref } from 'vue'

const props = defineProps<{ placeholder: string; maxLength: number; disabled?: boolean }>()
const emit = defineEmits<{ send: [text: string] }>()

const text = ref('')
const canSend = computed(() => !props.disabled && text.value.trim().length > 0)

function submit(): void {
  if (!canSend.value) return
  emit('send', text.value.trim())
  text.value = ''
}
</script>

<template>
  <form class="chat-input" @submit.prevent="submit">
    <input
      v-model="text"
      class="chat-input__field"
      type="text"
      :placeholder="placeholder"
      :maxlength="maxLength"
      :disabled="disabled"
      enterkeyhint="send"
      autocomplete="off"
    />
    <button class="chat-input__send" type="submit" :disabled="!canSend" :aria-label="placeholder">
      <SendHorizontal :size="20" :stroke-width="2.4" />
    </button>
  </form>
</template>

<style scoped>
.chat-input {
  display: flex;
  gap: 8px;
  align-items: center;
  padding: 8px var(--gutter) calc(var(--safe-bottom) + 6px);
  border-top: 1px solid var(--line);
  background: var(--bg);
}

.chat-input__field {
  flex: 1;
  min-width: 0;
  height: 44px;
  padding: 0 16px;
  border-radius: 999px;
  border: 1px solid var(--line);
  background: var(--surface-2);
  outline: none;
  transition: border-color 160ms var(--ease);
}

.chat-input__field:focus {
  border-color: var(--brand);
}

.chat-input__field::placeholder {
  color: var(--text-3);
}

.chat-input__send {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: var(--brand);
  color: var(--brand-ink);
  transition:
    opacity 160ms var(--ease),
    transform 120ms var(--ease);
}

.chat-input__send:disabled {
  opacity: 0.35;
}

.chat-input__send:active:not(:disabled) {
  transform: scale(0.92);
}
</style>
