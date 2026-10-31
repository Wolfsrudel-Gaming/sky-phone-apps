import { reactive } from 'vue'
import { nui } from './nui'
import type { Result, Status } from './types'

export type Screen =
  | { name: 'boot' }
  | { name: 'lock' }
  | { name: 'channels' }
  | { name: 'feed'; channel: string }
  | { name: 'threads' }
  | { name: 'thread'; threadId: number }
  | { name: 'settings' }

export const state = reactive({
  status: null as Status | null,
  screen: { name: 'boot' } as Screen,
  bootError: '',
})

export function rpc<T = undefined>(name: string, payload: unknown = {}): Promise<Result<T>> {
  return nui<T>('rpc', { name, payload })
}

export const readOnly = () => state.status?.extracted === true && state.status?.unlocked !== true

export async function refreshStatus(): Promise<void> {
  const result = await rpc<Status>('status')
  if (!result.ok) {
    state.bootError = result.error
    return
  }
  state.status = result.data
  const open = result.data.unlocked || result.data.extracted
  if (!open) {
    state.screen = { name: 'lock' }
  } else if (state.screen.name === 'boot' || state.screen.name === 'lock') {
    state.screen = { name: 'channels' }
  }
}

export function go(screen: Screen): void {
  state.screen = screen
}
