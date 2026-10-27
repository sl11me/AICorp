# AICorp Infra

Infrastructure AWS d'AICorp en Terraform (région `eu-west-3`). Les décisions d'architecture sont dans `docs/adr/` : les lire avant de changer la structure ou le state.

## État actuel

- Seul `bootstrap/` contient du code : bucket S3 + clé KMS qui hébergent tous les states, y compris le sien (backend S3 déjà migré).
- `environments/{dev,staging,prod}/` et `modules/` ne contiennent qu'un README ; `aicorp-platform/` est vide.
- L'arborescence du `README.md` est en avance sur le code (elle décrit la cible, pas l'existant).

## Commandes

```bash
pre-commit run --all-files        # fmt, validate, tflint, gitleaks, yaml/json — même chose que la CI sur PR
cd bootstrap && terraform init && terraform plan
scripts/aicorp-evidence.sh        # inventaire outillage + identité AWS
scripts/aicorp-verify-1c.sh       # vérifie pre-commit, budgets, credential report IAM, protection de branche
```

Versions : Terraform `~> 1.14` (CI en 1.14.1), provider AWS `~> 6.0`.

## Règles

- **Jamais de `terraform apply` ni de `destroy` sans demande explicite** : c'est un vrai compte AWS. `plan` est libre.
- State (ADR-0002) : un state par environnement et par couche, `<env>/{network,platform,apps}`,
  clé `s3://aicorp-tfstate-<ACCOUNT_ID>/<env>/<layer>/terraform.tfstate`, verrou S3 natif (`use_lockfile = true`, pas de DynamoDB).
- Dépendances entre couches via `terraform_remote_state`, dans un seul sens : apps → platform → network.
- `bootstrap/` a `prevent_destroy` sur le bucket et la clé, c'est voulu : ne pas le retirer sans accord. Les pièges sont dans `bootstrap/README.md`.
- Modules (`modules/`) : aucune valeur en dur, aucun bloc `provider` ; versionnés par tag.
- Tags par défaut posés par le provider (`Project`, `Environment`, `ManagedBy`, `Owner`, `CostCenter`) : ne pas les dupliquer par ressource.
- Garde-fou budgétaire : 5 USD/mois. Signaler le coût de toute nouvelle ressource payante.
- Toute décision structurante → nouvelle ADR numérotée dans `docs/adr/` (format des existantes).
- Secrets : jamais dans le repo (`*.tfvars`, `.env`, `*.pem` ignorés ; gitleaks en pre-commit). Les `terraform.tfstate`/`tfplan` locaux de `bootstrap/` sont ignorés.
