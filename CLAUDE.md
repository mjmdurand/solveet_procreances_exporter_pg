# CLAUDE.md — Contexte projet pour Claude Code

## Rôle du projet

ETL PowerShell qui extrait les données d'une base **HFSQL** (logiciel Procréances, via ODBC) et les insère dans une base **PostgreSQL**.

## Stack technique

| Composant | Détail |
|---|---|
| Script principal | `run.ps1` (PowerShell 7 recommandé) |
| Source données | HFSQL via ODBC (driver PC SOFT WINDEV) |
| Destination | PostgreSQL 192.168.40.60:5432, base `procreances` |
| Driver PG | Npgsql 3.2.7 (`drivers/Npgsql40.dll`, netstandard2.0) |
| Config | Fichier `.env` (gitignore) — modèle : `.env.config` |

## Structure

```
run.ps1                  Script principal
lib/
  LoadDotEnv.ps1         Lecture du fichier .env
  HfsqlHelper.ps1        Invoke-HFSelect (requête HFSQL → DataTable)
  SqlHelper.ps1          Convert-ToSqlValue (conversion valeurs → SQL)
  Logger.ps1             Table logger dans PostgreSQL
sql/
  create/                CREATE TABLE pour chaque table (16 tables)
  select/                SELECT HFSQL pour chaque table
  install.sql            CREATE DATABASE procreances
drivers/
  Npgsql40.dll           Npgsql 3.2.7 netstandard2.0 (gitignore)
  *.dll                  Dépendances (gitignore)
```

## Lancer l'import

```powershell
# Toutes les tables
.\run.ps1

# Une table spécifique
.\run.ps1 -TableToExport CLIENT

# Avec un fichier .env alternatif
.\run.ps1 -EnvFile .env-preprod
```

## Variables .env

```dotenv
DSN_HFSQL   = "NOM_SOURCE_ODBC"
PG_HOST     = "192.168.40.60"
PG_DB       = "procreances"
PG_USER     = "user"
PG_PASSWORD = "password"
PG_PORT     = "5432"
```

## Conventions SQL

- Les scripts `sql/create/` sont en syntaxe **PostgreSQL pure** (pas de MySQL)
- `TINYINT(1)` → `SMALLINT`, `AUTO_INCREMENT` → `SERIAL`, pas de `KEY` inline
- Les tables avec index ont leurs `CREATE INDEX` en fin de fichier `.sql`
- Les scripts `sql/select/` requêtent la source HFSQL (syntaxe HF SQL)

## Driver Npgsql

`drivers/Npgsql40.dll` est gitignore. Pour le remettre en place sur une nouvelle machine :

```powershell
$tmp = "$env:TEMP\npgsql"
New-Item -ItemType Directory -Force $tmp | Out-Null
& nuget install Npgsql -Version 3.2.7 -OutputDirectory $tmp -Source "https://api.nuget.org/v3/index.json"
Copy-Item "$tmp\Npgsql.3.2.7\lib\netstandard2.0\Npgsql.dll" -Destination ".\drivers\Npgsql40.dll"
```

## Logger

L'import crée et alimente automatiquement une table `logger` dans PostgreSQL :

```sql
id, script_name, start_time, end_time, last_update_time, status, messages
```

`status` peut être `RUNNING`, `SUCCESS` ou `FAIL`. Les logs bloqués en `RUNNING` depuis plus de 30 minutes sont automatiquement marqués `FAIL`.

## Points d'attention

- PowerShell 7 (`pwsh`) requis — PowerShell 5.1 (`powershell.exe`) cause des conflits de version DLL avec Npgsql
- Le DSN HFSQL doit être configuré dans les sources ODBC Windows (driver HFSQL de PC SOFT)
- Chaque import fait un `RENAME TO _backup` de la table existante avant de la recréer
- Les insertions sont faites en transactions par lots de 10 000 lignes
