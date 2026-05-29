param(
    [string]$TableToExport = "ALL",
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"

Get-ChildItem (Join-Path $PSScriptRoot "lib") -Filter "*.ps1" | ForEach-Object { . $_.FullName }

$conf = Load-DotEnv -Path (Join-Path $PSScriptRoot $EnvFile)

[void][System.Reflection.Assembly]::LoadFrom((Join-Path $PSScriptRoot "drivers\Npgsql40.dll"))

$pgConn = New-Object Npgsql.NpgsqlConnection(
    "Host=$($conf.PG_HOST);Port=$($conf.PG_PORT);Username=$($conf.PG_USER);Password=$($conf.PG_PASSWORD);Database=$($conf.PG_DB)"
)
$pgConn.Open()

Ensure-LogTable -Connection $pgConn
$logId = Start-Log -Connection $pgConn -ScriptName "Import-Procreances"
Log-Message -Connection $pgConn -LogId $logId -Message "Démarrage..."

$sqlCreate = Join-Path $PSScriptRoot "sql\create"
$sqlSelect = Join-Path $PSScriptRoot "sql\select"

try {
    $connHFSQL = New-Object System.Data.Odbc.OdbcConnection("DSN=$($conf.DSN_HFSQL);UID=;PWD=")
    $connHFSQL.Open()

    # Schéma dédié aux backups
    $pgCmd = $pgConn.CreateCommand()
    $pgCmd.CommandText = "CREATE SCHEMA IF NOT EXISTS backup"
    $null = $pgCmd.ExecuteNonQuery()

    $createFiles = if ($TableToExport -ne "ALL") {
        $f = Get-ChildItem $sqlCreate -Filter "$TableToExport.sql"
        if (-not $f) { throw "Table '$TableToExport' introuvable dans $sqlCreate" }
        $f
    } else {
        Get-ChildItem $sqlCreate -Filter "*.sql"
    }

    foreach ($createFile in $createFiles) {
        $tableName  = $createFile.BaseName
        $selectFile = Join-Path $sqlSelect "$tableName.sql"

        if (-not (Test-Path $selectFile)) {
            Log-Message -Connection $pgConn -LogId $logId -Message "[SKIP] $tableName — pas de fichier SELECT"
            continue
        }

        $pgCmd = $pgConn.CreateCommand()

        # Déplacer la table courante dans le schéma backup (libère aussi les noms d'index)
        $pgCmd.CommandText = "DROP TABLE IF EXISTS backup.$tableName"
        $null = $pgCmd.ExecuteNonQuery()

        $pgCmd.CommandText = "ALTER TABLE public.$tableName SET SCHEMA backup"
        try   { $null = $pgCmd.ExecuteNonQuery(); Log-Message -Connection $pgConn -LogId $logId -Message "[INFO] $tableName → backup.$tableName" }
        catch { Log-Message -Connection $pgConn -LogId $logId -Message "[INFO] $tableName inexistante, pas de backup" }

        $pgCmd.CommandText = Get-Content $createFile.FullName -Raw
        $null = $pgCmd.ExecuteNonQuery()

        $data = Invoke-HFSelect -sql (Get-Content $selectFile -Raw) -conn $connHFSQL

        if ($data.Rows.Count -eq 0) {
            Log-Message -Connection $pgConn -LogId $logId -Message "[EMPTY] $tableName"
            continue
        }

        $cols       = @($data.Columns | ForEach-Object { $_.ColumnName })
        $colsJoined = $cols -join ','
        $batchSize  = 10000
        $batch      = [System.Collections.Generic.List[string]]::new()
        $total      = $data.Rows.Count
        $n          = 0

        $pgCmd.CommandText = "BEGIN"
        $null = $pgCmd.ExecuteNonQuery()

        foreach ($row in $data.Rows) {
            $vals = @(foreach ($col in $cols) { Convert-ToSqlValue $row[$col] })
            $batch.Add("($($vals -join ','))")
            $n++

            if ($n % $batchSize -eq 0 -or $n -eq $total) {
                $pgCmd.CommandText = "INSERT INTO $tableName ($colsJoined) VALUES $($batch -join ',')"
                $null = $pgCmd.ExecuteNonQuery()
                $batch.Clear()
            }
        }

        $pgCmd.CommandText = "COMMIT"
        $null = $pgCmd.ExecuteNonQuery()

        Log-Message -Connection $pgConn -LogId $logId -Message "[OK] $tableName — $total lignes"
    }

    Log-Message -Connection $pgConn -LogId $logId -Message "Terminé avec succès."
    End-Log -Connection $pgConn -LogId $logId -Status "SUCCESS"

} catch {
    Log-Message -Connection $pgConn -LogId $logId -Message "[ERROR] $_"
    End-Log -Connection $pgConn -LogId $logId -Status "FAIL"
} finally {
    if ($connHFSQL) { $connHFSQL.Close() }
    $pgConn.Close()
}
