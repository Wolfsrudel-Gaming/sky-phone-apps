export type Result<T = undefined> =
  | { ok: true; data: T }
  | { ok: false; error: string }

export type AvatarColor = 'sunset' | 'ocean' | 'lime' | 'grape' | 'ember' | 'steel'

export interface PublicProfile {
  id: number
  username: string
  avatarColor: AvatarColor
}

export interface Account extends PublicProfile {
  email: string
  bio: string
  createdAt: number
  isPayoutOwner: boolean
}

export interface Category {
  id: string
  label: Record<string, string>
}

export interface AppConfig {
  categories: Category[]
  titleMaxLength: number
  chatMaxLength: number
  maxViewers: number
  pauseTimeoutSeconds: number
  donations: {
    minimum: number
    maximum: number
    presets: number[]
    messageMaxLength: number
    feePercent: number
    taxPercent: number
    taxBase: 'afterFee' | 'gross'
  }
  accounts: {
    usernameMinLength: number
    usernameMaxLength: number
    passwordMinLength: number
  }
}

export interface StreamInfo {
  id: number
  title: string
  category: string
  streamer: PublicProfile
  viewers: number
  uptime: number
  paused: boolean
  thumbnailVersion: number
}

export interface ChatMessage {
  id: number
  time: number
  kind: 'chat' | 'donation'
  user: PublicProfile & { role?: 'host' | 'viewer' }
  text: string
  amount?: number
}

export interface Earnings {
  gross: number
  net: number
  donations: number
}

export interface StreamSummary extends Earnings {
  duration: number
  peakViewers: number
  uniqueViewers: number
}

export interface LiveState {
  streamId: number
  paused: boolean
  muted: boolean
  front: boolean
  audio: boolean
}

export interface Bootstrap {
  loggedIn: boolean
  live: false | { stream: StreamInfo; earnings: Earnings; history: ChatMessage[] }
  config: AppConfig
}

export interface ClientState {
  live: false | LiveState
  watching: false | number
}

export type Signal =
  | { kind: 'offer' | 'answer'; sdp: string }
  | { kind: 'candidate'; candidate: RTCIceCandidateInit }

export interface EarningsSummary {
  totals: {
    donations: number
    gross: number
    fee: number
    tax: number
    net: number
    pending: number
  }
  streams: Array<{
    id: number
    title: string
    category: string
    peakViewers: number
    uniqueViewers: number
    startedAt: number
    endedAt: number
    donations: number
    gross: number
    fee: number
    tax: number
    net: number
  }>
  days: Array<{ day: string; gross: number; net: number }>
  supporters: Array<{ username: string; avatarColor: AvatarColor; total: number }>
  feePercent: number
  taxPercent: number
}

/** Messages the client script pushes into the app through Sky Phone. */
export type AppPush =
  | { type: 'chat'; streamId: number; messages: ChatMessage[] }
  | { type: 'room:state'; streamId: number; state: { viewers: number; paused: boolean } }
  | { type: 'room:ended'; streamId: number; reason: string }
  | { type: 'rtc:signal'; streamId: number; signal: Signal }
  | { type: 'live:state'; state: LiveState | false }
  | { type: 'live:earnings'; streamId: number; earnings: Earnings }
  | { type: 'live:ended'; streamId: number; reason: string; summary: StreamSummary }
  | { type: 'live:connections'; connected: number }
