<script setup lang="ts">
import { ChevronLeft } from 'lucide-vue-next'
import { computed, ref } from 'vue'
import { rpc } from '@/shared/nui'
import type { Account } from '@/shared/types'
import { errorText, t } from '../i18n'
import { useSnitch } from '../store'

const store = useSnitch()
const limits = computed(
  () => store.config?.accounts ?? { usernameMinLength: 3, usernameMaxLength: 20, passwordMinLength: 8 },
)

const username = ref('')
const email = ref('')
const password = ref('')
const busy = ref(false)
const error = ref('')

const valid = computed(
  () =>
    new RegExp(`^[A-Za-z0-9_]{${limits.value.usernameMinLength},${limits.value.usernameMaxLength}}$`).test(
      username.value,
    ) &&
    /^[^\s@]+@[^\s@]+\.[A-Za-z]{2,}$/.test(email.value.trim()) &&
    password.value.length >= limits.value.passwordMinLength,
)

async function submit(): Promise<void> {
  if (!valid.value || busy.value) return
  busy.value = true
  error.value = ''
  const result = await rpc<{ account: Account }>('auth:register', {
    username: username.value,
    email: email.value.trim(),
    password: password.value,
  })
  busy.value = false
  if (!result.ok) {
    error.value = errorText(result.error)
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
      <h1 class="page-title">{{ t('auth.registerTitle') }}</h1>
      <p class="muted auth-text">{{ t('auth.registerText') }}</p>

      <form @submit.prevent="submit">
        <label class="field">
          <span class="field__label">{{ t('auth.username') }}</span>
          <input
            v-model="username"
            class="field__input"
            autocomplete="username"
            autocapitalize="off"
            spellcheck="false"
            :maxlength="limits.usernameMaxLength"
            placeholder="los_santos_live"
          />
          <span class="field__hint">
            {{ t('auth.usernameHint', { min: limits.usernameMinLength, max: limits.usernameMaxLength }) }}
          </span>
        </label>
        <label class="field">
          <span class="field__label">{{ t('auth.email') }}</span>
          <input
            v-model="email"
            class="field__input"
            type="email"
            autocomplete="email"
            autocapitalize="off"
            spellcheck="false"
            placeholder="name@ifruit.com"
          />
        </label>
        <label class="field">
          <span class="field__label">{{ t('auth.password') }}</span>
          <input v-model="password" class="field__input" type="password" autocomplete="new-password" />
          <span class="field__hint">{{ t('auth.passwordHint', { min: limits.passwordMinLength }) }}</span>
        </label>

        <p v-if="error" class="form-error">{{ error }}</p>
        <button class="btn btn--primary btn--block" type="submit" :disabled="!valid || busy">
          {{ t('auth.register') }}
        </button>
      </form>

      <p class="auth-switch">
        {{ t('auth.haveAccount') }}
        <button class="auth-switch__link" @click="store.replace({ name: 'login' })">{{ t('auth.login') }}</button>
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
