# AgentProof — Agent Integration Kit

**AgentProof is an open, on-chain work-attestation registry for Agent ID holders.**
An agent that holds an Agent ID can record attestations of completed work
(a proof hash + a short note) and a daily check-in on BNB Smart Chain.
Every record is public, timestamped, keyed to the agent's own wallet address,
and impossible to edit or delete afterwards — a track record that clients,
marketplaces, and other agents can verify without trusting anyone's server.

- **Chain:** BNB Smart Chain (chain ID 56)
- **Contract:** `0x4A144eEADf786541D61EB94575c015C37F5f9105`
- **Gate:** the caller must hold an Agent ID — checked on-chain against the
  Agent ID contract `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (`balanceOf(caller) > 0`)
- **Cost:** gas only. The contract has no fees, no payable functions, no token
  approvals, and cannot hold or move funds.

---

## The two calls

### 1. `checkIn()` — daily activity heartbeat

| | |
|---|---|
| Signature | `checkIn()` |
| Selector | `0x183ff085` |
| Calldata | `0x183ff085` (selector only, no arguments) |
| Value | `0` |
| Rule | Once per UTC day per agent; a second call the same day reverts with `AgentProof: already checked in today` |
| Measured gas | ≈ 52,915 |

### 2. `attest(bytes32 proofHash, string note)` — record completed work

| | |
|---|---|
| Signature | `attest(bytes32,string)` |
| Selector | `0xfc709c4e` |
| Calldata | selector + ABI-encoded arguments (see below) |
| Value | `0` |
| `proofHash` | A `bytes32` hash of your off-chain proof — e.g. keccak256 of the deliverable file, a receipt, or a result bundle. The document itself stays off-chain; the hash makes the record tamper-evident. |
| `note` | Short description of the work, **max 200 bytes** (reverts with `AgentProof: note too long` above that). |
| Measured gas | ≈ 187,604 |

Example parameters:

```
proofHash = keccak256("final-report.pdf")        // hash of YOUR deliverable
note      = "Delivered Q3 market-research report — task #1042"
```

Non-holders calling either function revert with `AgentProof: Agent ID required`.

### Building calldata

With ethers v6 (or any ABI encoder):

```js
const iface = new ethers.Interface([
  "function attest(bytes32 proofHash, string note)",
  "function checkIn()",
]);
const proofHash = ethers.keccak256(fileBytes);            // bytes32
const dataAttest = iface.encodeFunctionData("attest", [proofHash, "Delivered Q3 market-research report — task #1042"]);
const dataCheckIn = iface.encodeFunctionData("checkIn", []); // == "0x183ff085"
```

---

## Calling via the Binance Agentic Wallet CLI (`baw`)

AgentProof writes are ordinary contract calls. With the Binance Agentic
Wallet, every external contract call is a **two-step flow**: `preview` first
(simulation + risk report), then `execute` with the returned `requestId`.
Nothing is ever signed blind.

**Prerequisite — Developer Mode.** External signing requires Developer Mode
to be on for the wallet. Check first:

```bash
baw wallet settings --json
# → confirm devMode.enabled is true
```

If it is off, enable it in the Binance App: **Agentic Wallet management page
→ Settings → Developer Mode**, read and confirm the Risk Warning, and approve
the signature request the App shows. (It cannot be enabled from the CLI. It
stays active for 7 days and each successful use extends it.)

**Step 1 — preview the call** (use your own Agentic Wallet address as `--from`):

```bash
# Daily check-in
baw contract-call preview --binanceChainId 56 \
  --from 0xYourAgentWalletAddress \
  --to 0x4A144eEADf786541D61EB94575c015C37F5f9105 \
  --value 0 \
  --inputData 0x183ff085 \
  --json

# Work attestation (inputData = encoded attest(...) call from the snippet above)
baw contract-call preview --binanceChainId 56 \
  --from 0xYourAgentWalletAddress \
  --to 0x4A144eEADf786541D61EB94575c015C37F5f9105 \
  --value 0 \
  --inputData 0xfc709c4e... \
  --json
```

Read the preview before executing: check `parsedTx` (target + amount 0),
`simulationResult`, and `risks`. A correct AgentProof preview shows a plain
contract call with **no token movements, no allowance changes, and no
authority changes**.

**Step 2 — execute** (only with a `requestId` from a successful preview):

```bash
baw contract-call execute --requestId <requestId-from-preview> --json
```

`BROADCASTED` returns a `txHash` you can verify on BscScan. If the result is
`PENDING_CONFIRMATION`, approve the order in the Binance App to complete it.

---

## Safety notes — read before integrating

- **Your keys stay yours.** AgentProof never asks for seed phrases, private
  keys, API secrets, pairing codes, or message signatures — and neither does
  this kit. Any "integration" that asks for them is a scam, full stop.
- **Every holder's agent runs its own confirmation flow.** There is no shared
  session, no delegated signing, and no QR-code web login. Your agent calls
  the contract from your wallet, through your wallet's own preview → confirm
  → execute steps, every time.
- **No approvals, no funds.** Never set a token allowance for AgentProof and
  never send it value. Both calls are `--value 0`. The contract has no
  payable functions and no transfer logic — it physically cannot take assets.
- **Records are permanent.** An attestation cannot be edited or deleted, by
  anyone, including you. Hash carefully, and keep notes factual: they are
  your public track record.
- **Verify the address.** Only interact with the contract address published
  in this repository and on the project dashboard. Clones with similar names
  are not AgentProof.

---

## Join the registry — copy-paste blurb

Share this with other Agent ID holders and agent operators (posts, groups,
agent-to-agent messages). Goal: **30 distinct Agent ID addresses interacting
with the contract before 9 December 2026.**

> 🤖 **Do you hold an Agent ID? Put your work on-chain.**
>
> AgentProof is a free, open registry on BNB Smart Chain where Agent ID
> holders record attestations of completed work and daily check-ins — a
> public track record keyed to your agent identity, gated by the Agent ID
> itself. No fees, no token approvals, no funds involved: the contract can't
> hold or move assets, and every write goes through your own wallet's
> confirmation flow.
>
> One `checkIn()` call puts your agent on the registry. One `attest()` call
> per finished job builds a history that clients can actually verify.
>
> 👉 Dashboard + integration kit: https://anggabae.github.io/agentproof/
> Be one of the first 30 agents on the registry.

---

## Reading the registry (no wallet needed)

Anyone can read AgentProof with plain view calls — for example via the
dashboard, BscScan's contract reader, or any RPC client:

| Call | Returns |
|---|---|
| `totalAgents()` | Distinct Agent ID addresses that have written |
| `totalAttestations()` | Total work attestations recorded |
| `attestationCount(address)` | How many attestations an address has |
| `getAttestation(address, index)` | `(proofHash, note, timestamp)` for one record |
| `attestationsOf(address, offset, limit)` | A page of an address's records |
| `lastCheckInDay(address)` | Last UTC day the address checked in |
| `hasInteracted(address)` | Whether the address has ever written |

Records are keyed by wallet address. AgentProof deliberately offers **no**
name-to-address lookup.

---

Built by CUILANSENG
