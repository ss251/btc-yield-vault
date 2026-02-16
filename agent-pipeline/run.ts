import { RpcProvider, Account, CallData, hash, cairo, constants, ec } from "starknet";

// ─── Config ───────────────────────────────────────────────────────────────────
const XVERSE_API_KEY = process.env.XVERSE_API_KEY || "";
const XVERSE_BASE = "https://api.secretkeylabs.io";
const BTC_ADDRESS = "bc1qm34lsc65zpw79lxes69zkqmk6ee3ewf0j77s3";

const DEVNET_RPC = "http://localhost:5050";
const VAULT_ADDRESS = "0x00feed60bab3040d068f6d8976a2dc05b3e7b17bedaa88bc58d8382c4d85b3f2";
const PROOF_REGISTRY_ADDRESS = "0x03673bedfe85fd5f12b9fa5dcf06d84a05143cb7fb55a2367dee43215caed5b3";
const DEPLOYER_ADDRESS = "0x064b48806902a367c8598f4f95c305e8c1a1acba5f082d294a43793113115691";
const DEPLOYER_PRIVATE_KEY = "0x71d7bb07b9a64f6f78ac4c816aff4da9";

const REBALANCE_THRESHOLD_SATS = 10_000;

const ACTION_TYPE = { REBALANCE: 1, CATALOG: 2, SWAP: 3 } as const;

// ─── Logging ──────────────────────────────────────────────────────────────────
function log(msg: string) {
  const ts = new Date().toISOString().replace("T", " ").slice(0, 19);
  console.log(`[${ts}] [Agent] ${msg}`);
}

// ─── Xverse API ───────────────────────────────────────────────────────────────
interface PortfolioData {
  balanceSats: number;
  balanceBTC: number;
  utxoCount: number;
  ordinalCount: number;
  runeCount: number;
}

async function fetchXverse(path: string): Promise<any> {
  const url = `${XVERSE_BASE}${path}`;
  const res = await fetch(url, {
    headers: { "x-api-key": XVERSE_API_KEY, Accept: "application/json" },
  });
  if (!res.ok) throw new Error(`Xverse ${res.status}`);
  return res.json();
}

async function fetchPortfolio(): Promise<PortfolioData> {
  log(`Fetching BTC portfolio for ${BTC_ADDRESS.slice(0, 12)}...`);

  let balanceSats = 0, utxoCount = 0, ordinalCount = 0, runeCount = 0;

  // Try Xverse API; fall back to mock data
  try {
    const data = await fetchXverse(`/v1/address/${BTC_ADDRESS}/getBalance`);
    balanceSats = data?.totalBalance ?? data?.confirmed ?? 50_000_000;
  } catch {
    try {
      const data = await fetchXverse(`/v1/address/${BTC_ADDRESS}`);
      balanceSats = data?.chain_stats?.funded_txo_sum ?? 50_000_000;
    } catch {
      log("⚠ Using mock balance data (Xverse API path not found)");
      balanceSats = 50_000_000;
    }
  }

  try {
    const data = await fetchXverse(`/v1/address/${BTC_ADDRESS}/ordinals?offset=0&limit=1`);
    ordinalCount = data?.total ?? (Array.isArray(data?.results) ? data.results.length : 2);
  } catch { ordinalCount = 2; }

  try {
    const data = await fetchXverse(`/v1/address/${BTC_ADDRESS}/runes`);
    runeCount = data?.total ?? (Array.isArray(data?.results) ? data.results.length : 0);
  } catch { runeCount = 1; }

  utxoCount = 3; // mock

  const balanceBTC = balanceSats / 1e8;
  log(`Balance: ${balanceBTC} BTC, ${utxoCount} UTXOs, ${ordinalCount} Ordinals, ${runeCount} Runes`);
  return { balanceSats, balanceBTC, utxoCount, ordinalCount, runeCount };
}

// ─── Strategy ─────────────────────────────────────────────────────────────────
interface ProposedAction {
  actionType: number;
  label: string;
  amount: bigint;
  riskScore: number;
  proofHash: string;
}

/**
 * Deterministic strategy — MUST mirror the on-chain ProofRegistry logic exactly.
 * Priority: REBALANCE > CATALOG > SWAP > default.
 * The ZK proof contract will reject any action that doesn't match.
 */
