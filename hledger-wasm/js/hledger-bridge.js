/**
 * hledger-wasm JavaScript bridge
 * Provides window.hledgerWasm API for running hledger commands in the browser
 */

import { WASI, OpenFile, File, ConsoleStdout, PreopenDirectory } from "@bjorn3/browser_wasi_shim";

let wasmInstance = null;
let wasiInstance = null;

// Configurable WASM path - can be set before calling init()
let wasmPath = "/wasm/hledger-wasm.wasm";

/**
 * Set the path to the hledger WASM file
 */
export function setWasmPath(path) {
  wasmPath = path;
}

/**
 * Initialize the hledger WASM module
 * Must be called once before using other functions
 */
export async function init() {
  if (wasmInstance) {
    return; // Already initialized
  }

  const response = await fetch(wasmPath);
  const wasmBytes = await response.arrayBuffer();
  
  // Create a minimal WASI environment
  const fds = [
    new OpenFile(new File([])), // stdin
    ConsoleStdout.lineBuffered((msg) => console.log("[hledger]", msg)),
    ConsoleStdout.lineBuffered((msg) => console.error("[hledger]", msg)),
    new PreopenDirectory("/", new Map()),
  ];

  wasiInstance = new WASI([], [], fds, { debug: false });
  
  const { instance } = await WebAssembly.instantiate(wasmBytes, {
    wasi_snapshot_preview1: wasiInstance.wasiImport,
  });

  wasmInstance = instance;
  wasiInstance.initialize(instance);
}

/**
 * Write journal content to virtual filesystem and run hledger command
 */
async function runHledger(journalContent, command, ...args) {
  if (!wasmInstance) {
    throw new Error("hledger WASM not initialized. Call init() first.");
  }

  // Capture stdout
  let stdout = "";
  let stderr = "";

  const fds = [
    new OpenFile(new File([])), // stdin
    ConsoleStdout.lineBuffered((msg) => { stdout += msg + "\n"; }),
    ConsoleStdout.lineBuffered((msg) => { stderr += msg + "\n"; }),
    new PreopenDirectory("/", new Map([
      ["journal.hledger", new File(new TextEncoder().encode(journalContent))],
    ])),
  ];

  const wasi = new WASI(
    ["hledger-wasm", command, "/journal.hledger", ...args],
    [],
    fds,
    { debug: false }
  );

  const response = await fetch(wasmPath);
  const wasmBytes = await response.arrayBuffer();
  
  const { instance } = await WebAssembly.instantiate(wasmBytes, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });

  wasi.initialize(instance);
  
  try {
    instance.exports._start();
  } catch (e) {
    if (e.message !== "exit with exit code 0" && !e.message.includes("unreachable")) {
      console.error("hledger error:", e);
    }
  }

  if (stderr.trim()) {
    console.warn("hledger stderr:", stderr);
  }

  return stdout.trim();
}

/**
 * Get account names from journal
 * @param {string} journal - Journal content as string
 * @returns {Promise<string[]>} - Array of account names
 */
export async function accounts(journal) {
  const result = await runHledger(journal, "accounts");
  if (!result) return [];
  return JSON.parse(result);
}

/**
 * Get transactions (print command)
 * @param {string} journal - Journal content as string
 * @returns {Promise<object[]>} - Array of transaction objects
 */
export async function print(journal) {
  const result = await runHledger(journal, "print");
  if (!result) return [];
  return JSON.parse(result);
}

/**
 * Get account balances
 * @param {string} journal - Journal content as string
 * @returns {Promise<Array<[string, object[]]>>} - Array of [accountName, amounts] tuples
 */
export async function balance(journal) {
  const result = await runHledger(journal, "balance");
  if (!result) return [];
  return JSON.parse(result);
}

/**
 * Get account register (transactions for a specific account)
 * @param {string} journal - Journal content as string
 * @param {string} account - Account name or prefix
 * @returns {Promise<object[]>} - Array of transaction objects
 */
export async function aregister(journal, account) {
  const result = await runHledger(journal, "aregister", account);
  if (!result) return [];
  return JSON.parse(result);
}

/**
 * Get commodities used in journal
 * @param {string} journal - Journal content as string
 * @returns {Promise<string[]>} - Array of commodity names
 */
export async function commodities(journal) {
  const result = await runHledger(journal, "commodities");
  if (!result) return [];
  return JSON.parse(result);
}

// Expose on window for Rust wasm_bindgen interop
if (typeof window !== "undefined") {
  window.hledgerWasm = {
    init,
    setWasmPath,
    accounts,
    print,
    balance,
    aregister,
    commodities,
  };
}

export default {
  init,
  setWasmPath,
  accounts,
  print,
  balance,
  aregister,
  commodities,
};
