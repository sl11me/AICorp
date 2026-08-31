# Bootstrap — socle de state Terraform

Cette racine crée le bucket S3 et la clé KMS qui hébergent tous les autres
states d'AICorp. Elle est particulière : elle stocke son propre state dans
le bucket qu'elle a elle-même créé.

## Reconstruction depuis zéro

    terraform init            # backend local
    terraform apply           # bucket + cle KMS
    # decommenter backend.tf
    terraform init -migrate-state

## Pièges connus

**`prevent_destroy` sur le bucket et la clé.** Toute opération impliquant
un remplacement (renommage du bucket, changement de région) échouera. Pour
la mener : retirer temporairement le bloc `lifecycle`, appliquer, le
remettre. C'est volontairement pénible.

**Dépendance circulaire assumée.** Si le bucket disparaît, cette racine ne
peut plus être pilotée par Terraform. Reprise : reconstruire avec un
backend local, puis réimporter les ressources survivantes.

**Verrou bloqué.** `terraform force-unlock <LOCK_ID>`, uniquement après
avoir vérifié qu'aucun apply n'est en cours.

## Coût mensuel estimé

| Poste | Estimation |
|---|---|
| Clé KMS | ~1,00 USD |
| Stockage S3 (states < 1 Mo) | < 0,01 USD |
| Requêtes KMS (avec bucket key) | < 0,05 USD |
| **Total** | **~1,05 USD** |

Soit environ 20 % du garde-fou budgétaire de 5 USD. Vérifier les tarifs
en vigueur, ils évoluent.
