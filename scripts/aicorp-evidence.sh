#!/usr/bin/env bash
# aicorp-evidence.sh — à lancer depuis la racine de aicorp-infra
set -uo pipefail

echo "===== OUTILLAGE ====="
for c in terraform aws docker kubectl helm k3d gh pre-commit tflint gitleaks; do
  if command -v "$c" >/dev/null 2>&1; then
    v=$( { "$c" version 2>/dev/null || "$c" --version 2>/dev/null; } | head -1 )
    printf "%-12s OK   %s\n" "$c" "$v"
  else
    printf "%-12s ABSENT\n" "$c"
  fi
done

echo; echo "===== IDENTITE AWS ====="
aws sts get-caller-identity --output json

echo; echo "===== MFA ROOT + USERS ====="
aws iam get-account-summary --query \
 'SummaryMap.{RootMFA:AccountMFAEnabled,Users:Users,MFADevices:MFADevices}' --output table

echo; echo "===== BUDGETS ====="
ACC=$(aws sts get-caller-identity --query Account --output text)
aws budgets describe-budgets --account-id "$ACC" --query \
 'Budgets[].{Nom:BudgetName,Limite:BudgetLimit.Amount,Devise:BudgetLimit.Unit,Type:BudgetType}' \
 --output table

echo; echo "===== ARBORESCENCE GIT ====="
git ls-files | head -40

echo; echo "===== BRANCH PROTECTION main ====="
gh api "repos/{owner}/{repo}/branches/main/protection" --jq \
 '{pr_requise: (.required_pull_request_reviews != null),
   historique_lineaire: .required_linear_history.enabled,
   force_push_autorise: .allow_force_pushes.enabled,
   checks: .required_status_checks.contexts}' 2>/dev/null \
 || echo "PAS DE PROTECTION -> critère 5 non rempli"

echo; echo "===== PRE-COMMIT ====="
pre-commit run --all-files 2>&1 | tail -20

echo; echo "===== HISTORIQUE (le commit est-il passé par une PR ?) ====="
git log --oneline --graph -10
