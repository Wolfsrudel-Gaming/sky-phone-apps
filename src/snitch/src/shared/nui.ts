import type { Result } from './types'

type NuiWindow = Window & { GetParentResourceName?: () => string }

const nuiWindow = window as NuiWindow

/** True outside FiveM, e.g. in `pnpm dev`. The app then runs against mock data. */
export const isBrowserPreview =
  !location.hostname.startsWith('cfx-nui-') &&
  typeof nuiWindow.GetParentResourceName !== 'function'

/** Resource name, taken from the page origin (https://cfx-nui-<resource>). */
export const resourceName = location.hostname.startsWith('cfx-nui-')
  ? location.hostname.slice('cfx-nui-'.length)
  : (nuiWindow.GetParentResourceName?.() ?? 'snitch')

type MockHandler = (name: string, data: unknown) => Promise<Result<unknown>>
let mockHandler: MockHandler | null = null

export function installNuiMock(handler: MockHandler): void {
  mockHandler = handler
}

/** Calls a RegisterNUICallback handler of this resource. Never throws. */
export async function nui<T = undefined>(
  name: string,
  data: unknown = {},
  timeoutMs = 20000,
): Promise<Result<T>> {
  if (mockHandler) return (await mockHandler(name, data)) as Result<T>

  const controller = new AbortController()
  const timeout = window.setTimeout(() => controller.abort(), timeoutMs)
  try {
    const response = await fetch(`https://${resourceName}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
      signal: controller.signal,
    })
    const result = (await response.json()) as Result<T> | null
    if (!result || typeof result !== 'object' || typeof result.ok !== 'boolean') {
      return { ok: false, error: 'invalid_response' }
    }
    return result
  } catch {
    return { ok: false, error: controller.signal.aborted ? 'timeout' : 'network' }
  } finally {
    window.clearTimeout(timeout)
  }
}

/** Calls a server request through the client script's `rpc` callback. */
export function rpc<T = undefined>(name: string, payload: unknown = {}): Promise<Result<T>> {
  return nui<T>('rpc', { name, payload })
}
