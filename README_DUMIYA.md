# DUMIYA Client V0.5 TEST

Application Flutter mono-boutique. Ouverture directe du catalogue e-commerce DUMIYA via `storefront/dumiya`, sans écran de sélection de boutique. Préserve les catégories, la recherche, le panier, WhatsApp et WonyaPay avec vérification côté Odoo. Logo DUMIYA intégré dans la génération des icônes Android et iOS.

## Configuration Odoo 18

Installer/mettre à jour `locintel_shop_core` V0.5. Dans LOCINTEL Shop > Boutiques, créer/mettre à jour une boutique publiée, active, slug `dumiya`, rattachée à la société et au site e-commerce DUMIYA. Indiquer le numéro WhatsApp, la caisse WonyaPay et le logo. Cliquer « Importer les produits publiés du site e-commerce ». La synchronisation est manuelle : relancer après ajout de produits. Les produits non publiés sont exclus par l’API.

## Compilation

Définir `SHOP_API_BASE=https://votre-domaine` dans les variables GitHub Actions. Les workflows utilisent `SHOP_STORE_SLUG=dumiya`. Exécuter les workflows Android et iOS. Android produit un APK debug, iOS un binaire simulateur non signé, **pas un IPA App Store**. Pour publier les deux applications indépendamment, fixer un identifiant Android package et un bundle ID iOS propres à DUMIYA avec signatures et provisioning dédiés.

## Notes

L’application requiert HTTPS. Les commandes sont créées côté Odoo ; WonyaPay ne marque payé qu’après vérification serveur. Le panier reste uniquement en mémoire pendant la session (comportement de la base V0.4), sans sauvegarde hors ligne. Les prix sont affichés selon la société configurée ; à valider si pricelists ou taxes spéciales. Pas de compilation réelle dans cet environnement.
