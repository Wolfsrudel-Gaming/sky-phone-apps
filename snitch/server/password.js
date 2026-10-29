'use strict'

// Password hashing runs asynchronously in Node's thread pool so a login never
// stalls the server tick. Lua passes a callback that receives the result.

const { randomBytes, scrypt, timingSafeEqual } = require('node:crypto')

const KEY_LENGTH = 32
const COST = 16384
const BLOCK_SIZE = 8
const PARALLELISM = 1
const MAX_MEMORY = 64 * 1024 * 1024
const PREFIX = `scrypt$${COST}$${BLOCK_SIZE}$${PARALLELISM}`

function derive(password, salt, done) {
  scrypt(
    password,
    salt,
    KEY_LENGTH,
    { N: COST, r: BLOCK_SIZE, p: PARALLELISM, maxmem: MAX_MEMORY },
    done,
  )
}

exports('hashPassword', (password, callback) => {
  if (typeof callback !== 'function') return
  if (typeof password !== 'string' || password.length === 0 || password.length > 256) {
    callback(false)
    return
  }

  const salt = randomBytes(16)
  derive(password, salt, (error, key) => {
    if (error) {
      console.error('[snitch] Password hashing failed.', error.message)
      callback(false)
      return
    }
    callback(`${PREFIX}$${salt.toString('base64')}$${key.toString('base64')}`)
  })
})

exports('verifyPassword', (password, encoded, callback) => {
  if (typeof callback !== 'function') return
  if (typeof password !== 'string' || typeof encoded !== 'string') {
    callback(false)
    return
  }

  const parts = encoded.split('$')
  if (parts.length !== 6 || `${parts[0]}$${parts[1]}$${parts[2]}$${parts[3]}` !== PREFIX) {
    callback(false)
    return
  }

  const salt = Buffer.from(parts[4], 'base64')
  const expected = Buffer.from(parts[5], 'base64')
  if (salt.length !== 16 || expected.length !== KEY_LENGTH) {
    callback(false)
    return
  }

  derive(password, salt, (error, key) => {
    if (error) {
      console.error('[snitch] Password verification failed.', error.message)
      callback(false)
      return
    }
    callback(timingSafeEqual(key, expected))
  })
})
