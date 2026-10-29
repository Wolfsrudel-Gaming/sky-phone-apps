<script setup lang="ts">
import { computed } from 'vue'
import SnitchLogo from './components/SnitchLogo.vue'
import TabBar from './components/TabBar.vue'
import ToastBar from './components/ToastBar.vue'
import { t } from './i18n'
import { useSnitch } from './store'
import DiscoverView from './views/DiscoverView.vue'
import EarningsView from './views/EarningsView.vue'
import GoLiveView from './views/GoLiveView.vue'
import LiveView from './views/LiveView.vue'
import LoginView from './views/LoginView.vue'
import ProfileView from './views/ProfileView.vue'
import RegisterView from './views/RegisterView.vue'
import SummaryView from './views/SummaryView.vue'
import WatchView from './views/WatchView.vue'
import WelcomeView from './views/WelcomeView.vue'

const store = useSnitch()

const views = {
  welcome: WelcomeView,
  register: RegisterView,
  login: LoginView,
  discover: DiscoverView,
  watch: WatchView,
  golive: GoLiveView,
  live: LiveView,
  summary: SummaryView,
  earnings: EarningsView,
  profile: ProfileView,
}

const view = computed(() => views[store.screen.name])
const viewKey = computed(() => `${store.screen.name}:${store.screen.streamId ?? ''}`)
const viewProps = computed(() =>
  store.screen.name === 'watch' ? { streamId: store.screen.streamId ?? 0 } : {},
)
</script>

<template>
  <main class="app">
    <div v-if="!store.ready" class="boot">
      <SnitchLogo :size="56" :wordmark="false" class="boot__logo" />
    </div>
    <div v-else-if="store.bootError" class="boot">
      <SnitchLogo :size="48" :wordmark="false" />
      <p class="muted">{{ store.bootError }}</p>
      <button class="btn btn--primary" @click="store.init()">{{ t('common.retry') }}</button>
    </div>
    <template v-else>
      <Transition name="screen">
        <component :is="view" :key="viewKey" v-bind="viewProps" />
      </Transition>
      <TabBar v-if="store.showsTabBar && store.account" />
    </template>
    <ToastBar />
  </main>
</template>

<style scoped>
.app {
  position: relative;
  height: 100%;
  overflow: hidden;
  background: var(--bg);
}

.boot {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  padding: 24px;
  text-align: center;
}

.boot__logo {
  animation: live-pulse 1.4s ease-in-out infinite;
}
</style>
