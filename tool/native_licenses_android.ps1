[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ApkPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$apk = (Resolve-Path -LiteralPath $ApkPath).Path
$output = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $output
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$licenseName = [regex]::new('^(LICENSE|NOTICE|COPYING)(\.[^/]*)?$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
$zip = [IO.Compression.ZipFile]::OpenRead($apk)
try {
    $entries = @(
        $zip.Entries |
            Where-Object {
                -not $_.FullName.EndsWith('/') -and
                $licenseName.IsMatch([IO.Path]::GetFileName($_.FullName))
            } |
            Sort-Object FullName
    )

    $builder = [Text.StringBuilder]::new()
    [void]$builder.AppendLine('# Android native notices extracted from an APK')
    [void]$builder.AppendLine("# APK: $([IO.Path]::GetFileName($apk))")
    [void]$builder.AppendLine("# Generated UTC: $([DateTime]::UtcNow.ToString('o'))")
    [void]$builder.AppendLine('# Scope: only license/notice files physically present in this APK.')
    [void]$builder.AppendLine('# This is not a declaration that all resolved native dependencies are covered.')
    [void]$builder.AppendLine()

    if ($entries.Count -eq 0) {
        [void]$builder.AppendLine('# No matching LICENSE, NOTICE, or COPYING files were found.')
    }

    foreach ($entry in $entries) {
        $memory = [IO.MemoryStream]::new()
        try {
            $stream = $entry.Open()
            try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
            $bytes = $memory.ToArray()
            $hash = [Security.Cryptography.SHA256]::HashData($bytes)
            $sha256 = ([BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
            [void]$builder.AppendLine("===== $($entry.FullName) | bytes=$($bytes.Length) | sha256=$sha256 =====")
            [void]$builder.AppendLine([Text.Encoding]::UTF8.GetString($bytes).TrimEnd())
            [void]$builder.AppendLine()
        } finally {
            $memory.Dispose()
        }
    }

    [IO.File]::WriteAllText($output, $builder.ToString(), [Text.UTF8Encoding]::new($false))
    Write-Output "Wrote $($entries.Count) notice/license files to $output"
} finally {
    $zip.Dispose()
}
