#!/usr/bin/env bash
# aicorp-verify-1c.sh — depuis la racine du repo
cd "$(git rev-parse --show-toplevel)"
set -uo pipefail
ACC=$(aws sts get-caller-identity --query Account --output text)

echo "== 1. BINAIRES =="
for c in tflint gitleaks; do
  command -v $c >/dev/null && echo "$c OK  $($c --version 2>&1 | head -1)" || echo "$c ABSENT"
done

echo; echo "== 2. PRE-COMMIT (execution reelle) =="
pre-commit run --all-files 2>&1 | tail -25

echo; echo "== 3. BUDGETS + NOTIFICATIONS =="
for b in $(aws budgets describe-budgets --account-id "$ACC" --query 'Budgets[].BudgetName' --output text); do
  echo "--- $b"
  aws budgets describe-budget --account-id "$ACC" --budget-name "$b" \
    --query 'Budget.BudgetLimit' --output text
  aws budgets describe-notifications-for-budget --account-id "$ACC" --budget-name "$b" \
    --query 'Notifications[].{Type:NotificationType,Seuil:Threshold}' --output table
done

echo; echo "== 4. CREDENTIAL REPORT =="
aws iam generate-credential-report >/dev/null 2>&1; sleep 4
aws iam get-credential-report --query Content --output text | base64 -d \
  | awk -F, '{print $1" | mfa="$8" | key1_active="$9" | key1_rotated="$10}'

echo; echo "== 5. BRANCH PROTECTION =="
gh api repos/{owner}/{repo}/branches/main/protection --jq \
 '{pr:(.required_pull_request_reviews!=null),
   lineaire:.required_linear_history.enabled,
   admins_soumis:.enforce_admins.enabled,
   checks:.required_status_checks.contexts}'

echo; echo "== 6. ARBORESCENCE =="
git ls-files
test -f .gitmodules && echo "!! .gitmodules TOUJOURS PRESENT" || echo "OK: pas de submodule"

echo; echo "== 7. ADR =="
test -f docs/adr/0001-choix-terraform.md \
  && wc -l docs/adr/0001-choix-terraform.md \
  || echo "!! ADR-0001 ABSENT"

echo; echo "== 8. HISTORIQUE =="
git log --oneline -8

echo; echo "== 9. CI =="
gh run list --limit 5