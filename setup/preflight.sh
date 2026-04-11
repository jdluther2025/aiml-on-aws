#!/usr/bin/env bash
# AWS with Claude — Pre-flight Checklist
# Run this before starting any blog in the series.
# Usage: bash setup/preflight.sh --profile your-profile-name --region us-east-1

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
PROFILE="${AWS_PROFILE:-}"
REGION="us-east-1"

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --region)  REGION="$2";  shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Helpers ────────────────────────────────────────────────────────────────────
PASS="✅"
FAIL="❌"
WARN="⚠️ "
ERRORS=0

ok()   { echo "  $PASS  $1"; }
fail() { echo "  $FAIL  $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "  $WARN  $1"; }
header() { echo ""; echo "$1"; echo "$(printf '─%.0s' {1..50})"; }

# ── Start ──────────────────────────────────────────────────────────────────────
echo ""
echo "AI-ML on AWS — Pre-flight Checklist"
echo "======================================="

# ── 1. AWS CLI ─────────────────────────────────────────────────────────────────
header "1. Tools"

if command -v aws &>/dev/null; then
  AWS_VER=$(aws --version 2>&1 | awk '{print $1}')
  ok "AWS CLI installed ($AWS_VER)"
else
  fail "AWS CLI not installed — https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
fi

if command -v node &>/dev/null; then
  NODE_VER=$(node --version)
  if [[ "$NODE_VER" == v20* ]]; then
    ok "Node.js installed ($NODE_VER)"
  else
    warn "Node.js installed ($NODE_VER) — CDK officially supports v20.x (may see warnings)"
  fi
else
  fail "Node.js not installed — https://nodejs.org"
fi

if command -v cdk &>/dev/null; then
  CDK_VER=$(cdk --version 2>/dev/null | awk '{print $1}')
  ok "CDK installed ($CDK_VER)"
else
  fail "CDK not installed — run: npm install -g aws-cdk"
fi

if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version)
  ok "Python installed ($PY_VER)"
else
  fail "Python 3 not installed"
fi

# ── 2. AWS Profile ─────────────────────────────────────────────────────────────
header "2. AWS Account"

if [[ -z "$PROFILE" ]]; then
  fail "No AWS profile set — pass --profile your-profile-name or set AWS_PROFILE"
else
  PROFILE_FLAG="--profile $PROFILE"
  IDENTITY=$(aws sts get-caller-identity $PROFILE_FLAG --region "$REGION" 2>&1) || true
  if echo "$IDENTITY" | grep -q "Account"; then
    ACCOUNT=$(echo "$IDENTITY" | python3 -c "import sys,json; print(json.load(sys.stdin)['Account'])")
    ARN=$(echo "$IDENTITY" | python3 -c "import sys,json; print(json.load(sys.stdin)['Arn'])")
    ok "AWS profile active (profile: $PROFILE → account: $ACCOUNT)"
    ok "Identity: $ARN"
    ok "Region: $REGION"
  else
    fail "AWS credentials invalid for profile '$PROFILE' — check your keys in ~/.aws/credentials"
    echo "       Run 'aws configure list-profiles' to see available profiles"
    echo "       Docs: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html"
  fi
fi

# ── 3. VPC ─────────────────────────────────────────────────────────────────────
header "3. VPC & Subnets"

if [[ -n "$PROFILE" ]] && [[ -n "${ACCOUNT:-}" ]]; then
  VPC=$(aws ec2 describe-vpcs $PROFILE_FLAG --region "$REGION" \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "None")

  if [[ "$VPC" != "None" ]] && [[ -n "$VPC" ]]; then
    ok "Default VPC found ($VPC)"

    SUBNET_COUNT=$(aws ec2 describe-subnets $PROFILE_FLAG --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC" "Name=mapPublicIpOnLaunch,Values=true" \
      --query "length(Subnets)" --output text 2>/dev/null || echo "0")

    if [[ "$SUBNET_COUNT" -gt 0 ]]; then
      ok "Public subnets available ($SUBNET_COUNT subnets)"
    else
      fail "No public subnets found in default VPC — check your VPC configuration"
      echo "       Docs: https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html"
    fi
  else
    fail "No default VPC found in $REGION — restore it with:"
    echo "       aws ec2 create-default-vpc --region $REGION"
    echo "       Docs: https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html"
  fi
else
  warn "Skipping VPC check — profile or account not resolved"
fi

# ── 4. Key Pair ────────────────────────────────────────────────────────────────
header "4. EC2 Key Pair"

if [[ -n "$PROFILE" ]] && [[ -n "${ACCOUNT:-}" ]]; then
  KEY_PAIRS=$(aws ec2 describe-key-pairs $PROFILE_FLAG --region "$REGION" \
    --query "KeyPairs[].KeyName" --output text 2>/dev/null || echo "")

  if [[ -n "$KEY_PAIRS" ]]; then
    ok "Key pair(s) found: $KEY_PAIRS"
  else
    fail "No EC2 key pairs found in $REGION — create one:"
    echo "       aws ec2 create-key-pair --key-name my-key --query KeyMaterial --output text > ~/.ssh/my-key.pem"
    echo "       chmod 400 ~/.ssh/my-key.pem"
    echo "       Docs: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html"
  fi
else
  warn "Skipping key pair check — profile or account not resolved"
fi

# ── 5. CDK Bootstrap ───────────────────────────────────────────────────────────
header "5. CDK Bootstrap"

if [[ -n "$PROFILE" ]] && [[ -n "${ACCOUNT:-}" ]]; then
  BOOTSTRAP=$(aws cloudformation describe-stacks $PROFILE_FLAG --region "$REGION" \
    --stack-name CDKToolkit \
    --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "NOT_FOUND")

  if [[ "$BOOTSTRAP" == "CREATE_COMPLETE" ]] || [[ "$BOOTSTRAP" == "UPDATE_COMPLETE" ]]; then
    ok "CDK bootstrapped (CDKToolkit: $BOOTSTRAP)"
  else
    fail "CDK not bootstrapped — run:"
    echo "       cdk bootstrap aws://$ACCOUNT/$REGION --profile $PROFILE"
    echo "       Docs: https://docs.aws.amazon.com/cdk/v2/guide/bootstrapping.html"
  fi
else
  warn "Skipping CDK bootstrap check — profile or account not resolved"
fi

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "======================================="
if [[ $ERRORS -eq 0 ]]; then
  echo "  $PASS  All checks passed."
else
  echo "  $FAIL  $ERRORS check(s) failed. Fix the items above and re-run."
fi
echo ""