function analyzePortfolio(data: PortfolioData): ProposedAction[] {
  // Priority 1: If balance > threshold → REBALANCE
  if (data.balanceSats > REBALANCE_THRESHOLD_SATS) {
    const amount = Math.min(Math.floor(data.balanceSats / 10), 5000);
    const risk = Math.max(Math.floor((amount * 100) / data.balanceSats) + 20, 30);
    return [{
      actionType: ACTION_TYPE.REBALANCE,
      label: `rebalance (amount: ${amount} sats, risk: ${risk})`,
      amount: BigInt(amount),
      riskScore: risk,
      proofHash: "0x0", // will be set by proof registry
    }];
  }

  // Priority 2: If ordinals > 0 → CATALOG
  if (data.ordinalCount > 0) {
    return [{
      actionType: ACTION_TYPE.CATALOG,
      label: `catalog ${data.ordinalCount} ordinals (risk: 10)`,
      amount: 0n,
      riskScore: 10,
      proofHash: "0x0",
    }];
  }

  // Priority 3: If runes > 0 → SWAP
  if (data.runeCount > 0) {
    return [{
      actionType: ACTION_TYPE.SWAP,
      label: `swap ${data.runeCount} rune(s) (risk: 40)`,
      amount: 1000n,
      riskScore: 40,
      proofHash: "0x0",
    }];
  }

  // Default
  return [{
    actionType: ACTION_TYPE.REBALANCE,
    label: "demo rebalance (amount: 100, risk: 5)",
    amount: 100n,
    riskScore: 5,
    proofHash: "0x0",
  }];
}

// ─── Low-level Starknet helpers ───────────────────────────────────────────────
function selectorFor(name: string): string {
  return hash.getSelectorFromName(name);
}

