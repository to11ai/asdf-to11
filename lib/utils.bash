#!/usr/bin/env bash

# Shared logic for the scripts in bin/. Sourced, never executed directly.

set -euo pipefail

GH_OWNER="to11ai"
GH_REPO_NAME="to11-cli"
GH_REPO="https://github.com/${GH_OWNER}/${GH_REPO_NAME}"
GH_API="https://api.github.com/repos/${GH_OWNER}/${GH_REPO_NAME}"

# The tool, the command and the archive prefix are all `to11`. The release
# repository is called `to11-cli`, which is a distribution detail that
# deliberately does not leak into the version a user pins.
TOOL_NAME="to11"

fail() {
	echo -e "asdf-${TOOL_NAME}: $*" >&2
	exit 1
}

curl_opts=(-fsSL --retry 3 --retry-delay 1)

# Once to11-cli is public a token is optional, and only raises the GitHub API
# rate limit from 60 to 5000 requests an hour. While the repository is private
# it is required. Both token paths below are marked PRIVATE-ONLY and can be
# deleted when the repository opens.
gh_token() {
	printf '%s' "${GITHUB_API_TOKEN:-${GITHUB_TOKEN:-}}"
}

# Sort semver ascending, so the newest version is last. Taken from
# asdf-vm/asdf-plugin-template: `sort -V` is not portable enough to rely on.
sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# Versions come from the tags themselves on the public path: no JSON parsing,
# no dependency on jq, and no API rate limit. GIT_TERMINAL_PROMPT=0 matters —
# without it, git asks for credentials on stdin when it cannot read the repo,
# which hangs the install rather than failing it.
list_all_versions() {
	local token
	token=$(gh_token)

	if [ -z "$token" ]; then
		# All three are needed to make an unreadable repo fail instead of
		# block. GIT_TERMINAL_PROMPT only silences the terminal prompt; a
		# configured credential helper (osxkeychain, for one) will still sit
		# there waiting, so the helper chain is cleared and askpass is pointed
		# at a command that returns nothing.
		GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true \
			git -c credential.helper= ls-remote --tags --refs "$GH_REPO" 2>/dev/null |
			grep -o 'refs/tags/.*' | cut -d/ -f3- | sed 's/^v//' ||
			fail "could not read tags from ${GH_REPO}. If it is private, set GITHUB_API_TOKEN."
		return
	fi

	# PRIVATE-ONLY. Deliberately not git-over-HTTPS: that needs Basic
	# credentials rather than a Bearer header, and a wrong guess prompts on
	# stdin instead of failing. The API is unambiguous. Only the first 100
	# releases are listed, which is ample and disappears with this branch once
	# the repository is public.
	command -v jq >/dev/null ||
		fail "jq is required while ${GH_REPO_NAME} is private; install jq, or unset GITHUB_API_TOKEN once it is public"

	curl "${curl_opts[@]}" -H "Authorization: Bearer ${token}" \
		-H "Accept: application/vnd.github+json" \
		"${GH_API}/releases?per_page=100" |
		jq -r '.[] | select(.draft == false) | .tag_name' | sed 's/^v//' ||
		fail "could not list releases for ${GH_REPO_NAME}"
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
	local version="$1" output="$2" name token url id
	name=$(asset_name "$version")
	token=$(gh_token)

	if [ -z "$token" ]; then
		url="${GH_REPO}/releases/download/v${version}/${name}"
		echo "* downloading ${TOOL_NAME} ${version} (${name})"
		curl "${curl_opts[@]}" -o "$output" "$url" ||
			fail "could not download ${url}\n  A private repository answers 404 here. If ${GH_REPO_NAME} is not public yet, set GITHUB_API_TOKEN."
		return
	fi

	# PRIVATE-ONLY. The plain download URL redirects to object storage, and
	# curl forwards the Authorization header to the redirect target, which
	# rejects it. Reading an asset from a private repository therefore has to
	# go through the API asset endpoint, which needs the asset's id first.
	command -v jq >/dev/null ||
		fail "jq is required while ${GH_REPO_NAME} is private; install jq, or unset GITHUB_API_TOKEN once it is public"

	id=$(curl "${curl_opts[@]}" -H "Authorization: Bearer ${token}" \
		-H "Accept: application/vnd.github+json" \
		"${GH_API}/releases/tags/v${version}" |
		jq -r --arg name "$name" '.assets[] | select(.name == $name) | .id') ||
		fail "could not read release v${version}"

	[ -n "$id" ] || fail "release v${version} has no asset named ${name}"

	echo "* downloading ${TOOL_NAME} ${version} (${name}, private)"
	curl "${curl_opts[@]}" -H "Authorization: Bearer ${token}" \
		-H "Accept: application/octet-stream" \
		-o "$output" "${GH_API}/releases/assets/${id}" ||
		fail "could not download asset ${id} (${name})"
}
