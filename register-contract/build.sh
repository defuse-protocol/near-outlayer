#!/bin/bash
set -e

echo "Building register-contract..."

# We use raw `cargo build` instead of `cargo near build` because cargo-near
# overrides RUSTFLAGS with its own value ("-C link-arg=-s") and does not forward
# CFLAGS to the C compiler, making it impossible to disable bulk-memory ops.
#
# RUSTFLAGS:
#   -C link-arg=-s          Strip debug symbols (same as cargo-near's default)
#   -C target-feature=-bulk-memory  Disable bulk-memory ops (memory.fill/memory.copy)
#                                   in rustc codegen. NEAR VM does not support them.
#
# CC/AR: Use LLVM 18 instead of LLVM 21. The ring crate compiles C code via clang
#        for wasm32, and LLVM 21 has a bug where -mno-bulk-memory is accepted but
#        ignored, still emitting memory.fill instructions.
#        Install with: brew install llvm@18
#
# CFLAGS:
#   -mno-bulk-memory  Disable bulk-memory ops in clang's C codegen (ring crate).
#                     Only effective with LLVM 18; LLVM 21 ignores this flag.
RUSTFLAGS="-C link-arg=-s -C target-feature=-bulk-memory" \
CC=/opt/homebrew/opt/llvm@18/bin/clang \
AR=/opt/homebrew/opt/llvm@18/bin/llvm-ar \
CFLAGS="-mno-bulk-memory" \
cargo build --target wasm32-unknown-unknown --release

mkdir -p res

# Lower sign-extension ops (i32.extend8_s etc.) that NEAR VM does not support.
# Rust 1.86+ emits these by default. wasm-opt rewrites them into portable equivalents.
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
