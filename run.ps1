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

    $createFiles = if ($TableToExport -ne "ALL") {
        $f = Get-ChildItem $sqlCreate -Filter "$TableToExport.sql"
        if (-not $f) { throw "Table '$TableToExport' introuvable dans $sqlCreate" }
        $f
    } else {
        Get-ChildItem $sqlCreate -Filter "*.sql"
    }

    foreach ($createFile in $createFiles) {
        $tableName  = $createFile.BaseName
        $backupName = "${tableName}_backup"
        $selectFile = Join-Path $sqlSelect "$tableName.sql"

        if (-not (Test-Path $selectFile)) {
            Log-Message -Connection $pgConn -LogId $logId -Message "[SKIP] $tableName — pas de fichier SELECT"
            continue
        }

        $pgCmd = $pgConn.CreateCommand()

        $pgCmd.CommandText = "DROP TABLE IF EXISTS $backupName"
        $null = $pgCmd.ExecuteNonQuery()

        $pgCmd.CommandText = "ALTER TABLE $tableName RENAME TO $backupName"
        try   { $null = $pgCmd.ExecuteNonQuery(); Log-Message -Connection $pgConn -LogId $logId -Message "[INFO] $tableName → $backupName" }
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
            $vals = @(foreach ($col in $cols) { Convert-ToSqlValue $row[$col] $col })
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
