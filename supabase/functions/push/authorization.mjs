/** Accept only the database webhook's dedicated secret. Never use the public anon key. */
export function acceptsPushWebhook(provided, expected) {
  if (!provided || !expected) return false
  // Compare the full strings without returning on the first differing byte.
  const a = new TextEncoder().encode(provided)
  const b = new TextEncoder().encode(expected)
  let difference = a.length ^ b.length
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    difference |= (a[i] ?? 0) ^ (b[i] ?? 0)
  }
  return difference === 0
}
