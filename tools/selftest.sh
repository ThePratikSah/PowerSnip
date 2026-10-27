#!/bin/zsh
# Runs the in-app self-test against a fresh store in /tmp. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/com.pratik.aipowersnip.savedState
store=/tmp/AiPowerSnip-self-store
rm -rf "$store"
mkdir -p "$store"
APP_STORE=$store ~/Applications/AiPowerSnip.app/Contents/MacOS/AiPowerSnip --selftest
