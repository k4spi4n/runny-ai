[CmdletBinding()]
param(
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$functionsRoot = Join-Path $repoRoot "supabase\functions"
$sharedRoot = Join-Path $functionsRoot "_shared"

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot "artifacts\supabase-dashboard-functions"
}
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
[void](New-Item -ItemType Directory -Path $outputPath -Force)

$functionNames = @(
    "openrouter",
    "training-plan",
    "training-plan-worker",
    "weather",
    "food-recognition",
    "strava_oauth",
    "strava_webhook",
    "strava-webhook-worker",
    "payos-create-payment",
    "payos-webhook"
)

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stageRoot = Join-Path $tempBase ("runny-ai-functions-" + [guid]::NewGuid())
[void](New-Item -ItemType Directory -Path $stageRoot)

try {
    foreach ($functionName in $functionNames) {
        $functionSource = Join-Path $functionsRoot $functionName
        if (-not (Test-Path -LiteralPath (Join-Path $functionSource "index.ts"))) {
            throw "Missing Edge Function entrypoint: $functionSource\index.ts"
        }

        $stage = Join-Path $stageRoot $functionName
        [void](New-Item -ItemType Directory -Path $stage)
        Get-ChildItem -LiteralPath $functionSource -Force |
            Copy-Item -Destination $stage -Recurse -Force
        Copy-Item -LiteralPath $sharedRoot `
            -Destination (Join-Path $stage "_shared") -Recurse -Force

        # Dashboard ZIP uploads use index.ts at the archive root. Move sibling
        # _shared imports into that root without changing repository imports.
        Get-ChildItem -LiteralPath $stage -Recurse -Filter "*.ts" |
            ForEach-Object {
                $text = [IO.File]::ReadAllText($_.FullName)
                $text = $text.Replace('"../_shared/', '"./_shared/')
                $text = $text.Replace("'../_shared/", "'./_shared/")
                if ($text.Contains("../_shared/")) {
                    throw "Unrewritten shared import in $($_.FullName)"
                }
                [IO.File]::WriteAllText(
                    $_.FullName,
                    $text,
                    [Text.UTF8Encoding]::new($false)
                )
            }

        $zipPath = Join-Path $outputPath "$functionName.zip"
        Compress-Archive -Path (Join-Path $stage "*") `
            -DestinationPath $zipPath -CompressionLevel Optimal -Force
        Write-Output $zipPath
    }

    $manifest = foreach ($zip in Get-ChildItem -LiteralPath $outputPath -Filter "*.zip") {
        $hash = Get-FileHash -LiteralPath $zip.FullName -Algorithm SHA256
        [pscustomobject]@{
            file = $zip.Name
            sha256 = $hash.Hash.ToLowerInvariant()
        }
    }
    $manifest |
        Sort-Object file |
        ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $outputPath "manifest.json") `
            -Encoding utf8
}
finally {
    $resolvedStage = [IO.Path]::GetFullPath($stageRoot)
    $safePrefix = $tempBase.TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedStage.StartsWith(
        $safePrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to remove unsafe staging path: $resolvedStage"
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
