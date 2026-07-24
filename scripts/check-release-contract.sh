#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

workflow=".github/workflows/release-cli.yml"

require_text() {
  local text="$1"
  if ! grep -Fq -- "$text" "$workflow"; then
    printf 'release contract missing: %s\n' "$text" >&2
    exit 1
  fi
}

manifest_version="$(
  sed -n 's/^version = "\([^"]*\)"/\1/p' Cargo.toml |
    head -n 1
)"
lock_version="$(
  awk '
    $0 == "name = \"logos-scaffold\"" {
      getline
      gsub(/^version = "|"$|"/, "")
      print
      exit
    }
  ' Cargo.lock
)"

if [[ -z "$manifest_version" || "$manifest_version" != "$lock_version" ]]; then
  printf 'Cargo version mismatch: manifest=%s lock=%s\n' \
    "$manifest_version" "$lock_version" >&2
  exit 1
fi

if [[ ! "$manifest_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-alpha\.[0-9]+$ ]]; then
  printf 'release version must be an alpha prerelease: %s\n' \
    "$manifest_version" >&2
  exit 1
fi

if ! grep -Fq "## [$manifest_version]" CHANGELOG.md; then
  printf 'CHANGELOG.md missing version %s\n' "$manifest_version" >&2
  exit 1
fi

if ! grep -Fq 'repository = "https://github.com/3esmit/scaffold"' Cargo.toml; then
  printf 'Cargo repository must identify the release-owning fork\n' >&2
  exit 1
fi

require_text "runs_on: ubuntu-24.04"
require_text "pull_request:"
require_text "if: github.event_name == 'workflow_dispatch'"
require_text "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"
require_text "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
require_text "actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c"
require_text "host_arch: x86_64"
require_text "target: x86_64-unknown-linux-gnu"
require_text "platform: linux-amd64"
require_text "runs_on: macos-15"
require_text "host_arch: arm64"
require_text "target: aarch64-apple-darwin"
require_text "platform: darwin-arm64"
require_text "for binary in logos-scaffold lgs"
require_text "install -m 0644 README.md LICENSE-APACHE LICENSE-MIT"
require_text "Releases must be dispatched from master."
require_text "sha256sum -- *.tar.gz > SHA256SUMS"
require_text "gh release create"
require_text "gh release download"
require_text "--draft"
require_text "--draft=false"
require_text "--prerelease"
require_text "--target \"\$GITHUB_SHA\""
require_text "git ls-remote --exit-code --tags origin"

printf 'release contract OK for logos-scaffold %s\n' "$manifest_version"
