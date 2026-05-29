function Load-DotEnv {
    param(
        [string]$Path = ".\.env",
        [switch]$DebugMode = $false
    )

    if (-not (Test-Path $Path)) { throw "Fichier .env introuvable : $Path" }

    $loaded = @{}

    foreach ($line in Get-Content $Path) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }

        if ($line -match '^\s*([^=]+?)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()

            # Supprimer les quotes éventuelles
            if ($val -match '^"(.*)"$') { $val = $matches[1] }
            elseif ($val -match "^'(.*)'$") { $val = $matches[1] }

            # Définir dans le process courant
            $loaded[$key] = $val

            if ($DebugMode) { Write-Host "[OK] $key = $val" }
        }
        elseif ($DebugMode) {
            Write-Warning "[IGNORÉ] Ligne invalide : $line"
        }
    }

    if ($DebugMode) { Write-Host "✅ Variables .env chargées : $($loaded.Keys -join ', ')" }

    return $loaded
}
