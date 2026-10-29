import { defineStore } from 'pinia'
import { nui, rpc } from '@/shared/nui'
import type {
  Account,
  AppConfig,
  AppPush,
  Bootstrap,
  ChatMessage,
  ClientState,
  Earnings,
  LiveState,
  StreamInfo,
  StreamSummary,
} from '@/shared/types'
import { onPhoneMessage } from './bridge'
import { errorText } from './i18n'

export type ScreenName =
  | 'welcome'
  | 'register'
  | 'login'
  | 'discover'
  | 'watch'
  | 'golive'
  | 'live'
  | 'summary'
  | 'earnings'
  | 'profile'

export interface Screen {
  name: ScreenName
  streamId?: number
}

export type Tab = 'discover' | 'live' | 'earnings' | 'profile'

export interface LiveSession {
  stream: StreamInfo
  state: LiveState
  earnings: Earnings
  chat: ChatMessage[]
  viewers: number
  connections: number
  startedAt: number
}

const CHAT_LIMIT = 150
const TOAST_MS = 3200

let toastTimer = 0

export const useSnitch = defineStore('snitch', {
  state: () => ({
    ready: false,
    bootError: '' as string,
    config: null as AppConfig | null,
    account: null as Account | null,
    screen: { name: 'welcome' } as Screen,
    history: [] as Screen[],
    live: null as LiveSession | null,
    summary: null as (StreamSummary & { reason: string; title: string }) | null,
    toast: null as { text: string; kind: 'info' | 'error' | 'success' } | null,
  }),

  getters: {
    tab(state): Tab | null {
      switch (state.screen.name) {
        case 'discover':
          return 'discover'
        case 'golive':
        case 'live':
          return 'live'
        case 'earnings':
          return 'earnings'
        case 'profile':
          return 'profile'
        default:
          return null
      }
    },
    showsTabBar(state): boolean {
      return ['discover', 'golive', 'earnings', 'profile'].includes(state.screen.name)
    },
  },

  actions: {
    async init() {
      this.bootError = ''
      const [bootstrap, clientState] = await Promise.all([
        rpc<Bootstrap>('app:bootstrap'),
        nui<ClientState>('state'),
      ])
      if (!bootstrap.ok) {
        this.bootError = errorText(bootstrap.error)
        this.ready = true
        return
      }
      this.config = bootstrap.data.config

      if (bootstrap.data.loggedIn) {
        const status = await rpc<{ account: Account | false }>('auth:status')
        this.account = status.ok && status.data.account ? status.data.account : null
      }

      const live = bootstrap.data.live
      if (live && clientState.ok && clientState.data.live) {
        this.live = {
          stream: live.stream,
          state: clientState.data.live,
          earnings: live.earnings,
          chat: live.history.slice(-CHAT_LIMIT),
          viewers: live.stream.viewers,
          connections: 0,
          startedAt: Date.now() / 1000 - live.stream.uptime,
        }
      }

      this.screen = this.account ? { name: this.live ? 'live' : 'discover' } : { name: 'welcome' }
      this.history = []
      this.ready = true
    },

    go(screen: Screen) {
      this.history.push(this.screen)
      if (this.history.length > 20) this.history.shift()
      this.screen = screen
    },

    replace(screen: Screen) {
      this.screen = screen
    },

    back() {
      const previous = this.history.pop()
      this.screen = previous ?? { name: this.account ? 'discover' : 'welcome' }
    },

    openTab(tab: Tab) {
      this.history = []
      if (tab === 'live') {
        this.screen = { name: this.live ? 'live' : 'golive' }
        return
      }
      this.screen = { name: tab }
    },

    showToast(text: string, kind: 'info' | 'error' | 'success' = 'info') {
      this.toast = { text, kind }
      window.clearTimeout(toastTimer)
      toastTimer = window.setTimeout(() => {
        this.toast = null
      }, TOAST_MS)
    },

    signedIn(account: Account) {
      this.account = account
      this.history = []
      this.screen = { name: 'discover' }
    },

    async logout(everywhere = false) {
      await rpc('auth:logout', { everywhere })
      this.account = null
      this.live = null
      this.history = []
      this.screen = { name: 'welcome' }
    },

    startedLive(stream: StreamInfo, state: LiveState) {
      this.live = {
        stream,
        state,
        earnings: { gross: 0, net: 0, donations: 0 },
        chat: [],
        viewers: 0,
        connections: 0,
        startedAt: Date.now() / 1000,
      }
      this.history = []
      this.screen = { name: 'live' }
    },

    finishLive(reason: string, summary: StreamSummary | null) {
      const live = this.live
      if (!live) return
      this.live = null
      this.summary = {
        duration: summary?.duration ?? Math.round(Date.now() / 1000 - live.startedAt),
        peakViewers: summary?.peakViewers ?? live.viewers,
        uniqueViewers: summary?.uniqueViewers ?? live.viewers,
        gross: summary?.gross ?? live.earnings.gross,
        net: summary?.net ?? live.earnings.net,
        donations: summary?.donations ?? live.earnings.donations,
        reason,
        title: live.stream.title,
      }
      this.history = []
      this.screen = { name: 'summary' }
    },

    handlePush(message: AppPush) {
      const live = this.live
      switch (message.type) {
        case 'chat':
          if (live && live.stream.id === message.streamId) {
            live.chat.push(...message.messages)
            if (live.chat.length > CHAT_LIMIT) live.chat.splice(0, live.chat.length - CHAT_LIMIT)
          }
          break
        case 'room:state':
          if (live && live.stream.id === message.streamId) live.viewers = message.state.viewers
          break
        case 'live:state':
          if (live && message.state) live.state = message.state
          break
        case 'live:earnings':
          if (live && live.stream.id === message.streamId) live.earnings = message.earnings
          break
        case 'live:connections':
          if (live) live.connections = message.connected
          break
        case 'live:ended':
          if (live && live.stream.id === message.streamId) this.finishLive(message.reason, message.summary)
          break
      }
    },
  },
})

export function connectPushes(store: ReturnType<typeof useSnitch>): void {
  onPhoneMessage((payload) => {
    if (payload && typeof payload === 'object' && typeof (payload as AppPush).type === 'string') {
      store.handlePush(payload as AppPush)
    }
  })
}
