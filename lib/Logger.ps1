function _CleanupStuckLogs {
    param($Connection)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = @"
UPDATE logger
SET status='FAIL', end_time=NOW(), last_update_time=NOW(),
    messages = COALESCE(messages, '') || chr(10) || '$timestamp [WARN] Processus probablement planté : aucune activité depuis plus de 30 minutes'
WHERE status='RUNNING' AND last_update_time < (NOW() - INTERVAL '30 minutes')
"@
    $rows = $cmd.ExecuteNonQuery()
    if ($rows -gt 0) { Write-Host "[Logger] $rows log(s) RUNNING bloqué(s) → FAIL" }
}

function Ensure-LogTable {
    param($Connection)

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = @"
CREATE TABLE IF NOT EXISTS logger (
    id           SERIAL PRIMARY KEY,
    script_name  VARCHAR(255) NOT NULL,
    start_time   TIMESTAMP    NOT NULL,
    end_time     TIMESTAMP,
    last_update_time TIMESTAMP,
    status       VARCHAR(10)  NOT NULL CHECK (status IN ('RUNNING','SUCCESS','FAIL')),
    messages     TEXT
);
"@
    $null = $cmd.ExecuteNonQuery()
}

function Start-Log {
    param($Connection, [string]$ScriptName)

    _CleanupStuckLogs -Connection $Connection

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = "INSERT INTO logger (script_name, start_time, status, messages, last_update_time) VALUES (@name, NOW(), 'RUNNING', '$timestamp Démarrage...', NOW()) RETURNING id"
    $cmd.Parameters.AddWithValue("@name", $ScriptName) | Out-Null
    return [int]$cmd.ExecuteScalar()
}

function Log-Message {
    param($Connection, [int]$LogId, [string]$Message)

    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Write-Host $line

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = "UPDATE logger SET messages = COALESCE(messages,'') || chr(10) || @msg, last_update_time = NOW() WHERE id = @id"
    $cmd.Parameters.AddWithValue("@msg", $line) | Out-Null
    $cmd.Parameters.AddWithValue("@id", $LogId)  | Out-Null
    $null = $cmd.ExecuteNonQuery()
}

function End-Log {
    param($Connection, [int]$LogId, [string]$Status)

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = "UPDATE logger SET status=@status, end_time=NOW(), last_update_time=NOW() WHERE id=@id"
    $cmd.Parameters.AddWithValue("@status", $Status) | Out-Null
    $cmd.Parameters.AddWithValue("@id",     $LogId)  | Out-Null
    $null = $cmd.ExecuteNonQuery()
}
