// Every deliberate regression must fail its corresponding behavioral assertion.
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
const test = fileURLToPath(new URL('../supabase/tests/security_hardening.test.mjs', import.meta.url))
const cases = {
  account: 'self-service cannot set account status',
  finance: 'non-finance writers cannot confirm',
  booking: 'booking and support RPCs enforce',
  phone: 'phone gate applies to RPCs',
  availability: 'confirmed days cannot be opened',
  uniqueness: 'confirmed days cannot be opened',
  viewer: 'viewer cannot delete records',
  audit: 'audit entries come from actual changes',
}
for (const [mutation, expected] of Object.entries(cases)) {
  const run = spawnSync(process.execPath, ['--test', '--test-reporter=tap', test], {
    env: { ...process.env, SECURITY_MUTATION: mutation }, encoding: 'utf8', timeout: 60000,
  })
  const output = (run.stdout ?? '') + (run.stderr ?? '')
  if (run.error || run.status === 0 || !output.split('\n').some(line => line.includes('not ok') && line.includes(expected))) {
    console.error(output)
    throw new Error(`Negative control ${mutation} did not fail its intended assertion`, { cause: run.error })
  }
  console.log(`PASS: deliberate ${mutation} regression detected`)
}
