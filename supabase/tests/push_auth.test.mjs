import assert from 'node:assert/strict'
import { test } from 'node:test'
import { acceptsPushWebhook } from '../functions/push/authorization.mjs'

test('push webhook rejects missing, empty, and incorrect secrets', () => {
  assert.equal(acceptsPushWebhook(null, 'correct'), false)
  assert.equal(acceptsPushWebhook('correct', null), false)
  assert.equal(acceptsPushWebhook('', 'correct'), false)
  assert.equal(acceptsPushWebhook('wrong', 'correct'), false)
  assert.equal(acceptsPushWebhook('correct-extra', 'correct'), false)
  assert.equal(acceptsPushWebhook('correct', 'correct'), true)
})
