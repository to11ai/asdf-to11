#!/usr/bin/env bash

# Runs the same checks CI does, so a failure is reproducible locally:
#   asdf install && scripts/lint.bash
#
# `set -e` is load-bearing. Without it this script exits with shfmt's status
# and a shellcheck failure passes silently.
set -euo pipefail

shellcheck --shell=bash --external-sources --source-path=lib/ \
	bin/* \
	lib/* \
	scripts/*

# Directories are walked, so this covers anything added later without the
# glob needing to be kept in step.
shfmt --language-dialect bash --diff \
	bin lib scripts
