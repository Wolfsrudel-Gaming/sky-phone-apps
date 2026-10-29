// Hidden full-screen page of the Snitch resource. It runs only while the player
// is live: it renders the phone camera picture at the stream resolution, sends
// it with the microphone to every viewer and posts a small preview image.

import { createGameView, type GameView } from '@/shared/gameView'
import { nui } from '@/shared/nui'
import type { Signal } from '@/shared/types'
import { StreamHost } from './host'

interface VideoConfig {
  Width: number
  Height: number
  Fps: number
  MaxBitrateKbps: number
}

type EngineMessage =
  | {
      type: 'start'
      requestId: number
      streamId: number
      video: VideoConfig
      iceServers: RTCIceServer[]
      audio: boolean
      thumbnailIntervalSeconds: number
    }
  | { type: 'stop' }
  | { type: 'pause' }
  | { type: 'resume' }
  | { type: 'mute'; muted: boolean }
  | { type: 'talking'; talking: boolean }
  | { type: 'signal'; from: number; signal: Signal }
  | { type: 'peer-left'; viewer: number }

interface Session {
  streamId: number
  view: GameView
  video: MediaStreamTrack
  microphone: MediaStream | null
  host: StreamHost
  frameInterval: number
  animation: number
  thumbnailTimer: number
  paused: boolean
  muted: boolean
  talking: boolean
}

const THUMBNAIL_WIDTH = 320
const THUMBNAIL_HEIGHT = 180
const MICROPHONE_TIMEOUT_MS = 8000

let session: Session | null = null
/** Bumped by every start and stop, so a start that is still awaiting can tell it was cancelled. */
let generation = 0
const thumbnailCanvas = document.createElement('canvas')
thumbnailCanvas.width = THUMBNAIL_WIDTH
thumbnailCanvas.height = THUMBNAIL_HEIGHT

async function acquireMicrophone(): Promise<MediaStream | null> {
  if (!navigator.mediaDevices?.getUserMedia) return null
  const request = navigator.mediaDevices.getUserMedia({
    audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
  })
  const timeout = new Promise<null>((resolve) =>
    window.setTimeout(() => resolve(null), MICROPHONE_TIMEOUT_MS),
  )
  try {
    const stream = await Promise.race([request, timeout])
    if (!stream) {
      // A late permission grant must not leave the microphone open.
      void request.then((late) => late.getTracks().forEach((track) => track.stop())).catch(() => undefined)
    }
    return stream
  } catch (error) {
    console.warn('[snitch] Microphone unavailable; streaming without audio.', error)
    return null
  }
}

/** The game picture can take a few frames to arrive after the texture is created. */
function waitForGamePicture(view: GameView, timeoutMs: number): Promise<boolean> {
  const deadline = performance.now() + timeoutMs
  return new Promise((resolve) => {
    const check = () => {
      if (view.isLive()) {
        resolve(true)
      } else if (performance.now() > deadline) {
        resolve(false)
      } else {
        requestAnimationFrame(check)
      }
    }
    check()
  })
}

function applyAudioGate(current: Session): void {
  const enabled = current.talking && !current.muted
  current.microphone?.getAudioTracks().forEach((track) => {
    track.enabled = enabled
  })
}

function renderLoop(current: Session): void {
  let previous = 0
  const frame = (now: number) => {
    if (session !== current) return
    current.animation = requestAnimationFrame(frame)
    if (current.paused || now - previous < current.frameInterval) return
    previous = now
    current.view.render()
  }
  current.animation = requestAnimationFrame(frame)
}

function postThumbnail(current: Session): void {
  if (session !== current || current.paused) return
  const context = thumbnailCanvas.getContext('2d')
  if (!context) return
  context.drawImage(current.view.canvas, 0, 0, THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT)
  void nui('engine:thumbnail', { image: thumbnailCanvas.toDataURL('image/jpeg', 0.62) })
}

function stop(): void {
  generation += 1
  const current = session
  if (!current) return
  session = null
  cancelAnimationFrame(current.animation)
  window.clearInterval(current.thumbnailTimer)
  current.host.closeAll()
  current.video.stop()
  current.microphone?.getTracks().forEach((track) => track.stop())
  current.view.dispose()
}

async function start(message: Extract<EngineMessage, { type: 'start' }>): Promise<void> {
  stop()
  const startGeneration = generation
  let view: GameView | null = null
  let microphone: MediaStream | null = null
  let video: MediaStreamTrack | null = null
  try {
    view = createGameView()
    view.resize(message.video.Width, message.video.Height, window.innerWidth, window.innerHeight)
    const pictureReady = await waitForGamePicture(view, 1500)
    if (startGeneration !== generation) throw new Error('cancelled')
    if (!pictureReady) throw new Error('game_view_unavailable')

    const videoTrack = view.canvas.captureStream(message.video.Fps).getVideoTracks()[0]
    if (!videoTrack) throw new Error('capture_failed')
    videoTrack.contentHint = 'motion'
    video = videoTrack

    microphone = message.audio ? await acquireMicrophone() : null
    if (startGeneration !== generation) throw new Error('cancelled')
    const audioTrack = microphone?.getAudioTracks()[0] ?? null
    const host = new StreamHost({
      iceServers: message.iceServers,
      fps: message.video.Fps,
      maxBitrateKbps: message.video.MaxBitrateKbps,
      tracks: () => ({ video: videoTrack, audio: audioTrack }),
      send: (viewer, signal) => void nui('engine:signal', { to: viewer, signal }),
      onConnections: (connected) => void nui('engine:viewers', { connected }),
    })

    const current: Session = {
      streamId: message.streamId,
      view,
      video: videoTrack,
      microphone,
      host,
      frameInterval: 1000 / message.video.Fps - 2,
      animation: 0,
      thumbnailTimer: 0,
      paused: false,
      muted: false,
      talking: false,
    }
    session = current
    applyAudioGate(current)
    renderLoop(current)
    window.setTimeout(() => postThumbnail(current), 3000)
    current.thumbnailTimer = window.setInterval(
      () => postThumbnail(current),
      Math.max(15, message.thumbnailIntervalSeconds) * 1000,
    )

    void nui('engine:reply', { requestId: message.requestId, ok: true, audio: microphone !== null })
  } catch (error) {
    if (session?.view !== view) {
      video?.stop()
      microphone?.getTracks().forEach((track) => track.stop())
      view?.dispose()
    }
    const reason = error instanceof Error ? error.message : ''
    if (reason !== 'cancelled') console.error('[snitch] Could not start the stream.', error)
    const code = reason === 'game_view_unavailable' || reason === 'cancelled' ? reason : 'capture_failed'
    void nui('engine:reply', { requestId: message.requestId, ok: false, error: code })
  }
}

window.addEventListener('message', (event: MessageEvent<EngineMessage>) => {
  const message = event.data
  if (!message || typeof message !== 'object' || typeof message.type !== 'string') return

  switch (message.type) {
    case 'start':
      void start(message)
      return
    case 'stop':
      stop()
      return
  }

  const current = session
  if (!current) return
  switch (message.type) {
    case 'pause':
      // Black frames keep every connection open; viewers show a "be right back" screen.
      current.paused = true
      current.video.enabled = false
      break
    case 'resume':
      current.paused = false
      current.video.enabled = true
      break
    case 'mute':
      current.muted = message.muted === true
      applyAudioGate(current)
      break
    case 'talking':
      current.talking = message.talking === true
      applyAudioGate(current)
      break
    case 'signal':
      void current.host.handleSignal(message.from, message.signal)
      break
    case 'peer-left':
      current.host.removePeer(message.viewer)
      break
  }
})
