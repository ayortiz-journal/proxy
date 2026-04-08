# PROXY Launch Content

---

## Twitter/X Thread

**Tweet 1 (Hook):**

We just open-sourced PROXY — an on-chain protocol that lets AI agents hire humans for real-world tasks.

One SDK call. USDC escrow. No backend.

The gig economy, but the boss is an AI.

🧵👇

github.com/proxyprotocol/proxy

---

**Tweet 2 (Problem):**

AI agents keep getting smarter. But they still can't:

- Pick up your dry cleaning
- Check if a store is open
- Buy groceries
- Notarize a document
- Photograph a restaurant menu

The physical world is an API with no endpoint. Until now.

---

**Tweet 3 (How it works):**

How PROXY works:

1. Agent calls `proxy.create({ title, bounty, deadline })`
2. USDC gets locked in escrow on Base
3. Human accepts the task
4. Human completes + submits proof
5. Agent confirms → USDC released instantly

No server. No database. Just a contract.

---

**Tweet 4 (Code):**

```typescript
import Proxy from 'proxy-protocol'

const task = await proxy.create({
  title: 'Buy a coffee and deliver to 123 Main St',
  bounty: 15,  // USDC
  deadline: '4h',
})

const result = await task.waitForCompletion()
```

That's it. Your AI agent just hired a human.

---

**Tweet 5 (Integrations):**

Works with everything:

🦜 LangChain tool
🚢 CrewAI tool
🤖 OpenAI function calling
🔌 MCP server (Claude, ChatGPT)

Your agent framework already supports it.

---

**Tweet 6 (Why Base):**

Why Base?

- < $0.01 per transaction
- Native USDC
- Ethereum-compatible
- Fast finality

Perfect for micropayments. A $5 task shouldn't cost $5 in gas.

---

**Tweet 7 (CTA):**

The entire protocol is:

- 1 Solidity contract (~200 lines)
- 1 TypeScript SDK
- MIT licensed
- Zero dependencies beyond ethers.js

Star it. Fork it. Build on it.

github.com/proxyprotocol/proxy

---

## Hacker News Post

**Title:**

Show HN: PROXY – An open protocol for AI agents to hire humans (on-chain, USDC escrow)

**Text:**

Hey HN,

I built PROXY — an open protocol that lets AI agents post tasks for humans to complete in the physical world, with USDC escrow on Base (Ethereum L2).

The idea: agents are getting incredibly capable at digital tasks, but they still can't interact with the physical world. Need someone to pick up a package? Check if a store is open? Notarize a document? There's no API for that.

PROXY is that API. It's a single Solidity smart contract (~200 lines) that handles:

- Task posting by agents (via SDK)
- Task acceptance by human workers
- USDC escrow (locked on creation, released on confirmation)
- Proof submission (IPFS links, photos, etc.)
- Dispute flagging

There's no backend server, no database, no centralized infra. The contract IS the backend. Events are the API. Anyone can build a frontend.

The SDK is designed to be dead simple:

```typescript
import Proxy from 'proxy-protocol'

const task = await proxy.create({
  title: 'Photograph the menu at the new ramen shop',
  bounty: 8,
  deadline: '24h',
  location: 'San Francisco, CA',
  proofRequired: ['photo'],
})
```

We also ship integrations for LangChain, CrewAI, OpenAI function calling, and an MCP server so Claude/ChatGPT can hire humans directly from chat.

Why Base? Transactions cost < $0.01, USDC is native, and it's EVM-compatible. A $5 task shouldn't incur $5 in gas.

The protocol takes a 2.5% fee on completed tasks (goes to a treasury multisig, eventually a DAO).

Everything is MIT licensed. Looking for contributors, especially for:
- Reference frontend (React, reads contract events, shows tasks on a map)
- Python SDK
- Reputation system
- Dispute resolution mechanism

Repo: github.com/proxyprotocol/proxy

Would love feedback on the contract design and the overall approach. Is this something you'd use in your agent workflows?

---

## Reddit Posts

### r/ethereum / r/ethdev

**Title:** PROXY: On-chain protocol for AI agents to hire humans (Solidity + USDC escrow on Base)

Just open-sourced a protocol that creates a permissionless marketplace between AI agents and human workers. Single Solidity contract, USDC escrow, TypeScript/Python SDKs. Looking for contributors on the frontend and reputation system.

### r/LangChain / r/LocalLLaMA

**Title:** Built a LangChain/CrewAI tool that lets your AI agent hire real humans for physical tasks

Your agent can now call `hire_human("pick up my dry cleaning")` and a real person will do it — payment handled via USDC escrow on-chain. Ships with LangChain Tool, CrewAI Tool, OpenAI function calling, and MCP server. Open source.

### r/cryptocurrency

**Title:** The gig economy, but the boss is an AI — just open-sourced an on-chain protocol for AI agents to hire humans (USDC on Base)

---

## Farcaster / Warpcast Post

Just shipped PROXY — an on-chain protocol where AI agents hire humans.

One Solidity contract on Base. USDC escrow. TypeScript SDK.

`npm install proxy-protocol` and your agent can hire a human with one function call.

The gig economy is about to get weird.

github.com/proxyprotocol/proxy
