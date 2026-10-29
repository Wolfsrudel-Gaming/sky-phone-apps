// Browser preview (`pnpm dev`): fake server data and a local test stream so the
// app can be designed and checked without FiveM. Never loaded inside the game.
//
// URL options: ?mock=guest (logged out), ?scheme=light, ?lang=en, ?empty=1

import { StreamHost } from '@/engine/host'
import { installNuiMock } from '@/shared/nui'
import type {
  Account,
  AppConfig,
  ChatMessage,
  EarningsSummary,
  PublicProfile,
  Result,
  Signal,
  StreamInfo,
} from '@/shared/types'
import { emitPhoneMessage, phoneContext } from './bridge'

const params = new URLSearchParams(location.search)

const config: AppConfig = {
  categories: [
    { id: 'just_chatting', label: { de: 'Just Chatting', en: 'Just Chatting' } },
    { id: 'driving', label: { de: 'Autos & Fahren', en: 'Cars & Driving' } },
    { id: 'events', label: { de: 'Events', en: 'Events' } },
    { id: 'news', label: { de: 'News', en: 'News' } },
    { id: 'music', label: { de: 'Musik', en: 'Music' } },
    { id: 'business', label: { de: 'Business', en: 'Business' } },
    { id: 'irl', label: { de: 'IRL', en: 'IRL' } },
  ],
  titleMaxLength: 80,
  chatMaxLength: 200,
  maxViewers: 5,
  pauseTimeoutSeconds: 180,
  donations: {
    minimum: 10,
    maximum: 50000,
    presets: [50, 100, 500, 1000, 5000],
    messageMaxLength: 120,
    feePercent: 50,
    taxPercent: 15,
    taxBase: 'afterFee',
  },
  accounts: { usernameMinLength: 3, usernameMaxLength: 20, passwordMinLength: 8 },
}

let account: Account | null =
  params.get('mock') === 'guest'
    ? null
    : {
        id: 1,
        username: 'malte_live',
        email: 'malte@ifruit.com',
        avatarColor: 'ember',
        bio: 'Unterwegs in Los Santos.',
        createdAt: Date.now() / 1000 - 86400 * 40,
        isPayoutOwner: true,
      }

const people: PublicProfile[] = [
  { id: 11, username: 'vinewood_vibes', avatarColor: 'grape' },
  { id: 12, username: 'lsc_tuning', avatarColor: 'ocean' },
  { id: 13, username: 'weazel_jenny', avatarColor: 'sunset' },
  { id: 14, username: 'paleto_pete', avatarColor: 'lime' },
  { id: 15, username: 'grove_st_dre', avatarColor: 'steel' },
]

const streams: StreamInfo[] =
  params.get('empty') === '1'
    ? []
    : [
        { id: 101, title: 'Nachtfahrt über den Great Ocean Highway', category: 'driving', streamer: people[1], viewers: 4, uptime: 3720, paused: false, thumbnailVersion: 1 },
        { id: 102, title: 'Eilmeldung: Großeinsatz am Pier', category: 'news', streamer: people[2], viewers: 3, uptime: 610, paused: false, thumbnailVersion: 1 },
        { id: 103, title: 'Chillen am Vinewood Sign – kommt vorbei!', category: 'just_chatting', streamer: people[0], viewers: 2, uptime: 8420, paused: false, thumbnailVersion: 1 },
        { id: 104, title: 'Grove Street Block Party', category: 'events', streamer: people[4], viewers: 1, uptime: 1900, paused: true, thumbnailVersion: 0 },
      ]

const PALETTES: Record<number, [string, string, string]> = {
  101: ['#0d1b3d', '#ff7a3d', '#ffd23f'],
  102: ['#1a0d0d', '#ff3355', '#4d6bff'],
  103: ['#1d0d33', '#c27bff', '#ffd23f'],
}

