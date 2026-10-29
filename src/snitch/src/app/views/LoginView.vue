<script setup lang="ts">
import { ChevronLeft } from 'lucide-vue-next'
import { computed, ref } from 'vue'
import { rpc } from '@/shared/nui'
import type { Account } from '@/shared/types'
import { errorText, t } from '../i18n'
import { useSnitch } from '../store'

const store = useSnitch()
const email = ref('')
const password = ref('')
const busy = ref(false)
const error = ref('')

const valid = computed(() => email.value.trim().includes('@') && password.value.length > 0)

async function submit(): Promise<void> {
  if (!valid.value || busy.value) return
  busy.value = true
  error.value = ''
  const result = await rpc<{ account: Account }>('auth:login', {
    email: email.value.trim(),
    password: password.value,
  })
  busy.value = false
  if (!result.ok) {
    error.value = errorText(result.error)
    password.value = ''
    return
  }
  store.signedIn(result.data.account)
}
</script>

<template>
  <section class="screen">
    <div class="screen__scroll">
      <header class="page-header">
        <button class="icon-btn" :aria-label="t('common.back')" @click="store.back()">
          <ChevronLeft :size="26" />
        </button>
      </header>
      <h1 class="page-title">{{ t('auth.loginTitle') }}</h1>
      <p class="muted auth-text">{{ t('auth.loginText') }}</p>

      <form @submit.prevent="submit">
        <label class="field">
          <span class="field__label">{{ t('auth.email') }}</span>
          <input
            v-model="email"
            class="field__input"
            type="email"
            autocomplete="email"
            autocapitalize="off"
            spellcheck="false"
          />
        </label>
        <label class="field">
          <span class="field__label">{{ t('auth.password') }}</span>
          <input v-model="password" class="field__input" type="password" autocomplete="current-password" />
        </label>

        <p v-if="error" class="form-error">{{ error }}</p>
        <button class="btn btn--primary btn--block" type="submit" :disabled="!valid || busy">
          {{ t('auth.login') }}
        </button>
      </form>

      <p class="auth-switch">
        {{ t('auth.noAccount') }}
        <button class="auth-switch__link" @click="store.replace({ name: 'register' })">
          {{ t('auth.createAccount') }}
        </button>
      </p>
    </div>
  </section>
</template>

<style scoped>
.auth-text {
  margin: 6px 0 24px;
}

.auth-switch {
  margin: 20px 0 0;
  color: var(--text-2);
  text-align: center;
  font-size: 14px;
}

.auth-switch__link {
  color: var(--text);
  font-weight: 700;
  text-decoration: underline;
  text-underline-offset: 3px;
}
</style>
