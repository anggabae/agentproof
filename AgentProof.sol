// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal read interface for an ERC-721 contract.
/// @dev AgentProof only ever needs `balanceOf` — the Agent ID holding check.
///      Keeping the interface this small means there is nothing else the
///      registry can do with the Agent ID contract: no transfers, no
///      approvals, no writes of any kind.
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentProof — an on-chain work-attestation registry for Agent ID holders
/// @author CUILANSENG
/// @notice AgentProof lets AI agents that hold a Binance Agent ID record
///         tamper-proof attestations of completed work — a proof hash plus a
///         short note — and daily check-ins, building a public, auditable
///         track record that is keyed to the agent's own wallet address and
///         readable by anyone, forever, without trusting any server.
///
/// @dev DESIGN — read this before judging the contract:
///
///      1. THE AGENT ID GATE IS THE PRODUCT.
///         Writing (attest / checkIn) is restricted to addresses that hold an
///         Agent ID — the non-transferable ERC-721 identity (SPACE ID) issued
///         to Binance Agentic Wallet users, one per KYC. The gate is a single
///         on-chain check, `IAgentID(agentIdContract).balanceOf(msg.sender) > 0`,
///         executed inside the transaction. There is no allowlist to manage,
///         no admin who can add or remove writers, and no way to write under
///         an identity you do not hold. Because an Agent ID cannot be
///         transferred or bought, an attestation history cannot be purchased
///         either — reputation here is earned, not acquired.
///
///      2. NO FUNDS. EVER.
///         The contract has no payable function, no receive/fallback, no
///         transfer logic, and never asks for token approvals. It cannot hold,
///         move, or lose user assets. The worst possible bug in this contract
///         is a wrong record — never a lost coin.
///
///      3. NO ADMIN. NO OWNER. NO UPGRADES.
///         There is deliberately no owner, no privileged role, and no proxy.
///         Nobody — including the deployer — can edit or delete another
///         agent's attestations, pause the registry, or change the Agent ID
///         contract it points to (the address is `immutable`, fixed at
///         deployment). What is deployed is what runs, permanently.
///
///      4. ADDRESS-KEYED BY DESIGN.
///         Records are stored and read by wallet address. The contract never
///         resolves names to addresses and offers no lookup-by-name feature.
///
///      5. READS ARE FREE AND OPEN.
///         Every view is public: clients, marketplaces, and other agents can
///         verify an address's attestation count, read its history, and watch
///         the global counters without any permission.
contract AgentProof {
    /// @notice One work attestation recorded by an agent.
    /// @param proofHash Hash of the off-chain proof (deliverable, receipt,
    ///        transcript, result file…). Storing the hash — not the document —
    ///        keeps the registry cheap and private-data-free while making the
    ///        record tamper-evident: the document either matches the hash or
    ///        it was changed after the fact.
    /// @param note Short human/agent-readable description of the work
    ///        (max 200 bytes, enforced on write).
    /// @param timestamp Block timestamp (seconds) when the attestation landed.
    struct Attestation {
        bytes32 proofHash;
        string note;
        uint64 timestamp;
    }

    /// @notice The Agent ID (SPACE ID ERC-721) contract used for the holding
    ///         gate. Production BSC address:
    ///         0x60b9262456de011f7d15a54cdd8c48baaa8b022f.
    /// @dev Immutable: the gate can never be re-pointed after deployment.
    IAgentID public immutable agentIdContract;

    /// @notice Per-agent attestation history, in recording order.
    mapping(address => Attestation[]) private _attestations;

    /// @notice Last UTC day (block.timestamp / 86400) an agent checked in.
    mapping(address => uint256) public lastCheckInDay;

    /// @notice True once an address has successfully attested or checked in.
    mapping(address => bool) public hasInteracted;

    /// @notice Number of distinct Agent ID addresses that have ever written.
    uint256 public totalAgents;

    /// @notice Total attestations recorded across all agents.
    uint256 public totalAttestations;

    /// @notice Emitted when an agent records a work attestation.
    /// @param index Position of the attestation in the agent's history.
    event Attested(
        address indexed agent,
        uint256 index,
        bytes32 proofHash,
        string note,
        uint64 timestamp
    );

    /// @notice Emitted when an agent checks in for a UTC day.
    /// @param day The UTC day number (block.timestamp / 86400).
    event CheckedIn(address indexed agent, uint256 day, uint64 timestamp);

    /// @param agentIdContract_ The Agent ID ERC-721 contract to gate on.
    constructor(address agentIdContract_) {
        require(agentIdContract_ != address(0), "AgentProof: zero address");
        agentIdContract = IAgentID(agentIdContract_);
    }

    /// @dev The Agent ID gate. Every write passes through here: the caller
    ///      must hold at least one Agent ID *at the moment of the call*.
    modifier onlyAgentIdHolder() {
        require(
            agentIdContract.balanceOf(msg.sender) > 0,
            "AgentProof: Agent ID required"
        );
        _;
    }

    /// @dev Marks the caller as an interacting agent exactly once, whichever
    ///      write (attest or checkIn) comes first.
    function _markInteracted(address agent) internal {
        if (!hasInteracted[agent]) {
            hasInteracted[agent] = true;
            totalAgents += 1;
        }
    }

    /// @notice Record an attestation of completed work.
    /// @param proofHash Hash of the off-chain proof of work (any bytes32 —
    ///        e.g. keccak256/sha256 of a deliverable or receipt).
    /// @param note Short description of the work, at most 200 bytes.
    function attest(bytes32 proofHash, string calldata note)
        external
        onlyAgentIdHolder
    {
        require(bytes(note).length <= 200, "AgentProof: note too long");
        Attestation memory entry = Attestation({
            proofHash: proofHash,
            note: note,
            timestamp: uint64(block.timestamp)
        });
        _attestations[msg.sender].push(entry);
        uint256 index = _attestations[msg.sender].length - 1;
        totalAttestations += 1;
        _markInteracted(msg.sender);
        emit Attested(msg.sender, index, proofHash, note, entry.timestamp);
    }

    /// @notice Check in once per UTC day — a lightweight "this agent is
    ///         active" heartbeat that builds a verifiable activity streak.
    function checkIn() external onlyAgentIdHolder {
        uint256 today = block.timestamp / 86400;
        require(
            lastCheckInDay[msg.sender] < today,
            "AgentProof: already checked in today"
        );
        lastCheckInDay[msg.sender] = today;
        _markInteracted(msg.sender);
        emit CheckedIn(msg.sender, today, uint64(block.timestamp));
    }

    // ------------------------------------------------------------------ views

    /// @notice How many attestations an address has recorded.
    function attestationCount(address agent) external view returns (uint256) {
        return _attestations[agent].length;
    }

    /// @notice Read a single attestation by agent address and index.
    function getAttestation(address agent, uint256 index)
        external
        view
        returns (bytes32 proofHash, string memory note, uint64 timestamp)
    {
        Attestation storage entry = _attestations[agent][index];
        return (entry.proofHash, entry.note, entry.timestamp);
    }

    /// @notice Read a page of an agent's attestations, oldest first.
    /// @param offset Index to start from (0 = oldest).
    /// @param limit Maximum number of entries to return.
    function attestationsOf(
        address agent,
        uint256 offset,
        uint256 limit
    ) external view returns (Attestation[] memory page) {
        uint256 count = _attestations[agent].length;
        if (offset >= count || limit == 0) {
            return new Attestation[](0);
        }
        uint256 size = count - offset;
        if (size > limit) size = limit;
        page = new Attestation[](size);
        for (uint256 i = 0; i < size; i++) {
            page[i] = _attestations[agent][offset + i];
        }
        return page;
    }
}
