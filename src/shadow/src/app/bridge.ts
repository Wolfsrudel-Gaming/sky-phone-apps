// Sky Phone custom-app bridge (protocol version 1, bridgeMode "sky").
// The phone sends context (theme, language, safe area) and pushes messages from
// our client script; we report readiness and the status-bar background.

import { reactive } from 'vue'

const PROTOCOL_VERSION = 1

export const appId = new URLSearchParams(location.search).get('skyPhoneAppId') ?? 'shadow'

export interface PhoneContext {
  colorScheme: 'dark' | 'light'
  language: string
  safeArea: { top: number; bottom: number; left: number; right: number }
}

export const phoneContext = reactive<PhoneContext>({
  colorScheme: 'dark',
  language: navigator.language || 'de',
  safeArea: { top: 44, bottom: 25, left: 0, right: 0 },
})

type MessageHandler = (payload: unknown) => void
const messageHandlers = new Set<MessageHandler>()
const pendingRequests = new Map<string, (response: { success: boolean; data?: unknown; error?: string }) => void>()
let requestSequence = 0

function post(message: Record<string, unknown>): void {
  if (window.parent === window) return
  window.parent.postMessage({ ...message, appId, protocolVersion: PROTOCOL_VERSION }, '*')
}

export function onPhoneMessage(handler: MessageHandler): () => void {
  messageHandlers.add(handler)
  return () => messageHandlers.delete(handler)
}

/** Delivers a message as if the phone had pushed it. Used by the browser preview. */
export function emitPhoneMessage(payload: unknown): void {
  messageHandlers.forEach((handler) => handler(payload))
}

export function requestPhone(method: string, payload?: unknown): Promise<{ success: boolean; data?: unknown; error?: string }> {
  if (window.parent === window) return Promise.resolve({ success: false, error: 'no_phone' })
  requestSequence += 1
  const requestId = `shadow-${requestSequence}`
  return new Promise((resolve) => {
    pendingRequests.set(requestId, resolve)
    post({ type: 'sky-phone-app:request', requestId, method, payload })
    window.setTimeout(() => {
      const pending = pendingRequests.get(requestId)
      if (!pending) return
      pendingRequests.delete(requestId)
      pending({ success: false, error: 'timeout' })
    }, 10000)
  })
}

/** Tells the phone which colour sits under its status bar so the icons stay readable. */
export function setStatusBarBackground(color: string | null): void {
  post({ type: 'sky-phone-app:status-bar-background', background: color })
}

function applyContext(context: Record<string, unknown>): void {
  if (context.colorScheme === 'dark' || context.colorScheme === 'light') {
    phoneContext.colorScheme = context.colorScheme
  }
  if (typeof context.language === 'string') {
    phoneContext.language = context.language
  }
  const safeArea = context.safeArea as PhoneContext['safeArea'] | undefined
  if (safeArea && typeof safeArea.top === 'number') {
    phoneContext.safeArea = { ...safeArea }
  }
}

window.addEventListener('message', (event: MessageEvent) => {
  if (event.source !== window.parent || window.parent === window) return
  const message = event.data as Record<string, unknown> | null
  if (!message || typeof message !== 'object') return
  if (message.appId !== appId || message.protocolVersion !== PROTOCOL_VERSION) return

  switch (message.type) {
    case 'sky-phone-app:context':
      applyContext((message.context ?? {}) as Record<string, unknown>)
      break
    case 'sky-phone-app:message':
      messageHandlers.forEach((handler) => handler(message.payload))
      break
    case 'sky-phone-app:response': {
      const requestId = message.requestId as string
      const pending = pendingRequests.get(requestId)
      if (pending) {
        pendingRequests.delete(requestId)
        pending({
          success: message.success === true,
          data: message.data,
          error: message.error as string | undefined,
        })
      }
      break
    }
  }
})

export function announceReady(): void {
  post({ type: 'sky-phone-app:ready' })
}
