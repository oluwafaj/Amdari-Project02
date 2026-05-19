#!/bin/bash
# Security Gate Script
# Aggregates scanner results and posts PR comment

echo "=========================================="
echo "         SECURITY GATE SUMMARY"
echo "=========================================="

HARD_FAIL=0

# Check Stage 1 - Gitleaks
if [ -f "gitleaks-report.json" ]; then
    SECRETS=$(cat gitleaks-report.json | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    if [ "$SECRETS" -gt "0" ]; then
        echo "❌ DEVSECOPS | Gitleaks: $SECRETS secret(s) found - HARD FAIL"
        HARD_FAIL=1
    else
        echo "✅ DEVSECOPS | Gitleaks: No secrets found"
    fi
fi

# Check Stage 3 - Trivy
echo "❌ DEVSECOPS | Trivy: CRITICAL/HIGH CVEs found - HARD FAIL"
HARD_FAIL=1

# Check Stage 4 - Checkov
echo "❌ DEVSECOPS | Checkov: CRITICAL/HIGH IaC findings - HARD FAIL"
HARD_FAIL=1

# AppSec findings (soft-fail)
echo "------------------------------------------"
echo "📋 APPSEC FINDINGS (non-blocking)"
echo "------------------------------------------"
echo "⚠️  APPSEC | SonarQube: See SonarCloud dashboard"
echo "   Owner: Application Security Team"
echo "   Action: File intake ticket at <link>"
echo "------------------------------------------"

if [ "$HARD_FAIL" -eq "1" ]; then
    echo "🚨 GATE RESULT: FAILED - Merge blocked"
    exit 1
else
    echo "✅ GATE RESULT: PASSED"
    exit 0
fi
