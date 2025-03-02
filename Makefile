# Heavily inspired by Reth: https://github.com/paradigmxyz/reth/blob/main/Makefile

# Include .env file to get GITHUB_TOKEN
ifneq ("$(wildcard .env)","")
	include .env
endif

# The release tag of https://github.com/ethereum/tests to use for EF tests
EF_TESTS_TAG := v12.4
EF_TESTS_URL := https://github.com/ethereum/tests/archive/refs/tags/$(EF_TESTS_TAG).tar.gz
EF_TESTS_DIR := ./crates/ef-testing/ethereum-tests

# Kakarot artifacts V0
KKRT_V0_ARTIFACTS_URL = $(shell curl -sL -H "Authorization: token $(GITHUB_TOKEN)" "https://api.github.com/repos/kkrt-labs/kakarot/actions/workflows/ci.yml/runs?per_page=1&branch=main&event=push&status=success" | jq -r '.workflow_runs[0].artifacts_url')
KKRT_V0_BUILD_ARTIFACT_URL = $(shell curl -sL -H "Authorization: token $(GITHUB_TOKEN)" "$(KKRT_V0_ARTIFACTS_URL)" | jq -r '.artifacts[] | select(.name=="kakarot-build").url')/zip

# Kakarot artifacts V1
KKRT_V1_ARTIFACTS_URL = $(shell curl -sL -H "Authorization: token $(GITHUB_TOKEN)" "https://api.github.com/repos/kkrt-labs/kakarot-ssj/actions/workflows/artifacts.yml/runs?per_page=1&branch=main&event=push&status=success" | jq -r '.workflow_runs[0].artifacts_url')
KKRT_V1_BUILD_ARTIFACT_URL = $(shell curl -sL -H "Authorization: token $(GITHUB_TOKEN)" "$(KKRT_V1_ARTIFACTS_URL)" | jq -r '.artifacts[] | select(.name=="dev-artifacts").url')/zip

# Downloads and unpacks Ethereum Foundation tests in the `$(EF_TESTS_DIR)` directory.
# Requires `wget` and `tar`
$(EF_TESTS_DIR):
	mkdir -p $(EF_TESTS_DIR)
	wget $(EF_TESTS_URL) -O ethereum-tests.tar.gz
	tar -xzf ethereum-tests.tar.gz --strip-components=1 -C $(EF_TESTS_DIR)
	rm ethereum-tests.tar.gz

# Ensures the commands for $(EF_TESTS_DIR) always run on `make setup`, regardless if the directory exists
.PHONY: $(EF_TESTS_DIR) build
setup: $(EF_TESTS_DIR)

setup-kakarot-v0: clean-kakarot-v0
	@curl -sL -o kakarot-build.zip -H "Authorization: token $(GITHUB_TOKEN)" "$(KKRT_V0_BUILD_ARTIFACT_URL)"
	unzip -o kakarot-build.zip -d build/v0
	mv build/v0/fixtures/ERC20.json build/common/
	rm -f kakarot-build.zip

setup-kakarot-v1: clean-kakarot-v1
	@curl -sL -o dev-artifacts.zip -H "Authorization: token $(GITHUB_TOKEN)" "$(KKRT_V1_BUILD_ARTIFACT_URL)"
	unzip -o dev-artifacts.zip -d build/temp
	mv build/temp/contracts_ContractAccount.compiled_contract_class.json build/v1/contract_account.json
	mv build/temp/contracts_ExternallyOwnedAccount.compiled_contract_class.json build/v1/externally_owned_account.json
	mv build/temp/contracts_KakarotCore.compiled_contract_class.json build/v1/kakarot.json
	mv build/temp/contracts_UninitializedAccount.compiled_contract_class.json build/v1/uninitialized_account.json
	mv build/temp/contracts_Precompiles.compiled_contract_class.json build/common/precompiles.json
	rm -fr build/temp
	rm -f dev-artifacts.zip

setup-kakarot: clean-common setup-kakarot-v0 setup-kakarot-v1

clean-common:
	rm -rf build/common
	mkdir -p build/common

clean-kakarot-v0:
	rm -rf build/v0
	mkdir -p build/v0

clean-kakarot-v1:
	rm -rf build/v1
	mkdir -p build/v1

# Runs all tests but integration tests
unit:
	cargo test --lib

vm-tests-v0-ci: build
	cargo test --test VMTests --lib --no-fail-fast --quiet --features "v0,ci"

vm-tests-v1-ci: build
	cargo test --test VMTests --lib --no-fail-fast --quiet --features "v1,ci"

# Runs the repo tests with the `v0` feature
tests-v0-ci: build
	cargo test --test tests --lib --no-fail-fast --quiet --features "v0,ci"

# Runs the repo tests with the `v1` feature
tests-v1-ci: build
	cargo test --test tests --lib --no-fail-fast --quiet --features "v1,ci"

# Runs ef tests only with the `v0` feature
ef-test-v0: build
	cargo test --test tests --no-fail-fast --quiet --features "v0,ci"

# Runs ef tests only with the `v1` feature
ef-test-v1: build
	cargo test --test tests --no-fail-fast --quiet --features "v1,ci"

# Build the rust crates
build:
	cargo build --release

# Generates a `blockchain-tests-skip.yml` at the project root, by consuming a `data.txt` file containing logs of the ran tests
generate-skip-file:
	python ./scripts/generate_skip_file.py
