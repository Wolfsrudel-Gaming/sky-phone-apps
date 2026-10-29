import { nui } from '@/shared/nui'
import type { Signal } from '@/shared/types'

export type ViewerStatus = 'connecting' | 'connected' | 'reconnecting' | 'failed'

const MAX_ATTEMPTS = 4
const CONNECT_TIMEOUT_MS = 15000

/**
 * Receives one stream. The viewer offers receive-only audio and video; the
 * streamer's engine answers. Signalling runs through the FiveM server.
 */
export class ViewerConnection {
  readonly media = new MediaStream()
  private pc: RTCPeerConnection | null = null
  private pendingCandidates: RTCIceCandidateInit[] = []
  private attempts = 0
  private timeout = 0
  private retryTimer = 0
  private closed = false

  constructor(
    private readonly streamId: number,
    private readonly iceServers: RTCIceServer[],
    private readonly onStatus: (status: ViewerStatus) => void,
    private readonly onMedia: (media: MediaStream) => void,
  ) {}

  async start(): Promise<void> {
    if (this.closed) return
    this.retryTimer = 0
    this.teardown()
    this.attempts += 1
    this.onStatus(this.attempts === 1 ? 'connecting' : 'reconnecting')

    const pc = new RTCPeerConnection({ iceServers: this.iceServers, bundlePolicy: 'max-bundle' })
    this.pc = pc
    pc.addTransceiver('video', { direction: 'recvonly' })
    pc.addTransceiver('audio', { direction: 'recvonly' })

    pc.ontrack = (event) => {
      if (this.pc !== pc) return
      for (const track of this.media.getTracks()) {
        if (track.kind === event.track.kind) this.media.removeTrack(track)
      }
      this.media.addTrack(event.track)
      this.onMedia(this.media)
    }
    pc.onicecandidate = (event) => {
      if (event.candidate && this.pc === pc) {
        this.send({ kind: 'candidate', candidate: event.candidate.toJSON() })
      }
    }
    pc.onconnectionstatechange = () => {
      if (this.pc !== pc) return
      if (pc.connectionState === 'connected') {
        window.clearTimeout(this.timeout)
        this.attempts = 0
        this.onStatus('connected')
      } else if (pc.connectionState === 'failed') {
        this.retry()
      } else if (pc.connectionState === 'disconnected') {
        this.onStatus('reconnecting')
      }
    }

    const offer = await pc.createOffer()
    await pc.setLocalDescription(offer)
    if (this.pc !== pc) return
    this.send({ kind: 'offer', sdp: offer.sdp ?? '' })
    this.timeout = window.setTimeout(() => this.retry(), CONNECT_TIMEOUT_MS)
  }

  async handleSignal(signal: Signal): Promise<void> {
    const pc = this.pc
    if (!pc || this.closed) return
    if (signal.kind === 'answer') {
      if (pc.signalingState !== 'have-local-offer') return
      await pc.setRemoteDescription({ type: 'answer', sdp: signal.sdp }).catch(() => this.retry())
      for (const candidate of this.pendingCandidates.splice(0)) {
        await pc.addIceCandidate(candidate).catch(() => undefined)
      }
    } else if (signal.kind === 'candidate') {
      if (!pc.remoteDescription) {
        this.pendingCandidates.push(signal.candidate)
        return
      }
      await pc.addIceCandidate(signal.candidate).catch(() => undefined)
    }
  }

  close(): void {
    this.closed = true
    window.clearTimeout(this.retryTimer)
    this.teardown()
    this.media.getTracks().forEach((track) => this.media.removeTrack(track))
  }

  private retry(): void {
    if (this.closed || this.retryTimer) return
    if (this.attempts >= MAX_ATTEMPTS) {
      this.teardown()
      this.onStatus('failed')
      return
    }
    this.onStatus('reconnecting')
    this.retryTimer = window.setTimeout(() => void this.start(), 1000 * this.attempts)
  }

  /** Starts over after a failure, e.g. when the viewer taps "try again". */
  restart(): void {
    if (this.closed) return
    window.clearTimeout(this.retryTimer)
    this.attempts = 0
    void this.start()
  }

  private send(signal: Signal): void {
    void nui('watch:signal', { streamId: this.streamId, signal })
  }

  private teardown(): void {
    window.clearTimeout(this.timeout)
    this.pendingCandidates = []
    const pc = this.pc
    this.pc = null
    if (pc) {
      pc.ontrack = null
      pc.onicecandidate = null
      pc.onconnectionstatechange = null
      pc.close()
    }
  }
}
