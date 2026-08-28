param(
    [string]$LuaPath,
    [string]$LuacPath
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-LuaTool {
    param([string]$ExplicitPath, [string[]]$CommandNames, [string]$BundledName)
    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) { throw "Lua tool not found: $ExplicitPath" }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    foreach ($name in $CommandNames) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    $bundled = Join-Path $env:LOCALAPPDATA "Programs\Lua51\$BundledName"
    if (Test-Path -LiteralPath $bundled) { return $bundled }
    throw "Lua 5.1 tool not found. Pass -LuaPath and -LuacPath explicitly."
}

$lua = Resolve-LuaTool $LuaPath @("lua5.1", "lua") "lua.exe"
$luac = Resolve-LuaTool $LuacPath @("luac5.1", "luac") "luac.exe"

Push-Location $repositoryRoot
try {
    $addonFiles = @(Get-ChildItem -LiteralPath "HCOneButton" -Recurse -Filter "*.lua" | Sort-Object FullName)
    foreach ($file in $addonFiles) {
        & $luac -p $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Lua parse failed: $($file.FullName)" }
    }
    Write-Host "addon parse: $($addonFiles.Count)/$($addonFiles.Count)"

    $testFiles = @(Get-ChildItem -LiteralPath "tests" -Filter "*.lua" | Sort-Object Name)
    foreach ($file in $testFiles) {
        & $luac -p $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Test parse failed: $($file.FullName)" }
        & $lua $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "Test failed: $($file.FullName)" }
    }
    Write-Host "tests: $($testFiles.Count)/$($testFiles.Count)"
}
finally {
    Pop-Location
}
