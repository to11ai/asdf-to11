#!/usr/bin/env bash

# Shared logic for the scripts in bin/. Sourced, never executed directly.

set -euo pipefail

GH_OWNER="to11ai"
GH_REPO_NAME="to11-cli"
GH_REPO="https://github.com/${GH_OWNER}/${GH_REPO_NAME}"

# The tool, the command and the archive prefix are all `to11`. The release
# repository is called `to11-cli`, which is a distribution detail that
# deliberately does not leak into the version a user pins.
TOOL_NAME="to11"

fail() {
	echo -e "asdf-${TOOL_NAME}: $*" >&2
	exit 1
}

curl_opts=(-fsSL --retry 3 --retry-delay 1)

# Sort semver ascending, so the newest version is last. Taken from
# asdf-vm/asdf-plugin-template: `sort -V` is not portable enough to rely on.
sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# Versions come from the tags themselves rather than the releases API: no JSON
# parsing, no jq, and no rate limit. Tags in to11-cli are plain `v<semver>` —
# the monorepo's `cli-` prefix is stripped when a release is published.
list_all_versions() {
	# All three settings are needed to make an unreachable repository fail
	# rather than block. GIT_TERMINAL_PROMPT only silences the terminal
	# prompt; a configured credential helper (osxkeychain, for one) will still
	# sit there waiting, so the helper chain is cleared and askpass is pointed
	# at a command that returns nothing.
	GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true \
		git -c credential.helper= ls-remote --tags --refs "$GH_REPO" 2>/dev/null |
		grep -o 'refs/tags/.*' | cut -d/ -f3- | sed 's/^v//' ||
		fail "could not read tags from ${GH_REPO}"
}

get_arch() {
	case "$(uname -m)" in
	x86_64 | amd64) printf 'amd64' ;;
	aarch64 | arm64) printf 'arm64' ;;
	*) fail "architecture '$(uname -m)' has no published build; see ${GH_REPO}/releases" ;;
	esac
}

get_platform() {
	case "$(uname | tr '[:upper:]' '[:lower:]')" in
	darwin) printf 'darwin' ;;
	linux) printf 'linux' ;;
	*) fail "platform '$(uname)' has no published build; see ${GH_REPO}/releases" ;;
	esac
}

asset_name() {
	printf '%s_%s_%s_%s.tar.gz' "$TOOL_NAME" "$1" "$(get_platform)" "$(get_arch)"
}

download_release() {
	local version="$1" output="$2" name url
	name=$(asset_name "$version")
	url="${GH_REPO}/releases/download/v${version}/${name}"

	echo "* downloading ${TOOL_NAME} ${version} (${name})"
	curl "${curl_opts[@]}" -o "$output" "$url" ||
		fail "could not download ${url}\n  Check that ${version} is a published release: ${GH_REPO}/releases"
}
