import './styles.css'
import { createApp, watchEffect } from 'vue'
import App from './App.vue'
import { announceReady, phoneContext } from './bridge'
import { isBrowserPreview, nui } from './nui'
import { refreshStatus } from './state'

function isEditable(target: EventTarget | null): boolean {
  return target instanceof HTMLTextAreaElement || target instanceof HTMLInputElement
}

/** While a text field has focus the player must not walk or shoot (Sky Phone input contract). */
function trackTyping(): void {
  let typing = false
  const set = (next: boolean) => {
    if (typing === next) return
    typing = next
    void nui('input:typing', { typing: next })
  }
  document.addEventListener('focusin', (event) => isEditable(event.target) && set(true))
  document.addEventListener('focusout', (event) => !isEditable(event.relatedTarget) && set(false))
  window.addEventListener('pagehide', () => set(false))
}

async function boot(): Promise<void> {
  if (isBrowserPreview) {
    const { installMock } = await import('./mock')
    installMock()
  }
  createApp(App).mount('#app')
  watchEffect(() => {
    const root = document.documentElement
    root.lang = phoneContext.language.slice(0, 2)
    root.style.setProperty('--safe-top', `${phoneContext.safeArea.top}px`)
    root.style.setProperty('--safe-bottom', `${phoneContext.safeArea.bottom}px`)
  })
  trackTyping()
  announceReady()
  await refreshStatus()
}

void boot()
