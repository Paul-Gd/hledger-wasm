# hledger-wasm

hledger compiled to WebAssembly for running in the browser.

## Quick Start (Pre-built)

The `dist/` directory contains a pre-built WASM binary. To use it:

1. Copy `dist/hledger-wasm.wasm` and `js/hledger-bridge.js` to your project
2. Install the WASI shim: `npm install @bjorn3/browser_wasi_shim`
3. Import and use:

```javascript
import { init, accounts, balance, print, aregister, commodities } from './hledger-bridge.js';

await init();

const journal = `
2024-01-01 Opening
    assets:bank  1000 USD
    equity:opening
`;

const accountList = await accounts(journal);
const balances = await balance(journal);
```

## API

All functions take journal content as a string and return Promises.

- `init()` - Initialize the WASM module (call once)
- `accounts(journal)` - Get account names as `string[]`
- `print(journal)` - Get transactions as objects
- `balance(journal)` - Get balances as `[accountName, amounts][]`
- `aregister(journal, account)` - Get transactions for an account
- `commodities(journal)` - Get commodity names as `string[]`

## window.hledgerWasm

For Rust wasm-bindgen interop, the bridge automatically exposes these functions on `window.hledgerWasm`.

## Building from Source

### Prerequisites

Install ghc-wasm-meta:

```bash
curl https://gitlab.haskell.org/ghc/ghc-wasm-meta/-/raw/master/bootstrap.sh | PREFIX=/tmp/ghc-wasm sh
source /tmp/ghc-wasm/env
```

### Build

```bash
./build.sh
```

This builds the WASM binary to `dist/hledger-wasm.wasm`.

## Project Structure

```
hledger-wasm/
├── bridge/              # Haskell CLI wrapper for hledger-lib
│   ├── Main.hs
│   └── hledger-wasm-bridge.cabal
├── hledger-lib/         # hledger-lib source (modified for WASM)
├── terminal-size-stub/  # Stub for terminal-size (not available in WASM)
├── js/
│   └── hledger-bridge.js  # JavaScript API
├── dist/
│   └── hledger-wasm.wasm  # Pre-built WASM binary
├── cabal.project
├── build.sh
└── package.json
```

## Integration with Muhasib

For use with muhasib-e-hledger:

1. Copy `dist/hledger-wasm.wasm` to `public/wasm/`
2. Copy `js/hledger-bridge.js` to `public/wasm/`
3. In your HTML, add:
   ```html
   <script type="module" src="/wasm/hledger-bridge.js"></script>
   ```

See the muhasib-e-hledger documentation for details.

## License

GPL-3.0-or-later (same as hledger)
