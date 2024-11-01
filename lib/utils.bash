#!/usr/bin/env bash

set -eo pipefail

GITHUB_REPO="WebAssembly/binaryen"
REPO_URL="https://github.com/$GITHUB_REPO"

curl_opts=(-fsSL)
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

# stolen from https://github.com/rbenv/ruby-build/pull/631/files#diff-fdcfb8a18714b33b07529b7d02b54f1dR942
function sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

function list_github_releases() {
  curl "${curl_opts[@]}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$GITHUB_REPO/releases?per_page=100" |
    grep -o '"tag_name": "version_.*"' |
    sed -E 's/"tag_name": "(version_.*)"/\1/'
}

function get_platform() {
  case "$OSTYPE" in
    darwin*) echo -n "darwin" ;;
    linux*) echo -n "linux" ;;
    *) fail "Unsupported platform" ;;
  esac
}

function get_arch() {
  case "$(uname -m)" in
    x86_64) echo -n "x86_64" ;;
    arm64) echo -n "arm64";;
    aarch64) echo -n "aarch64" ;;
    *) fail "Unsupported architecture" ;;
  esac
}

function get_bin_target() {
  local version=$1

  local platform
  platform=$(get_platform)

  local arch
  arch=$(get_arch)

  local target="$arch-$platform"

  echo -n "binaryen-$version-$target"
}

function get_bin_url() {
  local version=$1

  local target
  target=$(get_bin_target $version)

  echo -n "$REPO_URL/releases/download/$version/$target.tar.gz"
}

function get_source_url() {
  local version=$1

  echo -n "$REPO_URL/archive/$version.zip"
}

function get_temp_dir() {
  local base
  base="${TMPDIR:-/tmp}"
  base="${base%/}"

  local tmpdir
  tmpdir=$(mktemp -d "$base/asdf-binaryen.XXXX")

  echo -n "$tmpdir"
}

function fail() {
  echo -e "\e[31mFail:\e[m $*" 1>&2
  exit 1
}
