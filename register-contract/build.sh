#!/bin/bash
set -e

echo "Building register-contract..."

# We use raw `cargo build` instead of `cargo near build` because cargo-near
# hardcodes RUSTFLAGS="-C link-arg=-s" without -C target-cpu=mvp, and its
# wasm-opt step doesn't run --signext-lowering.
#
# RUSTFLAGS:
#   -C link-arg=-s     Strip debug symbols (same as cargo-near's default)
#   -C target-cpu=mvp  Emit only WebAssembly MVP instructions — no bulk-memory
#                      (memory.fill/memory.copy) or sign-extension (i32.extend8_s)
#                      ops. NEAR VM only supports the MVP spec.
#
# CC/AR: Use LLVM 18 — the ring crate compiles C code via clang for wasm32.
#        LLVM 21 has issues with -mno-bulk-memory being ignored.
#        Install with: brew install llvm@18
#
# CFLAGS:
#   -mcpu=mvp  Same as target-cpu=mvp but for clang. Restricts C codegen to
#              MVP-only instructions.
RUSTFLAGS="-C link-arg=-s -C target-cpu=mvp" \
CC=/opt/homebrew/opt/llvm@18/bin/clang \
AR=/opt/homebrew/opt/llvm@18/bin/llvm-ar \
CFLAGS="-mcpu=mvp" \
cargo build --target wasm32-unknown-unknown --release

mkdir -p res

# Lower sign-extension ops remaining from Rust's pre-compiled standard library
# (libcore, liballoc). These are baked into the toolchain's .rlib files and cannot
# be eliminated by RUSTFLAGS. --signext-lowering rewrites them into MVP equivalents.
# -O also optimizes for size (same as cargo-near's wasm-opt post-step).
wasm-opt --signext-lowering -O target/wasm32-unknown-unknown/release/register_contract.wasm -o res/register_contract.wasm

# Show file size
ls -lh res/register_contract.wasm

echo "✅ Build complete: res/register_contract.wasm"

# near contract deploy worker.outlayer.testnet use-file target/near/register_contract.wasm with-init-call new json-args '{"owner_id": "owner.outlayer.testnet", "init_worker_account": "init-worker.outlayer.testnet"}' prepaid-gas '100.0 Tgas' attached-deposit '0 NEAR' network-config testnet sign-with-keychain send
# near contract deploy worker.outlayer.testnet use-file res/register_contract.wasm without-init-call network-config testnet sign-with-keychain send
# near contract call-function as-transaction worker.outlayer.testnet migrate json-args '{"outlayer_contract_id":"outlayer.testnet"}' prepaid-gas '100.0 Tgas' attached-deposit '0 NEAR' sign-as worker.outlayer.testnet network-config testnet sign-with-keychain send

# mainnet
# near contract deploy worker.outlayer.near use-file worker-contract.wasm with-init-call new json-args '{"owner_id": "owner.outlayer.near", "init_worker_account": "init-worker.outlayer.near"}' prepaid-gas '100.0 Tgas' attached-deposit '0 NEAR' network-config mainnet sign-with-keychain send

# Add approved measurements (use scripts/deploy_phala.sh to extract all 5 measurements)
# near contract call-function as-transaction worker.outlayer.testnet add_approved_measurements json-args '{"measurements":{"mrtd":"...","rtmr0":"...","rtmr1":"...","rtmr2":"...","rtmr3":"..."}, "clear_others": true}' prepaid-gas '100.0 Tgas' attached-deposit '0 NEAR' sign-as owner.outlayer.testnet network-config testnet sign-with-legacy-keychain send
