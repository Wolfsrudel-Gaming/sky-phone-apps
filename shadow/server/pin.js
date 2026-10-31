'use strict'

// PIN hashing runs in Node's thread pool so it never stalls the server tick.

const { randomBytes, scrypt, timingSafeEqual } = require('node:crypto')

const OPTIONS = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 }

exports('hashPin', (pin, callback) => {
  if (typeof callback !== 'function') return
  if (typeof pin !== 'string' || !/^\d{4,6}$/.test(pin)) return callback(false)
  const salt = randomBytes(16)
  scrypt(pin, salt, 32, OPTIONS, (error, key) => {
    if (error) return callback(false)
    callback(`${salt.toString('base64')}$${key.toString('base64')}`)
  })
})

exports('verifyPin', (pin, encoded, callback) => {
  if (typeof callback !== 'function') return
  if (typeof pin !== 'string' || typeof encoded !== 'string') return callback(false)
  const [salt, hash] = encoded.split('$')
  const expected = Buffer.from(hash ?? '', 'base64')
  if (!salt || expected.length !== 32) return callback(false)
  scrypt(pin, Buffer.from(salt, 'base64'), 32, OPTIONS, (error, key) => {
    callback(!error && timingSafeEqual(key, expected))
  })
})
