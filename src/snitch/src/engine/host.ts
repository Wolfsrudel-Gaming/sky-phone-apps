import type { Signal } from '@/shared/types'

interface Peer {
  pc: RTCPeerConnection
  remoteReady: boolean
  pendingCandidates: RTCIceCandidateInit[]
}

export interface StreamHostOptions {
  iceServers: RTCIceServer[]
  fps: number
  maxBitrateKbps: number
  tracks: () => { video: MediaStreamTrack; audio: MediaStreamTrack | null }
  send: (viewer: number, signal: Signal) => void
  onConnections: (connected: number) => void
}

/**
 * One peer connection per viewer. The viewer sends an offer with receive-only
 * transceivers; the host answers and attaches its camera and microphone tracks.
 */
export class StreamHost {
  private readonly peers = new Map<number, Peer>()
  private connected = -1

  constructor(private readonly options: StreamHostOptions) {}

  async handleSignal(viewer: number, signal: Signal): Promise<void> {
    if (signal.kind === 'offer') {
      await this.answer(viewer, signal.sdp)
      return
    }
    if (signal.kind !== 'candidate') return

    const peer = this.peers.get(viewer)
    if (!peer) return
    if (!peer.remoteReady) {
      peer.pendingCandidates.push(signal.candidate)
      return
    }
    await peer.pc.addIceCandidate(signal.candidate).catch(() => undefined)
  }

  removePeer(viewer: number): void {
    const peer = this.peers.get(viewer)
    if (!peer) return
    this.peers.delete(viewer)
    peer.pc.onicecandidate = null
    peer.pc.onconnectionstatechange = null
    peer.pc.close()
    this.report()
  }

  closeAll(): void {
    for (const viewer of [...this.peers.keys()]) this.removePeer(viewer)
  }

  private async answer(viewer: number, sdp: string): Promise<void> {
    this.removePeer(viewer)
    const pc = new RTCPeerConnection({
      iceServers: this.options.iceServers,
      bundlePolicy: 'max-bundle',
    })
    const peer: Peer = { pc, remoteReady: false, pendingCandidates: [] }
    this.peers.set(viewer, peer)
    const current = () => this.peers.get(viewer) === peer

    pc.onicecandidate = (event) => {
      if (event.candidate && current()) {
        this.options.send(viewer, { kind: 'candidate', candidate: event.candidate.toJSON() })
      }
    }
    pc.onconnectionstatechange = () => {
      if (!current()) return
      if (pc.connectionState === 'failed' || pc.connectionState === 'closed') {
        this.removePeer(viewer)
        return
      }
      this.report()
    }

    try {
      await pc.setRemoteDescription({ type: 'offer', sdp })
      if (!current()) return
      peer.remoteReady = true

      const { video, audio } = this.options.tracks()
      for (const transceiver of pc.getTransceivers()) {
        const kind = transceiver.receiver.track.kind
        if (kind === 'video') {
          await transceiver.sender.replaceTrack(video)
          transceiver.direction = 'sendonly'
        } else if (kind === 'audio' && audio) {
          await transceiver.sender.replaceTrack(audio)
          transceiver.direction = 'sendonly'
        } else {
          transceiver.direction = 'inactive'
        }
      }

      const answer = await pc.createAnswer()
      await pc.setLocalDescription(answer)
      if (!current()) return
      this.options.send(viewer, { kind: 'answer', sdp: answer.sdp ?? '' })
      await this.limitVideo(pc)

      for (const candidate of peer.pendingCandidates.splice(0)) {
        await pc.addIceCandidate(candidate).catch(() => undefined)
      }
    } catch (error) {
      console.error('[snitch] Could not answer viewer', viewer, error)
      this.removePeer(viewer)
    }
  }

  private async limitVideo(pc: RTCPeerConnection): Promise<void> {
    for (const sender of pc.getSenders()) {
      if (sender.track?.kind !== 'video') continue
      const parameters = sender.getParameters()
      if (!parameters.encodings || parameters.encodings.length === 0) {
        parameters.encodings = [{}]
      }
      parameters.encodings[0].maxBitrate = this.options.maxBitrateKbps * 1000
      parameters.encodings[0].maxFramerate = this.options.fps
      await sender.setParameters(parameters).catch(() => undefined)
    }
  }

  private report(): void {
    let connected = 0
    for (const peer of this.peers.values()) {
      if (peer.pc.connectionState === 'connected') connected += 1
    }
    if (connected !== this.connected) {
      this.connected = connected
      this.options.onConnections(connected)
    }
  }
}
