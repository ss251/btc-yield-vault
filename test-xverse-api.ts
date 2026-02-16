#!/usr/bin/env npx tsx
/**
 * Test script: Validates all Xverse API endpoints with real data.
 * Run: npx tsx test-xverse-api.ts
 */

const BASE_URL = "https://api.secretkeylabs.io";
const API_KEY = "REDACTED_API_KEY";
const TEST_ADDRESS = "bc1q0egjvlcfq77cxd9kvpgppyuxckzvws46e3sxch";

// A known whale address with ordinals/runes for richer testing
const WHALE_ADDRESS = "bc1p5d7rjq7g6rdk2yhzks9smlaqtedr4dekq08ge8ztwac72sfr9rusxg3297";

async function xverseGet(path: string): Promise<any> {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: { "x-api-key": API_KEY, Accept: "application/json" },
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`${res.status}: ${text}`);
  return JSON.parse(text);
}

async function xversePost(path: string, body: any): Promise<any> {
  const res = await fetch(`${BASE_URL}${path}`, {
    method: "POST",
    headers: {
      "x-api-key": API_KEY,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
}

async function test(name: string, fn: () => Promise<any>) {
  try {
    const result = await fn();
    console.log(`✅ ${name}`);
    console.log(JSON.stringify(result, null, 2).slice(0, 500));
    console.log();
    return true;
  } catch (err: any) {
    console.log(`❌ ${name}: ${err.message}`);
    console.log();
    return false;
  }
}

async function main() {
  console.log("=== Xverse API Integration Tests ===\n");
  console.log(`Test address: ${TEST_ADDRESS}\n`);

  let passed = 0;
  let total = 0;

  // 1. BTC Balance
  total++;
  if (await test("Get BTC Balance", () =>
    xverseGet(`/v1/bitcoin/address/${TEST_ADDRESS}/balance`)
  )) passed++;

  // 2. UTXOs
  total++;
  if (await test("Get UTXOs", () =>
    xverseGet(`/v1/bitcoin/address/${TEST_ADDRESS}/utxo?offset=0&limit=25`)
  )) passed++;

  // 3. Ordinals Inscriptions
  total++;
  if (await test("Get Ordinals Inscriptions", () =>
    xverseGet(`/v1/ordinals/address/${TEST_ADDRESS}/inscriptions`)
  )) passed++;

  // 4. Runes Balances
  total++;
  if (await test("Get Runes Balances", () =>
    xverseGet(`/v1/ordinals/address/${TEST_ADDRESS}/runes`)
  )) passed++;

  // 5. Register Portfolio
  total++;
  if (await test("Register Portfolio Address", () =>
    xversePost("/v1/portfolio/register", {
      assetType: "bitcoin",
      addresses: [TEST_ADDRESS],
    })
  )) passed++;

  // 6. Whale address tests (more likely to have ordinals/runes)
  total++;
  if (await test("Whale - BTC Balance", () =>
    xverseGet(`/v1/bitcoin/address/${WHALE_ADDRESS}/balance`)
  )) passed++;

  total++;
  if (await test("Whale - Ordinals", () =>
    xverseGet(`/v1/ordinals/address/${WHALE_ADDRESS}/inscriptions`)
  )) passed++;

  total++;
  if (await test("Whale - Runes", () =>
    xverseGet(`/v1/ordinals/address/${WHALE_ADDRESS}/runes`)
  )) passed++;

  console.log(`\n=== Results: ${passed}/${total} passed ===`);
}

main().catch(console.error);
