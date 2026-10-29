import './styles.css'
import { createPinia } from 'pinia'
import { createApp, watchEffect } from 'vue'
import { isBrowserPreview, nui } from '@/shared/nui'
import App from './App.vue'
import { announceReady, phoneContext } from './bridge'
import { connectPushes, useSnitch } from './store'

function isEditable(target: EventTarget | null): boolean {
  return (
    target instanceof HTMLTextAreaElement ||
    (target instanceof HTMLInputElement && !['button', 'checkbox', 'radio', 'submit'].includes(target.type))
  )
}

/** While a text field has focus the player must not walk or shoot (Sky Phone input contract). */
function trackTyping(): void {
  let typing = false
  const set = (next: boolean) => {
    if (typing === next) return
    typing = next
    void nui('input:typing', { typing: next })
  }
  document.addEventListener('focusin', (event) => {
    if (isEditable(event.target)) set(true)
  })
  document.addEventListener('focusout', (event) => {
    if (!isEditable(event.relatedTarget)) set(false)
  })
  window.addEventListener('pagehide', () => set(false))
}

async function boot(): Promise<void> {
  if (isBrowserPreview) {
    const { installMock } = await import('./mock')
    installMock()
  }

  const app = createApp(App)
  app.use(createPinia())
  app.mount('#app')

  const store = useSnitch()
  connectPushes(store)
  if (isBrowserPreview) (window as unknown as { snitch: typeof store }).snitch = store

  watchEffect(() => {
    const root = document.documentElement
    root.dataset.scheme = phoneContext.colorScheme
    root.lang = phoneContext.language.slice(0, 2)
    root.style.setProperty('--safe-top', `${phoneContext.safeArea.top}px`)
    root.style.setProperty('--safe-bottom', `${phoneContext.safeArea.bottom}px`)
  })

  trackTyping()
  announceReady()
  await store.init()
}

void boot()
