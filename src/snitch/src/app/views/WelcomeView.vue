<script setup lang="ts">
import SnitchLogo from '../components/SnitchLogo.vue'
import { t } from '../i18n'
import { useSnitch } from '../store'

const store = useSnitch()
</script>

<template>
  <section class="screen welcome">
    <div class="welcome__glow" aria-hidden="true" />
    <div class="welcome__content">
      <SnitchLogo :size="44" />
      <h1 class="welcome__title">{{ t('auth.welcomeTitle') }}</h1>
      <p class="welcome__text">{{ t('auth.welcomeText') }}</p>
    </div>
    <div class="welcome__actions">
      <button class="btn btn--primary btn--block" @click="store.go({ name: 'register' })">
        {{ t('auth.createAccount') }}
      </button>
      <button class="btn btn--ghost btn--block" @click="store.go({ name: 'login' })">
        {{ t('auth.login') }}
      </button>
    </div>
  </section>
</template>

<style scoped>
.welcome {
  justify-content: flex-end;
  padding: calc(var(--safe-top) + 24px) 24px calc(var(--safe-bottom) + 20px);
  background: var(--bg);
}

.welcome__glow {
  position: absolute;
  inset: -20% -40% 30%;
  background:
    radial-gradient(circle at 30% 40%, rgba(255, 210, 63, 0.35), transparent 45%),
    radial-gradient(circle at 75% 30%, rgba(255, 51, 85, 0.28), transparent 42%),
    radial-gradient(circle at 50% 70%, rgba(106, 61, 255, 0.25), transparent 50%);
  filter: blur(10px);
  animation: welcome-drift 14s ease-in-out infinite alternate;
}

@keyframes welcome-drift {
  from {
    transform: translate3d(-4%, 0, 0) scale(1);
  }
  to {
    transform: translate3d(4%, 3%, 0) scale(1.08);
  }
}

.welcome__content {
  position: relative;
  margin-bottom: 32px;
}

.welcome__title {
  margin: 28px 0 10px;
  font-size: 40px;
  font-weight: 900;
  line-height: 1.02;
  letter-spacing: -0.045em;
}

.welcome__text {
  margin: 0;
  max-width: 300px;
  color: var(--text-2);
  font-size: 16px;
}

.welcome__actions {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 10px;
}
</style>