function scene(context: CanvasRenderingContext2D, width: number, height: number, palette: [string, string, string], time: number): void {
  const sky = context.createLinearGradient(0, 0, 0, height)
  sky.addColorStop(0, palette[0])
  sky.addColorStop(0.65, palette[1])
  sky.addColorStop(1, palette[2])
  context.fillStyle = sky
  context.fillRect(0, 0, width, height)

  context.fillStyle = 'rgba(255, 240, 200, 0.85)'
  context.beginPath()
  context.arc(width * 0.72, height * 0.42, height * 0.11, 0, Math.PI * 2)
  context.fill()

  context.fillStyle = 'rgba(8, 6, 14, 0.92)'
  const count = 14
  for (let index = 0; index < count; index += 1) {
    const buildingWidth = width / count
    const buildingHeight = height * (0.25 + ((index * 37) % 11) / 22)
    context.fillRect(index * buildingWidth, height - buildingHeight, buildingWidth - 4, buildingHeight)
  }

  context.fillStyle = 'rgba(255, 210, 63, 0.9)'
  for (let index = 0; index < 60; index += 1) {
    const x = (index * 97) % width
    const y = height - ((index * 53) % Math.floor(height * 0.5))
    if ((index + Math.floor(time * 2)) % 3 === 0) context.fillRect(x, y, 4, 6)
  }

  context.fillStyle = '#2a2433'
  context.fillRect(0, height * 0.88, width, height * 0.12)
  context.fillStyle = '#ffd23f'
  for (let index = 0; index < 8; index += 1) {
    const x = ((index * width) / 6 - ((time * 220) % (width / 6)))
    context.fillRect(x, height * 0.935, width / 14, 4)
  }
}

function thumbnail(id: number): string {
  const canvas = document.createElement('canvas')
  canvas.width = 320
  canvas.height = 180
  const context = canvas.getContext('2d')
  if (!context) return ''
  scene(context, 320, 180, PALETTES[id] ?? ['#111', '#333', '#555'], id)
  return canvas.toDataURL('image/jpeg', 0.7)
}

const CHAT_LINES = [
  'Hammer Aussicht 🔥',
  'wo genau ist das?',
  'grüße aus Sandy Shores',
  'LOL',
  'mach mal die Selfie-Cam an',
  'fahr nicht so schnell 😅',
  'wie lange streamst du heute noch?',
  'erster!',
  'gg',
  'kann jemand mich abholen am Legion Square?',
]

let sequence = 1000
function chatMessage(user: PublicProfile, text: string, role: 'host' | 'viewer' = 'viewer'): ChatMessage {
  sequence += 1
  return { id: sequence, time: Date.now() / 1000, kind: 'chat', user: { ...user, role }, text }
}

function donationMessage(user: PublicProfile, amount: number, text: string): ChatMessage {
  sequence += 1
  return { id: sequence, time: Date.now() / 1000, kind: 'donation', user, amount, text }
}

function pick<T>(items: T[]): T {
  return items[Math.floor(Math.random() * items.length)]
}

// A local "streamer": a canvas scene sent through the real host/viewer WebRTC code.
class FakeBroadcast {
  private readonly canvas = document.createElement('canvas')
  private readonly host: StreamHost
  private animation = 0
  private readonly timers: number[] = []

  constructor(
    private readonly streamId: number,
    palette: [string, string, string],
  ) {
    this.canvas.width = 960
    this.canvas.height = 540
    const context = this.canvas.getContext('2d')
    const track = this.canvas.captureStream(30).getVideoTracks()[0]
    const start = performance.now()
    const draw = () => {
      this.animation = requestAnimationFrame(draw)
      if (context) scene(context, 960, 540, palette, (performance.now() - start) / 1000)
    }
    draw()
    this.host = new StreamHost({
      iceServers: [],
      fps: 30,
      maxBitrateKbps: 1500,
      tracks: () => ({ video: track, audio: null }),
      send: (_, signal) => {
        window.setTimeout(() => emitPhoneMessage({ type: 'rtc:signal', streamId: this.streamId, signal }), 20)
      },
      onConnections: () => undefined,
    })

    this.timers.push(
      window.setInterval(() => {
        emitPhoneMessage({ type: 'chat', streamId: this.streamId, messages: [chatMessage(pick(people), pick(CHAT_LINES))] })
      }, 2600),
      window.setInterval(() => {
        emitPhoneMessage({
          type: 'chat',
          streamId: this.streamId,
          messages: [donationMessage(pick(people), pick([100, 250, 500, 1000]), 'Weiter so!')],
        })
      }, 11000),
    )
  }

