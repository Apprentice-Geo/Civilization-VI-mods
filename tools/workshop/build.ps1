$ErrorActionPreference = 'Stop'
$manifest = Join-Path $PSScriptRoot 'Cargo.toml'

# Cargo reports the matching DLL location even when the dependency is already built.
$outputEncoding = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $messages = & cargo build --locked --manifest-path $manifest --bin civ6-workshop --message-format=json-render-diagnostics
    if ($LASTEXITCODE -ne 0) {
        throw "Cargo build failed with exit code $LASTEXITCODE."
    }
} finally {
    [Console]::OutputEncoding = $outputEncoding
}

$executable = $null
$steamDll = $null
foreach ($line in $messages) {
    $message = ConvertFrom-Json -InputObject $line
    if ($message.reason -eq 'compiler-artifact' -and $message.target.name -eq 'civ6-workshop' -and $message.executable) {
        $executable = $message.executable
    }
    if ($message.reason -eq 'build-script-executed') {
        foreach ($library in $message.linked_libs) {
            if ($library -match '^dylib=(steam_api(?:64)?)$') {
                $steamDll = Join-Path $message.out_dir ($Matches[1] + '.dll')
            }
        }
    }
}

if (-not $executable -or -not $steamDll) {
    throw 'Cargo did not report the Windows executable and its Steamworks DLL.'
}

Copy-Item -LiteralPath $steamDll -Destination (Split-Path -Parent $executable) -Force
Write-Output $executable
