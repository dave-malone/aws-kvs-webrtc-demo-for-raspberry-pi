#!/bin/bash
#
# setup-aws-sso.sh
#
# Configures an AWS SSO profile for use with the KVS WebRTC provisioning scripts.
# This only needs to be run once. After that, use `aws sso login --profile <name>`
# to refresh your session.
#
# Usage:
#   ./setup-aws-sso.sh [PROFILE_NAME]
#
# Example:
#   ./setup-aws-sso.sh work
#

set -euo pipefail

# ─── Prerequisites check ─────────────────────────────────────────────────────

if ! command -v aws &>/dev/null; then
  echo "Error: AWS CLI is not installed."
  echo "Install it from: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

AWS_CLI_MAJOR=$(aws --version 2>&1 | grep -oE 'aws-cli/[0-9]+' | cut -d/ -f2)
if [[ "${AWS_CLI_MAJOR}" -lt 2 ]]; then
  echo "Error: AWS CLI v2 is required for SSO support (found v${AWS_CLI_MAJOR})."
  echo "Install it from: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

PROFILE_NAME="${1:-}"

if [[ -z "$PROFILE_NAME" ]]; then
  read -p "Enter a name for your AWS CLI profile (e.g. work, personal): " PROFILE_NAME
  if [[ -z "$PROFILE_NAME" ]]; then
    echo "Error: Profile name cannot be empty."
    exit 1
  fi
fi

echo "=== AWS SSO Profile Setup ==="
echo ""
echo "This will walk you through configuring an AWS SSO profile named '${PROFILE_NAME}'."
echo "You will need your IAM Identity Center start URL, account ID, and role name."
echo ""

# Check if profile already exists
if aws configure get sso_start_url --profile "${PROFILE_NAME}" &>/dev/null; then
  echo "Profile '${PROFILE_NAME}' already exists in ~/.aws/config."
  echo ""
  read -p "Overwrite it? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Keeping existing profile. Run 'aws sso login --profile ${PROFILE_NAME}' to log in."
    exit 0
  fi
fi

# aws configure sso walks through the full setup interactively
aws configure sso --profile "${PROFILE_NAME}"

echo ""
echo "=== SSO profile '${PROFILE_NAME}' configured ==="
echo ""
echo "To log in:  aws sso login --profile ${PROFILE_NAME}"
echo "To verify:  aws sts get-caller-identity --profile ${PROFILE_NAME}"
echo ""
echo "Then run the provisioning script:"
echo "  ./provision-local.sh --profile ${PROFILE_NAME} --pi-host <user>@<pi-ip> --thing-name <name>"
