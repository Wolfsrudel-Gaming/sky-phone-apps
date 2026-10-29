import { describe, expect, it } from 'vitest'
import { calculateSplit } from './split'

describe('calculateSplit', () => {
  it('takes the tax from the streamer share by default', () => {
    expect(calculateSplit(1000, 50, 15, 'afterFee')).toEqual({
      gross: 1000,
      fee: 500,
      tax: 75,
      net: 425,
    })
  })

  it('can tax the full donation', () => {
    expect(calculateSplit(1000, 50, 15, 'gross')).toEqual({
      gross: 1000,
      fee: 500,
      tax: 150,
      net: 350,
    })
  })

  it('rounds fee and tax down', () => {
    expect(calculateSplit(33, 50, 15, 'afterFee')).toEqual({
      gross: 33,
      fee: 16,
      tax: 2,
      net: 15,
    })
  })

  it('never pays out a negative amount', () => {
    expect(calculateSplit(100, 90, 50, 'gross')).toEqual({
      gross: 100,
      fee: 90,
      tax: 10,
      net: 0,
    })
  })
})