  signal(signal: Signal): void {
    void this.host.handleSignal(1, signal)
  }

  stop(): void {
    cancelAnimationFrame(this.animation)
    this.timers.forEach((timer) => window.clearInterval(timer))
    this.host.closeAll()
  }
}

let broadcast: FakeBroadcast | null = null
let liveTimers: number[] = []
let liveTotals = { gross: 0, net: 0, donations: 0 }
let liveStartedAt = 0

function ok<T>(data: T): Result<T> {
  return { ok: true, data }
}

function fail(error: string): Result<never> {
  return { ok: false, error }
}

const earnings: EarningsSummary = {
  totals: { donations: 38, gross: 48250, fee: 24125, tax: 3615, net: 20510, pending: 425 },
  streams: [
    { id: 9, title: 'Feierabend-Cruise durch Vinewood', category: 'driving', peakViewers: 5, uniqueViewers: 14, startedAt: Date.now() / 1000 - 86400, endedAt: Date.now() / 1000 - 86400 + 5400, donations: 12, gross: 15400, fee: 7700, tax: 1155, net: 6545 },
    { id: 8, title: 'Q&A mit der Community', category: 'just_chatting', peakViewers: 4, uniqueViewers: 9, startedAt: Date.now() / 1000 - 86400 * 3, endedAt: Date.now() / 1000 - 86400 * 3 + 3600, donations: 9, gross: 9850, fee: 4925, tax: 738, net: 4187 },
    { id: 7, title: 'Rennen am Flughafen', category: 'events', peakViewers: 5, uniqueViewers: 21, startedAt: Date.now() / 1000 - 86400 * 6, endedAt: Date.now() / 1000 - 86400 * 6 + 7200, donations: 17, gross: 23000, fee: 11500, tax: 1722, net: 9778 },
  ],
  days: [3, 6, 7, 10, 12, 13].map((offset, index) => {
    const date = new Date(Date.now() - offset * 86400000)
    const day = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
    const net = [4187, 9778, 1200, 2500, 650, 2195][index]
    return { day, gross: net * 2.35, net }
  }),
  supporters: [
    { username: 'vinewood_vibes', avatarColor: 'grape', total: 12500 },
    { username: 'lsc_tuning', avatarColor: 'ocean', total: 8000 },
    { username: 'weazel_jenny', avatarColor: 'sunset', total: 4250 },
  ],
  feePercent: 50,
  taxPercent: 15,
}

