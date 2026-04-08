/**
 * Minimal example: create a task on PROXY
 *
 * PRIVATE_KEY=0x... npx tsx examples/create-task.ts
 */
import Proxy from '../sdk/src'

async function main() {
  const proxy = new Proxy({
    privateKey: process.env.PRIVATE_KEY!,
    network: 'base-sepolia',
  })

  console.log('Creating task...')

  const task = await proxy.create({
    title: 'Check if Blue Bottle Coffee on Mint Plaza is open right now',
    description: 'Walk by and confirm open/closed. Take a photo of the storefront.',
    bounty: 3,
    deadline: '2h',
    location: 'San Francisco, CA',
    proofRequired: ['photo'],
  })

  console.log(`✅ Task #${task.id} created!`)
  console.log('Waiting for someone to complete it...')

  const result = await task.waitForCompletion({ timeout: 600_000 })
  console.log(`Done! Status: ${result.status}, Proof: ${result.proofURI}`)

  await task.approve()
  console.log('Payment released.')
}

main().catch(console.error)
