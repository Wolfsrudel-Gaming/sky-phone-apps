export interface Split {
  gross: number
  fee: number
  tax: number
  net: number
}

/** Same rules as shared/split.lua: whole dollars, rounding favours the streamer. */
export function calculateSplit(
  gross: number,
  feePercent: number,
  taxPercent: number,
  taxBase: 'afterFee' | 'gross',
): Split {
  const whole = Math.floor(gross)
  const fee = Math.floor((whole * feePercent) / 100)
  const taxable = taxBase === 'gross' ? whole : whole - fee
  let tax = Math.floor((taxable * taxPercent) / 100)
  let net = whole - fee - tax
  if (net < 0) {
    tax = Math.max(0, tax + net)
    net = 0
  }
  return { gross: whole, fee, tax, net }
}
