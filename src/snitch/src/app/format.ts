import { locale } from './i18n'

const moneyFormatters = new Map<string, Intl.NumberFormat>()

export function money(amount: number): string {
  let formatter = moneyFormatters.get(locale.value)
  if (!formatter) {
    formatter = new Intl.NumberFormat(locale.value, {
      style: 'currency',
      currency: 'USD',
      maximumFractionDigits: 0,
    })
    moneyFormatters.set(locale.value, formatter)
  }
  return formatter.format(amount)
}

export function compactNumber(value: number): string {
  return new Intl.NumberFormat(locale.value, { notation: 'compact', maximumFractionDigits: 1 }).format(value)
}

/** 0:42, 12:05, 1:03:09 */
export function clock(totalSeconds: number): string {
  const seconds = Math.max(0, Math.floor(totalSeconds))
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const rest = seconds % 60
  const pad = (value: number) => value.toString().padStart(2, '0')
  return hours > 0 ? `${hours}:${pad(minutes)}:${pad(rest)}` : `${minutes}:${pad(rest)}`
}

/** 3 h 20 min, 45 min, 30 s */
export function duration(totalSeconds: number): string {
  const seconds = Math.max(0, Math.floor(totalSeconds))
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  if (hours > 0) return `${hours} h ${minutes} min`
  if (minutes > 0) return `${minutes} min`
  return `${seconds} s`
}

export function shortDate(unixSeconds: number): string {
  return new Intl.DateTimeFormat(locale.value, { day: 'numeric', month: 'short' }).format(unixSeconds * 1000)
}

export function longDate(unixSeconds: number): string {
  return new Intl.DateTimeFormat(locale.value, { month: 'long', year: 'numeric' }).format(unixSeconds * 1000)
}

export function weekday(isoDay: string): string {
  return new Intl.DateTimeFormat(locale.value, { weekday: 'narrow' }).format(new Date(`${isoDay}T12:00:00`))
}
