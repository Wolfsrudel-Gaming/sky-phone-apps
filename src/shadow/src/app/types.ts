export type Result<T = undefined> =
  | { ok: true; data: T }
  | { ok: false; error: string; remaining?: number }

export interface Channel {
  id: string
  label: Record<string, string>
}

export interface ChannelInfo extends Channel {
  count: number
  lastAt: number
}

export interface Status {
  installed: boolean
  police: boolean
  hasPin?: boolean
  unlocked?: boolean
  extracted?: boolean
  foreignPhone?: boolean
  lockedUntil?: number
  alias?: string
  aliasChangeAt?: number
  config: {
    appName: string
    channels: Channel[]
    pinLength: number
    aliasMode: 'custom' | 'random'
    aliasMinLength: number
    aliasMaxLength: number
    messageMaxLength: number
    lifetimeHours: number
    crackSeconds: number
  }
}

export interface Message {
  id: number
  alias: string
  body: string
  isAd: boolean
  createdAt: number
  mine: boolean
}

export interface ThreadSummary {
  id: number
  alias: string
  topic: string
  lastBody: string | null
  lastAt: number
}
