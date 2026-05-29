function Convert-ToSqlValue {
    param([Parameter(Mandatory=$true)] $rawVal)

    if ($null -eq $rawVal -or [string]::IsNullOrWhiteSpace("$rawVal")) {
        return "NULL"
    }

    $s = $rawVal.ToString().Trim()

    # Date au format FR : dd/MM/yyyy HH:mm:ss
    if ($s -match "^\d{1,2}/\d{1,2}/\d{4} \d{2}:\d{2}:\d{2}$") {
        $dt = [datetime]::ParseExact($s, "dd/MM/yyyy HH:mm:ss", $null)
        return "'$($dt.ToString('yyyy-MM-dd HH:mm:ss'))'"
    }

    # Décimal FR (virgule → point)
    if ($s -match "^[+-]?\d+,\d+$") {
        return $s.Replace(",", ".")
    }

    # Chaîne : échappement des apostrophes
    return "'$($s.Replace("'", "''"))'"
}
