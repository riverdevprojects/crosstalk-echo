# Validates Crosstalk/Resources/Themes/Theme-*.json and prints per-theme word counts.
# Usage: powershell -File tools/check-themes.ps1 [-Fix]
#   -Fix rewrites each file with duplicates removed (case-insensitive, first kept)
#        and words trimmed and lowercased, preserving order.
param([switch]$Fix)

$dir = Join-Path $PSScriptRoot "..\Crosstalk\Resources\Themes"
$ok = $true
foreach ($file in Get-ChildItem (Join-Path $dir "Theme-*.json") | Sort-Object Name) {
    $json = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $seen = @{}
    $clean = New-Object System.Collections.Generic.List[string]
    $dups = @()
    foreach ($w in $json.words) {
        $t = $w.Trim().ToLower()
        if ($t -eq "") { continue }
        if ($seen.ContainsKey($t)) { $dups += $t; continue }
        $seen[$t] = $true
        $clean.Add($t)
    }
    $multi = @($clean | Where-Object { $_ -match "[ \-]" }).Count
    "{0,-22} {1,5} words  ({2} multi-word)  dups: {3}" -f $json.name, $clean.Count, $multi, ($(if ($dups) { $dups -join ", " } else { "none" }))
    if ($dups) { $ok = $false }

    if ($Fix -and ($dups -or ($clean.Count -ne $json.words.Count))) {
        $json.words = $clean.ToArray()
        $lines = @()
        for ($i = 0; $i -lt $clean.Count; $i += 10) {
            $chunk = $clean[$i..([Math]::Min($i + 9, $clean.Count - 1))] | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }
            $lines += "    " + ($chunk -join ", ")
        }
        $body = "{`n" +
            "  `"id`": `"$($json.id)`",`n" +
            "  `"name`": `"$($json.name)`",`n" +
            "  `"order`": $($json.order),`n" +
            "  `"showsNameToEcho`": $($json.showsNameToEcho.ToString().ToLower()),`n" +
            "  `"words`": [`n" + ($lines -join ",`n") + "`n  ]`n}`n"
        [System.IO.File]::WriteAllText($file.FullName, $body, (New-Object System.Text.UTF8Encoding($false)))
        "  -> rewrote $($file.Name)"
    }
}
if (-not $ok -and -not $Fix) { exit 1 }
