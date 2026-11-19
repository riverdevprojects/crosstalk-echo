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

    $changed = (@($json.words) -join "`n") -cne ($clean -join "`n")
    if ($Fix -and $changed) {
        $json.words = $clean.ToArray()
        # Replace only the "words" array in the original text, so every other
        # field (including optional ones that may be absent) stays as written.
        $lines = @()
        for ($i = 0; $i -lt $clean.Count; $i += 10) {
            $chunk = $clean[$i..([Math]::Min($i + 9, $clean.Count - 1))] |
                ForEach-Object { '"' + $_.Replace('\', '\\').Replace('"', '\"') + '"' }
            $lines += "    " + ($chunk -join ", ")
        }
        $array = "`"words`": [`n" + ($lines -join ",`n") + "`n  ]"
        $text = [System.IO.File]::ReadAllText($file.FullName)
        $pattern = '"words"\s*:\s*\[(?:[^\[\]"]|"(?:[^"\\]|\\.)*")*\]'
        if (-not [regex]::IsMatch($text, $pattern)) {
            "  !! couldn't find the words array in $($file.Name); left unchanged"
            $ok = $false
            continue
        }
        $text = [regex]::Replace($text, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $array })
        [System.IO.File]::WriteAllText($file.FullName, $text, (New-Object System.Text.UTF8Encoding($false)))
        "  -> rewrote words in $($file.Name)"
    }
}
if (-not $ok -and -not $Fix) { exit 1 }
