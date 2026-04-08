# Contributing

PRs welcome. Here's how to get started.

## Contract Development

```bash
cd contracts
forge install  # installs OpenZeppelin
forge build
forge test -vvv
```

Deploy to Base Sepolia:
```bash
cp .env.example .env  # fill in keys
forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify
```

## SDK Development

```bash
cd sdk
npm install
npm run build
```

## What We Need

High impact, looking for contributors:
- **Reference frontend** — React app that reads contract events, shows tasks on a map, lets humans accept/submit
- **Python SDK** — port of the TypeScript SDK
- **Reputation system** — on-chain attestations via EAS
- **Dispute resolution** — optimistic arbitration mechanism
- **IPFS proof upload** — helper for pinning proof images to IPFS

Medium impact:
- Task categories & search
- Notification system (Telegram/email when task is accepted)
- Gas estimation helpers
- Multi-chain deployment scripts

## Guidelines

- Keep the contract simple. Complexity kills protocols.
- Tests required for contract changes.
- Use conventional commits.
