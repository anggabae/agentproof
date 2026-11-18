# AgentProof

**An open, on-chain work-attestation registry for Agent ID holders.**

AI agents holding an Agent ID (the non-transferable ERC-721 identity issued
to Binance Agentic Wallet users) can record attestations of completed work —
a proof hash plus a short note — and daily check-ins on BNB Smart Chain.
Every record is public, timestamped, keyed to the agent's own wallet
address, and cannot be edited or deleted. Clients, marketplaces, and other
agents can verify an agent's track record without trusting any server.

> An Agent ID proves who an agent is. AgentProof proves what it has done.

## How it works

- **The gate is the product.** `attest()` and `checkIn()` require the caller
  to hold an Agent ID, checked on-chain at call time against the official
  Agent ID contract (`balanceOf > 0`). No allowlist, no admin, no sign-up.
- **No funds, ever.** The contract has no payable functions and no transfer
  or approval logic. It cannot hold, move, or lose assets.
- **No admin, no owner, no upgrades.** Nobody can edit another agent's
  record, pause the registry, or change the gate — its address is
  `immutable`.
- **Open reads.** Per-address histories, counts, check-ins, and global
  counters (`totalAgents`, `totalAttestations`) are free for anyone to read.
  Records are keyed by address; there is deliberately no name-to-address
  lookup.

## Repository layout

| Path | Contents |
|---|---|
| `contracts/AgentProof.sol` | The registry contract (single file, no dependencies) |
| `contracts/MockAgentID.sol` | Test-only mock — never deploy |
| `test/AgentProof.test.js` | Hardhat + ethers v6 test suite (12 tests) |
| `dashboard/index.html` | Read-only public dashboard (single static file) |
| `AGENT-KIT.md` | Integration guide for agent operators |
| `DESIGN.md` | Architecture, security posture, compliance checklist |
| `SUBMISSION.md` | Hackathon submission material |

## Build & test

```bash
npm install
npx hardhat compile   # solc 0.8.24, optimizer 200 runs
npx hardhat test      # 12 passing
```

## Status

Phase 1 complete: contract built and fully tested locally, dashboard and
integration kit ready. Deployment to BNB Smart Chain and BscScan source
verification are phase 2; the live contract address will be added here and
in `AGENT-KIT.md` once deployed.

## License

MIT

---

Built by CUILANSENG
