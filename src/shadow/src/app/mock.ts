// Browser preview (`pnpm dev`) with fake data. Never loaded inside the game.
// URL options: ?mock=locked (PIN 1234), ?mock=police (seized phone), ?lang=en

import { phoneContext } from './bridge'
import { installNuiMock } from './nui'
import type { Message, Result, Status, ThreadSummary } from './types'

const mode = new URLSearchParams(location.search).get('mock')
const now = () => Math.floor(Date.now() / 1000)

const status: Status = {
  installed: true,
  police: mode === 'police',
  hasPin: mode !== null,
  unlocked: mode === null,
  extracted: false,
  foreignPhone: mode === 'police',
  lockedUntil: 0,
  alias: 'Grauer Fuchs #4821',
  aliasChangeAt: 0,
  config: {
    appName: 'Shadow',
    channels: [
      { id: 'general', label: { de: 'Allgemein', en: 'General' } },
      { id: 'jobs', label: { de: 'Aufträge', en: 'Jobs' } },
      { id: 'weapons', label: { de: 'Waffen', en: 'Weapons' } },
      { id: 'goods', label: { de: 'Ware', en: 'Goods' } },
      { id: 'vehicles', label: { de: 'Fahrzeuge', en: 'Vehicles' } },
      { id: 'intel', label: { de: 'Infos', en: 'Intel' } },
    ],
    pinLength: 4,
    aliasMode: 'custom',
    aliasMinLength: 3,
    aliasMaxLength: 20,
    messageMaxLength: 500,
    lifetimeHours: 72,
    crackSeconds: 5,
  },
}

let id = 100
const message = (alias: string, body: string, minutes: number, extra: Partial<Message> = {}): Message => ({
  id: ++id,
  alias,
  body,
  isAd: false,
  createdAt: now() - minutes * 60,
  mine: false,
  ...extra,
})

const channels: Record<string, Message[]> = {
  jobs: [
    message('Stiller Rabe #0193', 'Suche Fahrer mit schnellem Wagen, heute Nacht. Bezahlung stimmt.', 95, { isAd: true }),
    message('Kalter Hai #7710', 'Wer kennt jemanden bei der Hafenbehörde?', 42),
    message('Dunkler Wolf #3302', 'Brauche 2 Leute für einen Job im Norden. Erfahrung nötig. Nur ernst gemeinte Antworten.', 18, { isAd: true }),
    message('Grauer Fuchs #4821', 'Bin dabei, wenn es nicht in der Stadt ist.', 6, { mine: true }),
  ],
  weapons: [message('Leiser Falke #5521', 'Biete Eisen. Nur gegen Bargeld. Treffpunkt nach Absprache.', 30, { isAd: true })],
  intel: [message('Blinder Geist #1180', 'Viele Streifen am Legion Square heute. Vorsicht.', 3)],
}

const threads: ThreadSummary[] = [
  { id: 1, alias: 'Stiller Rabe #0193', topic: 'Suche Fahrer mit schnellem Wagen, heute Nacht.', lastBody: 'Treffpunkt schick ich dir.', lastAt: now() - 600 },
]
const threadMessages: Message[] = [
  message('Grauer Fuchs #4821', 'Ich hab einen Sultan RS. Wann?', 14, { mine: true }),
  message('Stiller Rabe #0193', 'Um 2. Treffpunkt schick ich dir.', 10),
]

const ok = <T>(data: T): Result<T> => ({ ok: true, data })

async function handle(name: string, data: unknown): Promise<Result<unknown>> {
  await new Promise((resolve) => setTimeout(resolve, 80))
  const { name: request, payload = {} } = data as { name: string; payload: Record<string, unknown> }
  if (name === 'input:typing') return ok({})
  switch (request) {
    case 'status':
      return ok(status)
    case 'pin:verify':
      if (payload.pin !== '1234') return { ok: false, error: 'wrong_pin', remaining: 3 }
      status.unlocked = true
      return ok({})
    case 'extract:start':
      return ok({ seconds: status.config.crackSeconds })
    case 'extract:finish':
      status.extracted = true
      return ok({ alias: status.alias })
    case 'channels:list':
      return ok({
        channels: status.config.channels.map((channel) => {
          const list = channels[channel.id] ?? []
          return { ...channel, count: list.length, lastAt: list.length ? list[list.length - 1].createdAt : 0 }
        }),
      })
    case 'channel:read': {
      const list = channels[payload.channel as string] ?? []
      return ok({ messages: list.filter((entry) => entry.id > Number(payload.after ?? 0)) })
    }
    case 'channel:post': {
      const list = (channels[payload.channel as string] ??= [])
      list.push(message(status.alias ?? '', String(payload.body), 0, { mine: true, isAd: payload.ad === true }))
      return ok({})
    }
    case 'thread:open':
      return ok({ threadId: 1 })
    case 'threads:list':
      return ok({ threads })
    case 'thread:read':
      return ok({
        thread: { alias: threads[0].alias, topic: threads[0].topic },
        messages: threadMessages.filter((entry) => entry.id > Number(payload.after ?? 0)),
      })
    case 'thread:send':
      threadMessages.push(message(status.alias ?? '', String(payload.body), 0, { mine: true }))
      return ok({})
    case 'alias:set':
      status.alias = String(payload.alias)
      return ok({ alias: status.alias })
    case 'pin:set':
      status.hasPin = payload.pin !== false
      return ok({ hasPin: status.hasPin })
  }
  return { ok: false, error: 'unknown_request' }
}

export function installMock(): void {
  phoneContext.language = new URLSearchParams(location.search).get('lang') === 'en' ? 'en' : 'de'
  installNuiMock(handle)
}
