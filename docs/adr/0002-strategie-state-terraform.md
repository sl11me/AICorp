# ADR-0002 — Stratégie de gestion du state Terraform

- Statut : Accepté
- Date : 2026-09-01
- Décideurs : Platform Engineering
- Lié à : ADR-0001 (choix de Terraform)

## Contexte et problématique

Le state Terraform est le fichier qui relie le code HCL aux ressources
réellement provisionnées. Il est à la fois indispensable et sensible :
il contient en clair les valeurs générées ou lues par les providers,
mots de passe de bases de données inclus.

AICorp a désormais deux contributeurs de fait : l'ingénieur plateforme
depuis son poste, et le runner GitHub Actions qui exécutera `plan` sur
chaque pull request. Un state local sur une machine est donc déjà
disqualifié, indépendamment de la taille de l'équipe.

Les décisions prises ici sont difficilement réversibles une fois des
ressources sous gestion : elles doivent être arrêtées avant la première
ligne de HCL.

## Décisions

### 1. Découpage : un state par environnement et par couche

    <env>/network/    VPC, subnets, security groups, endpoints
    <env>/platform/   EKS, addons, IAM de service
    <env>/apps/       charges applicatives

Trois environnements (dev, staging, prod) × trois couches = neuf states,
plus celui du bootstrap.

Motifs : le rayon d'impact d'une erreur est borné physiquement (un
`destroy` sur `apps` ne peut pas atteindre le VPC, qui n'est pas dans ce
state) ; et la durée du `refresh` reste faible, ce qui conditionne le
temps de retour d'un `plan` en pull request — donc l'expérience des
équipes produit.

Les dépendances inter-couches passent par `terraform_remote_state`, en
lecture seule et dans un seul sens : apps → platform → network. Toute
dépendance inverse est interdite.

### 2. Verrouillage : S3 natif, sans DynamoDB

`use_lockfile = true` (Terraform ≥ 1.10). Terraform dépose un objet
`.tflock` à côté du state ; les écritures conditionnelles S3 garantissent
qu'un seul processus l'obtient.

Motif : une ressource de moins à provisionner, sécuriser et facturer,
pour une garantie équivalente à DynamoDB.

Limite acceptée : certains outils tiers anciens (Terragrunt, Atlantis)
présupposent encore une table DynamoDB. Le retour en arrière représente
quelques lignes de configuration.

### 3. Nommage des clés

    s3://aicorp-tfstate-<ACCOUNT_ID>/<env>/<layer>/terraform.tfstate

Le suffixe `<ACCOUNT_ID>` répond à l'unicité mondiale des noms de bucket S3.

Le point déterminant n'est pas la lisibilité mais le fait que ce chemin
sert de support aux permissions IAM. L'isolation entre environnements
s'exprime alors directement :

    "Resource": "arn:aws:s3:::aicorp-tfstate-<ID>/dev/*"

Une convention prévisible produit une isolation gratuite ; une convention
arbitraire impose des policies au cas par cas, non maintenables.

### 4. Chiffrement : SSE-KMS avec clé gérée par AICorp

Motifs : deux barrières indépendantes à franchir pour lire le state — la
bucket policy et la key policy — potentiellement détenues par deux équipes
distinctes ; et une trace CloudTrail par opération de déchiffrement,
exigence d'audit en environnement bancaire.

Coût accepté : environ 1 USD par mois pour la clé, plus les requêtes API.
Arbitrage assumé face à SSE-S3, gratuit mais sans policy propre ni
traçabilité fine.

Pour que la clé constitue une barrière réellement indépendante d'IAM, sa
key policy est explicite plutôt que laissée au comportement par défaut
d'AWS (délégation complète à IAM via le compte root) : un accès root
restreint à `GetKeyPolicy`/`PutKeyPolicy` sert uniquement de recours en cas
de mauvaise configuration, sans jamais accorder `kms:*` à l'ensemble du
compte. Les actions d'administration de la clé et son usage
(`Decrypt`/`Encrypt`/`GenerateDataKey`) sont accordés nommément à
l'opérateur courant, avec une liste extensible (`additional_key_user_arns`)
pour le jour où un rôle OIDC GitHub Actions ou un second opérateur doit lire
le state.

### 5. Amorçage : migration du state du bootstrap dans son propre bucket

Le bucket de state est lui-même une ressource Terraform. Séquence retenue :

    terraform init                  # backend local
    terraform apply                 # bucket + clé KMS créés
    # ajout du bloc backend "s3"
    terraform init -migrate-state   # le state rejoint le bucket qu'il a créé

Le bootstrap héberge donc son propre state. Alternatives écartées : la
création manuelle (ressource hors IaC, non reproductible) et le state local
committé (fichier binaire en conflit de merge, contenu sensible en clair
dans l'historique git).

## Conséquences

### Positives
- Un seul opérateur ou pipeline ne peut plus verrouiller ou corrompre le
  state d'un autre : le découpage par environnement et par couche borne le
  rayon d'impact d'une erreur humaine ou d'un bug de pipeline.
- Aucune ressource AWS supplémentaire à faire vivre pour le verrouillage
  (pas de table DynamoDB), donc rien de plus à sécuriser, monitorer ou
  facturer pour cette seule fonction.
- La clé KMS dédiée avec key policy explicite fait du chiffrement une
  barrière réellement indépendante d'IAM, pas une simple case cochée.
- Coût total mesuré et documenté (~1,05 USD/mois, README du bootstrap) :
  aucune surprise face au garde-fou budgétaire de 5 USD.

### Négatives
- Neuf states plus le bootstrap à faire vivre dès le départ, avant même la
  première charge applicative réelle — complexité opérationnelle payée
  d'avance, pas amortie progressivement.
- Le bootstrap est en dépendance circulaire assumée avec sa propre
  infrastructure (son state vit dans le bucket qu'il a créé) : la reprise
  après perte du bucket exige une procédure manuelle documentée, pas un
  simple `terraform apply`.
- `use_lockfile` retire une compatibilité implicite avec certains outils
  tiers (Terragrunt, Atlantis anciens) qui présupposent DynamoDB.
- La liste `additional_key_user_arns` doit être tenue à jour manuellement à
  chaque nouveau principal (rôle CI, second opérateur) : oubli possible,
  contrairement à une délégation IAM large qui aurait inclus ce cas par
  défaut — c'est le prix explicite de la barrière indépendante.

## Points ouverts
- Faut-il un `object_lock_configuration` (WORM) sur le bucket de state pour
  se prémunir d'une suppression malveillante par un principal qui aurait
  quand même obtenu les droits nécessaires ? Non retenu pour l'instant,
  faute de second contributeur humain avec des droits larges.
- Quand ajouter effectivement une entrée à `additional_key_user_arns` pour
  un rôle OIDC GitHub Actions : dès le premier `terraform plan` automatisé
  en CI, ou seulement lorsqu'un `apply` automatisé sera aussi envisagé ?
- Le nommage `<env>/<layer>/terraform.tfstate` suppose que `env` et `layer`
  ne changent jamais de nom une fois des états créés (le chemin S3 fait
  partie de la clé primaire du state) : documenter la procédure de
  renommage avant d'en avoir besoin, pas après.
