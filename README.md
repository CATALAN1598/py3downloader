# Py3Downloader

## Description

Py3Downloader est un outil d'administration permettant de **Télécharger**, **Archiver** puis d'**Importer** des librairies python pour des environnement Air-Gapped.

Ce projet regroupe 3 outils:

- **py3downloader.sh**: Outil de téléchargement des librairie depuis internet
- **py3archiver.sh**: Outil d'archivage des librairies pour un transfert (USB-proccessing ou réseau) vers un environnement partiellement ou completement déconnecté.
- **py3importer**: Outil d'import des librairie dans un dépôt local.

Ce pipeline de traitement nécessite 2 machines minimum:

- Une machine connecté à internet avec les outils **py3downloader** et **py3archiver** disponible dans le répertoire **download** de projet.
- Une machine dans le réseau Air-gapped avec les flux réseau vers un dépot local (example: Nexus-Repository).  

## Utilisation

Chaque outil possède son propre README.md afin de présenté au mieu l'utilisation des différents outils.

Tous les outils sont écrits en **BASH** et son GNU/Linux exportable.
 
