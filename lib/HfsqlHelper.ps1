function Invoke-HFSelect {
    param(
        [string]$sql,
        [System.Data.Odbc.OdbcConnection]$conn
    )

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $sql
    $reader = $cmd.ExecuteReader()

    $table = New-Object System.Data.DataTable "Result"
    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
        [void]$table.Columns.Add($reader.GetName($i), [string])
    }

    while ($reader.Read()) {
        $row = $table.NewRow()
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            if (-not $reader.IsDBNull($i)) {
                $row[$i] = [Convert]::ToString($reader.GetValue($i))
            } else {
                $row[$i] = ""
            }
        }
        $table.Rows.Add($row)
    }

    $reader.Close()
    return ,$table
}