// ─── Main Pipeline ────────────────────────────────────────────────────────────
async function runPipeline() {
  console.log("\n" + "═".repeat(60));
  log("🚀 ZK-Constrained Autonomous Bitcoin Agent — Pipeline Start");
  console.log("═".repeat(60) + "\n");

  const provider = new RpcProvider({ nodeUrl: DEVNET_RPC, blockIdentifier: "latest" as any });

  try {
    await provider.getChainId();
    log("✅ Connected to Starknet devnet");
  } catch (e: any) {
    log(`❌ Cannot connect to devnet: ${e.message}`);
    process.exit(1);
  }

  const account = new Account({
    provider: provider,
    address: DEPLOYER_ADDRESS,
    signer: DEPLOYER_PRIVATE_KEY,
  });

  // Read vault state via raw callContract
  log("Reading vault state...");
  let totalActions: number;
  try {
    const raw = await provider.callContract({
      contractAddress: VAULT_ADDRESS,
      entrypoint: "get_agent_state",
      calldata: [],
    });
    // Flat result: [agent, daily_low, daily_high, timestamp, total_actions, max_daily_low, max_daily_high, allowed, max_single_low, max_single_high, risk_threshold, is_active]
    totalActions = Number(BigInt(raw[4]));
    log(`Vault: ${totalActions} total actions, risk_threshold=${Number(BigInt(raw[10]))}`);
  } catch (e: any) {
    log(`❌ Failed to read vault: ${e.message}`);
    process.exit(1);
  }

  // Fetch BTC portfolio
  console.log("");
  const portfolio = await fetchPortfolio();

  // Analyze
  console.log("");
  const actions = analyzePortfolio(portfolio);
  log(`Strategy: ${actions.length} action(s) to propose`);
  for (const a of actions) log(`  • ${a.label}`);

  // ── Compute portfolio commitment hash and submit to AgentVault ──
  const portfolioCommitHash = hash.computePedersenHash(
    hash.computePedersenHash(
      hash.computePedersenHash(
        hash.computePedersenHash("0x0", portfolio.balanceSats.toString()),
        portfolio.utxoCount.toString()
      ),
      portfolio.ordinalCount.toString()
    ),
    portfolio.runeCount.toString()
  );
  log(`Portfolio commit hash: ${portfolioCommitHash.slice(0, 18)}...`);

  log("→ Setting portfolio commitment on AgentVault...");
  try {
    const commitTx = await account.execute({
      contractAddress: VAULT_ADDRESS,
      entrypoint: "set_portfolio_commit",
      calldata: [portfolioCommitHash],
    });
    await provider.waitForTransaction(commitTx.transaction_hash);
    log(`→ Portfolio commitment set ✅`);
  } catch (e: any) {
    log(`⚠ Failed to set portfolio commit: ${e.message}`);
  }

  // Submit proofs, propose & approve
  console.log("");
  let successCount = 0;

  for (const action of actions) {
    try {
      // ── Step 1: Submit decision proof to ProofRegistry ──
      // The contract deterministically re-computes the expected action from
      // portfolio + strategy and verifies the agent's proposal matches.
      log(`→ Submitting ZK decision proof for ${action.label}`);

      // Portfolio input: [balance_sats, num_utxos, num_ordinals, num_runes]
      // Strategy params: [rebalance_threshold, max_risk]
      // Proposed action: [action_type, amount, risk_score]
      const proofTx = await account.execute({
        contractAddress: PROOF_REGISTRY_ADDRESS,
        entrypoint: "submit_proof",
        calldata: [
          portfolio.balanceSats.toString(),        // balance_sats
          portfolio.utxoCount.toString(),           // num_utxos
          portfolio.ordinalCount.toString(),        // num_ordinals
          portfolio.runeCount.toString(),           // num_runes
          REBALANCE_THRESHOLD_SATS.toString(),      // rebalance_threshold
          "80",                                     // max_risk
          action.actionType.toString(),             // action_type
          Number(action.amount).toString(),         // amount
          action.riskScore.toString(),              // risk_score
        ],
      });
      await provider.waitForTransaction(proofTx.transaction_hash);
      log(`→ Proof verified on-chain ✅ (tx: ${proofTx.transaction_hash.slice(0, 18)}...)`);

      // Get proof_hash (output_hash) from ProofRegistry for use in AgentVault
      const proofHashRaw = await provider.callContract({
        contractAddress: PROOF_REGISTRY_ADDRESS,
        entrypoint: "compute_output_hash",
        calldata: [
          action.actionType.toString(),
          Number(action.amount).toString(),
          action.riskScore.toString(),
        ],
      });
      const proofHash = proofHashRaw[0];
      log(`→ Proof hash: ${proofHash.slice(0, 18)}...`);

      // Get proof_id (total_proofs - 1) for linking to AgentVault
      const totalProofsRaw = await provider.callContract({
        contractAddress: PROOF_REGISTRY_ADDRESS,
        entrypoint: "get_total_proofs",
        calldata: [],
      });
      const proofId = Number(BigInt(totalProofsRaw[0])) - 1;
      log(`→ Proof ID: ${proofId}`);

      // ── Step 2: Propose action on AgentVault with proof_id + portfolio snapshot ──
      const amountLow = action.amount & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFn;
      const amountHigh = action.amount >> 128n;
      
      log(`→ Proposing ${action.label}`);
      const proposeTx = await account.execute({
        contractAddress: VAULT_ADDRESS,
        entrypoint: "propose_action",
        calldata: [
          action.actionType.toString(),
          amountLow.toString(),
          amountHigh.toString(),
          action.riskScore.toString(),
          proofId.toString(),           // proof_id for registry verification
          portfolioCommitHash,          // portfolio_snapshot_hash
        ],
      });
      await provider.waitForTransaction(proposeTx.transaction_hash);

      // Get action ID
      const stateRaw = await provider.callContract({
        contractAddress: VAULT_ADDRESS,
        entrypoint: "get_agent_state",
        calldata: [],
      });
      const actionId = Number(BigInt(stateRaw[4])) - 1;
      log(`→ Proposed action #${actionId} (tx: ${proposeTx.transaction_hash.slice(0, 18)}...)`);

      // ── Step 3: Approve action (constraint checks) ──
      log(`→ Validating constraints for action #${actionId}...`);
      const approveTx = await account.execute({
        contractAddress: VAULT_ADDRESS,
        entrypoint: "approve_action",
        calldata: [actionId.toString()],
      });
      await provider.waitForTransaction(approveTx.transaction_hash);

      // Verify
      const actionRaw = await provider.callContract({
        contractAddress: VAULT_ADDRESS,
        entrypoint: "get_action",
        calldata: [actionId.toString()],
      });
      // [action_type, amount_low, amount_high, risk_score, proof_hash, timestamp, approved]
      const approved = Number(BigInt(actionRaw[6]));
      if (approved === 1) {
        log(`→ Action #${actionId} APPROVED ✅ (ZK-verified + constraint-checked)`);
        successCount++;
      } else {
        log(`→ Action #${actionId} status: ${approved}`);
      }
      console.log("");
    } catch (e: any) {
      log(`❌ Failed: ${e.message}`);
    }
  }

  console.log("═".repeat(60));
  log(`✅ Pipeline complete: ${successCount}/${actions.length} actions approved`);
  console.log("═".repeat(60) + "\n");
}

runPipeline().catch((e) => {
  log(`💀 Fatal: ${e.message}`);
  console.error(e);
  process.exit(1);
});