async function handle(name: string, data: unknown): Promise<Result<unknown>> {
  await new Promise((resolve) => window.setTimeout(resolve, 120))
  const body = (data ?? {}) as Record<string, unknown>

  if (name === 'rpc') {
    const payload = (body.payload ?? {}) as Record<string, unknown>
    switch (body.name) {
      case 'app:bootstrap':
        return ok({ loggedIn: account !== null, live: false, config })
      case 'auth:status':
        return ok({ account: account ?? false })
      case 'auth:register':
        account = {
          id: 1,
          username: String(payload.username),
          email: String(payload.email),
          avatarColor: 'sunset',
          bio: '',
          createdAt: Date.now() / 1000,
          isPayoutOwner: true,
        }
        return ok({ account })
      case 'auth:login':
        if (payload.password !== 'passwort123') return fail('invalid_credentials')
        account = { id: 1, username: 'malte_live', email: String(payload.email), avatarColor: 'ember', bio: '', createdAt: Date.now() / 1000 - 86400 * 40, isPayoutOwner: true }
        return ok({ account })
      case 'auth:logout':
        account = null
        return ok({})
      case 'profile:update':
        if (!account) return fail('not_logged_in')
        account = { ...account, ...(payload as Partial<Account>) }
        return ok({ account })
      case 'streams:list':
        return ok({ streams })
      case 'streams:thumbnail':
        return ok({ id: payload.id, version: 1, image: thumbnail(Number(payload.id)) })
      case 'chat:send':
        if (!account) return fail('not_logged_in')
        emitPhoneMessage({
          type: 'chat',
          streamId: payload.streamId,
          messages: [chatMessage(account, String(payload.text), broadcast ? 'viewer' : 'host')],
        })
        return ok({})
      case 'donate': {
        const amount = Number(payload.amount)
        if (amount > 25000) return fail('insufficient_funds')
        if (account) {
          emitPhoneMessage({
            type: 'chat',
            streamId: payload.streamId,
            messages: [donationMessage(account, amount, String(payload.message ?? ''))],
          })
        }
        return ok({})
      }
      case 'earnings:summary':
        return ok(earnings)
    }
    return fail('unknown_request')
  }

  switch (name) {
    case 'state':
      return ok({ live: false, watching: false })
    case 'watch:join': {
      const stream = streams.find((entry) => entry.id === body.streamId)
      if (!stream) return fail('stream_not_found')
      broadcast?.stop()
      broadcast = new FakeBroadcast(stream.id, PALETTES[stream.id] ?? ['#111', '#333', '#555'])
      return ok({
        stream,
        history: [
          chatMessage(people[3], 'Servus zusammen!'),
          chatMessage(stream.streamer, 'Willkommen im Stream 👋', 'host'),
          donationMessage(people[0], 500, 'Für den Sprit!'),
          chatMessage(people[4], pick(CHAT_LINES)),
        ],
        iceServers: [],
      })
    }
    case 'watch:signal':
      broadcast?.signal(body.signal as Signal)
      return ok(undefined)
    case 'watch:leave':
      broadcast?.stop()
      broadcast = null
      return ok({})
    case 'live:start': {
      const stream: StreamInfo = {
        id: 900,
        title: String(body.title),
        category: String(body.category),
        streamer: account ?? people[0],
        viewers: 0,
        uptime: 0,
        paused: false,
        thumbnailVersion: 0,
      }
      liveTotals = { gross: 0, net: 0, donations: 0 }
      liveStartedAt = Date.now() / 1000
      let viewers = 0
      liveTimers = [
        window.setInterval(() => {
          viewers = Math.min(5, viewers + 1)
          emitPhoneMessage({ type: 'room:state', streamId: 900, state: { viewers, paused: false } })
          emitPhoneMessage({ type: 'live:connections', connected: viewers })
        }, 3000),
        window.setInterval(() => {
          emitPhoneMessage({ type: 'chat', streamId: 900, messages: [chatMessage(pick(people), pick(CHAT_LINES))] })
        }, 2200),
        window.setInterval(() => {
          const amount = pick([100, 250, 500, 1000])
          liveTotals = {
            gross: liveTotals.gross + amount,
            net: liveTotals.net + amount - Math.floor(amount / 2) - Math.floor((amount - Math.floor(amount / 2)) * 0.15),
            donations: liveTotals.donations + 1,
          }
          emitPhoneMessage({ type: 'chat', streamId: 900, messages: [donationMessage(pick(people), amount, 'Mega Stream!')] })
          emitPhoneMessage({ type: 'live:earnings', streamId: 900, earnings: liveTotals })
        }, 7000),
      ]
      return ok({ stream, state: { streamId: 900, paused: false, muted: false, front: body.front === true, audio: true } })
    }
    case 'live:end':
      liveTimers.forEach((timer) => window.clearInterval(timer))
      liveTimers = []
      window.setTimeout(() => {
        emitPhoneMessage({
          type: 'live:ended',
          streamId: 900,
          reason: 'ended',
          summary: { duration: Date.now() / 1000 - liveStartedAt, peakViewers: 5, uniqueViewers: 7, ...liveTotals },
        })
      }, 200)
      return ok({})
    case 'live:mute':
      return ok({ streamId: 900, paused: false, muted: body.muted === true, front: false, audio: true })
    case 'live:camera':
      return ok({ streamId: 900, paused: false, muted: false, front: body.front === true, audio: true })
    case 'live:resume':
      return ok({ streamId: 900, paused: false, muted: false, front: false, audio: true })
    case 'input:typing':
      return ok({})
  }
  return fail('unknown_request')
}

export function installMock(): void {
  phoneContext.colorScheme = params.get('scheme') === 'light' ? 'light' : 'dark'
  phoneContext.language = params.get('lang') === 'en' ? 'en' : 'de'
  installNuiMock(handle)
  document.documentElement.classList.add('preview')
}
