# ADR-0001 — Terraform comme outil d'Infrastructure as Code

- Statut : Accepté
- Date : 2026-08-31
- Décideurs : Moi-même (Platform/DevOps)
- Contexte technique : AICorp, migration cloud AWS puis Azure

## Contexte et problématique
AICorp opère aujourd'hui sur AWS, avec une extension vers Azure envisagée à
moyen terme dans une démarche exploratoire — il n'existe pas aujourd'hui de
contrainte réglementaire ou contractuelle imposant le multi-cloud, mais la
trajectoire est assumée comme objectif de montée en compétence et de
réduction du risque de concentration fournisseur.

L'équipe Platform est aujourd'hui réduite à une seule personne, avec une
croissance prévue qui pourra inclure des agents IA comme contributeurs
autonomes à l'infrastructure. Le secteur visé (finance/banque) impose des
standards élevés d'auditabilité : toute modification d'infrastructure doit
pouvoir être proposée, revue et tracée avant d'être appliquée, quel que soit
l'auteur (humain ou agent).

L'outil d'Infrastructure as Code retenu doit donc :
- fonctionner sur plusieurs fournisseurs cloud sans réécriture ;
- s'intégrer nativement à un flux plan → review → apply, gouverné par les
  pull requests (protection de branche + CI déjà en place sur ce repo) ;
- rester exploitable par une équipe qui passera de 1 à plusieurs
  contributeurs, humains et/ou agents.

## Options envisagées
1. **Terraform** (HashiCorp, propriété IBM depuis 2024, licence BSL depuis 2023)
   — multi-cloud, écosystème mature.
2. **OpenTofu** — fork communautaire de Terraform créé en réaction au
   changement de licence, gouvernance Linux Foundation, licence Apache 2.0,
   syntaxe HCL identique.
3. **AWS CloudFormation / CDK** — natif AWS, écarté d'emblée : aucune
   portabilité vers Azure, ne répond pas au besoin multi-cloud.
4. **Pulumi** — multi-cloud, IaC en langage de programmation (TypeScript,
   Python, Go) plutôt que déclaratif.
5. **Ansible seul** — orienté configuration et déploiement applicatif, pas
   conçu pour la gestion déclarative de ressources cloud avec état.

## Décision
Terraform.

## Justification
- **Cohérence d'écosystème** : trajectoire à terme vers d'autres outils de la
  suite HashiCorp (Vault pour la gestion des secrets en particulier), ce qui
  favorise un modèle de support et de compétences unifié plutôt que
  fragmenté entre plusieurs fournisseurs d'outillage.
- **Reconnaissance marché** : à compétences techniques équivalentes à
  OpenTofu (syntaxe HCL identique), Terraform reste la référence nommée dans
  la grande majorité des offres d'emploi et des entretiens techniques —
  pertinent pour un objectif de progression vers un rôle de Senior Platform
  Architect où l'employabilité et le vocabulaire partagé avec une équipe
  comptent autant que la technique pure.
- **Couverture multi-cloud** : Terraform et OpenTofu répondent tous deux au
  besoin AWS+Azure via des providers officiels matures ; ce critère ne
  départage pas les deux, mais élimine CloudFormation/CDK.
- **Dépendance assumée** : le risque de concentration sur un fournisseur
  unique (HashiCorp/IBM) est identifié et accepté en connaissance de cause,
  avec des mitigations explicites (voir ci-dessous) plutôt qu'ignoré.

## Conséquences
### Positives
- Un seul outil et une seule syntaxe (HCL) pour couvrir AWS et Azure.
- Modèle déclaratif avec `plan`/`apply` : toute modification est prévisible
  et revue avant application, ce qui s'appuie directement sur la protection
  de branche et le check CI `pre-commit` déjà configurés sur ce repo.
- Écosystème de providers et de modules réutilisables très large et mature,
  réduisant le code à écrire et maintenir soi-même.
- Trajectoire cohérente vers une intégration future avec Vault si un besoin
  de gestion centralisée des secrets apparaît.

### Négatives
- Dépendance à un fournisseur commercial unique (HashiCorp, propriété IBM
  depuis 2024), dont la licence a déjà changé une fois (MPL → BSL, 2023) —
  rien ne garantit l'absence d'un nouveau changement de conditions
  (licence, tarification, fonctionnalités reléguées à une offre payante).
- Le `tfstate` doit être géré rigoureusement (backend distant, verrouillage)
  pour rester fiable ; mal géré, il devient un point de fragilité — pas une
  garantie — en particulier si le nombre de contributeurs augmente
  (agents IA compris) et que des applications concurrentes doivent être
  arbitrées.
- OpenTofu, l'alternative qui aurait réduit ce risque de concentration
  fournisseur, n'est pas retenue malgré son intérêt — ce choix devra être
  réévalué si la relation avec HashiCorp/IBM se dégrade.

### Risques et mitigations
| Risque | Mitigation |
|---|---|
| Nouveau changement de licence ou de tarification HashiCorp/IBM | Le code HCL reste aujourd'hui compatible OpenTofu (fork syntaxique identique) ; migration possible en dernier recours. Cet ADR sera réévalué si un événement vendor majeur survient. |
| State corrompu, perdu, ou appliqué de façon concurrente | Backend distant versionné et verrouillé (S3+DynamoDB, ou équivalent managé) dès qu'un deuxième contributeur (humain ou agent) intervient. En attendant, le gate PR obligatoire + CI déjà en place empêche tout apply non revu. |
| Dérive multi-cloud sans discipline (logique dupliquée par provider) | Modules Terraform organisés par domaine fonctionnel plutôt que par cloud ; revue à froid de la structure si la trajectoire Azure se précise réellement. |

## Points ouverts
- Faut-il mettre en place un backend Terraform distant dès maintenant, ou
  seulement à l'arrivée d'un deuxième contributeur (humain ou agent) ?
- Le multi-cloud restant exploratoire à ce stade, la structure
  `environments/` doit-elle déjà anticiper Azure, ou rester AWS-only tant
  qu'aucun besoin concret ne se présente ?
- À quel signal concret (changement de licence, de pricing, d'acquisition)
  cet ADR devrait-il être formellement rouvert pour reconsidérer OpenTofu ?
