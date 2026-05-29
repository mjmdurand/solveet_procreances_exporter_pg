# Procreances Data Importer

ETL PowerShell qui extrait les données d'une base **HFSQL** (logiciel Procréances) via ODBC et les insère dans une base **PostgreSQL**.

## Prérequis

1. **PowerShell 7** (`pwsh`) — PowerShell 5.1 n'est pas compatible
2. **Driver HFSQL** (PC SOFT WINDEV) installé et source ODBC configurée dans Windows
3. **Npgsql 3.2.7** placé dans `drivers/Npgsql40.dll` (voir ci-dessous)
4. Un fichier `.env` à la racine du projet (voir `.env.config` comme modèle)

## Installation de Npgsql

`drivers/*.dll` est gitignore. À exécuter une fois sur chaque poste :

```powershell
$tmp = "$env:TEMP\npgsql"
New-Item -ItemType Directory -Force $tmp | Out-Null
& nuget install Npgsql -Version 3.2.7 -OutputDirectory $tmp -Source "https://api.nuget.org/v3/index.json"
Copy-Item "$tmp\Npgsql.3.2.7\lib\netstandard2.0\Npgsql.dll" -Destination ".\drivers\Npgsql40.dll"
```

## Configuration

Copier `.env.config` en `.env` et renseigner les valeurs :

```dotenv
# HFSQL (ODBC)
DSN_HFSQL = "NOM_SOURCE_ODBC"

# PostgreSQL
PG_HOST     = "192.168.40.60"
PG_DB       = "procreances"
PG_USER     = "user"
PG_PASSWORD = "password"
PG_PORT     = "5432"
```

## Utilisation

```powershell
# Importer toutes les tables
.\run.ps1

# Importer une table spécifique
.\run.ps1 -TableToExport CLIENT

# Utiliser un fichier .env alternatif
.\run.ps1 -EnvFile .env-preprod
```

## Fonctionnement

Pour chaque table :

1. La table existante est renommée en `<TABLE>_backup`
2. La nouvelle table est créée depuis `sql/create/<TABLE>.sql`
3. Les données sont lues depuis HFSQL via `sql/select/<TABLE>.sql`
4. Les insertions sont faites en **transactions par lots de 10 000 lignes**

Un log d'exécution est automatiquement enregistré dans la table `logger` de PostgreSQL.

## Structure du projet

```
run.ps1              Script principal
lib/
  LoadDotEnv.ps1     Lecture du fichier .env
  HfsqlHelper.ps1    Requêtes HFSQL via ODBC
  SqlHelper.ps1      Conversion des valeurs vers SQL
  Logger.ps1         Logging en base PostgreSQL
sql/
  create/            Scripts CREATE TABLE (PostgreSQL)
  select/            Scripts SELECT HFSQL (16 tables)
  install.sql        Création de la base
drivers/
  Npgsql40.dll       Driver PostgreSQL (gitignore)
.env.config          Modèle de configuration
```

## Configuration ODBC HFSQL

1. Ouvrir **Sources de données ODBC** (Windows)
2. Ajouter une source de données système avec le driver **HFSQL**
3. Pointer vers le répertoire de la base Procréances
4. Renseigner le nom de la source dans `DSN_HFSQL`

Le driver HFSQL est disponible sur : https://download.windev.com/fr/download/neo/HFSQL/2026.awp
