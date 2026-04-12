#!/usr/bin/env bash
# AI-ML on AWS — Smoke Test: Claude Code via Anthropic API
# Run this after SSHing into the AI Dev Server.
# Requires: ANTHROPIC_API_KEY set in your environment

set -euo pipefail

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "Error: ANTHROPIC_API_KEY is not set."
  echo "Run: export ANTHROPIC_API_KEY=sk-ant-your-key-here"
  exit 1
fi

echo "Testing Claude Code via Anthropic API..."
claude -p "Say: Claude Code is live on AWS."
