# AICorp Infra

Ce dépôt contient l'infrastructure as code et la configuration de déploiement pour les environnements AICorp.

## Structure

```text
aicorp-infra/
├── .github/workflows/
├── docs/adr/
├── modules/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── .gitignore
├── .pre-commit-config.yaml
└── README.md
```

## Objectif

- centraliser la configuration de l'infrastructure par environnement ;
- séparer les modules réutilisables des environnements spécifiques ;
- documenter les décisions d'architecture dans `docs/adr/` ;
- automatiser les validations CI/CD via GitHub Actions.

## Environnements

- `dev` : environnement de développement
- `staging` : environnement de validation
- `prod` : environnement de production

## Bonnes pratiques

- Garder les secrets hors du dépôt
- Valider les fichiers Terraform, YAML et JSON avant commit
- Ajouter des ADRs pour chaque décision d'architecture importante
- Utiliser des modules réutilisables pour éviter la duplication
