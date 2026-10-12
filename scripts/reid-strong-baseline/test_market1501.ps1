#Requires -Version 5.1
<#
.SYNOPSIS
  Run official reid-strong-baseline tools/test.py on Market1501 (inference only).

.PARAMETER ReidRepoRoot
  Root of git clone https://github.com/michuanhaohao/reid-strong-baseline

.PARAMETER PythonExe
  Python interpreter (venv) with torch, ignite, yacs installed.

.PARAMETER DataRoot
  DATASETS.ROOT_DIR (default: ReidRepoRoot/data).

.PARAMETER WeightPath
  TEST.WEIGHT (default: ReidRepoRoot/pretrained/market1501/resnet50_model_120.pth).

.PARAMETER DeviceId
  GPU id for MODEL.DEVICE_ID (default 0).

.PARAMETER OutputDir
  OUTPUT_DIR for logs (default: ReidRepoRoot/outputs/reproduction_acceptance/run_<timestamp>).

.PARAMETER NumWorkers
  DATALOADER.NUM_WORKERS (default 0 for Windows).
#>
[CmdletBinding()]
param(
    [string] $ReidRepoRoot = $env:REID_REPO_ROOT,
    [string] $PythonExe = $env:REID_PYTHON,
    [string] $DataRoot = $env:REID_DATA_ROOT,
    [string] $WeightPath = $env:REID_WEIGHT,
    [string] $DeviceId = "0",
    [string] $OutputDir = $env:REID_OUTPUT_DIR,
    [int] $NumWorkers = 0
)

$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath {
    param([string] $Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $full = [System.IO.Path]::GetFullPath($Path)
    return ($full -replace '\\', '/')
}

if ([string]::IsNullOrWhiteSpace($ReidRepoRoot)) {
    Write-Error "Set -ReidRepoRoot or env REID_REPO_ROOT to your reid-strong-baseline clone."
}
if ([string]::IsNullOrWhiteSpace($PythonExe)) {
    $guess = Join-Path (Split-Path $ReidRepoRoot -Parent) "reid-strong-baseline-py310\Scripts\python.exe"
    if (Test-Path $guess) { $PythonExe = $guess }
    else { Write-Error "Set -PythonExe or env REID_PYTHON." }
}

if (-not (Test-Path $ReidRepoRoot)) { Write-Error "ReidRepoRoot not found: $ReidRepoRoot" }
if (-not (Test-Path $PythonExe)) { Write-Error "PythonExe not found: $PythonExe" }

$testPy = Join-Path $ReidRepoRoot "tools\test.py"
$config = Join-Path $ReidRepoRoot "configs\softmax_triplet_with_center.yml"
if (-not (Test-Path $testPy)) { Write-Error "Missing tools/test.py under ReidRepoRoot." }
if (-not (Test-Path $config)) { Write-Error "Missing configs/softmax_triplet_with_center.yml." }

if ([string]::IsNullOrWhiteSpace($DataRoot)) {
    $DataRoot = Join-Path $ReidRepoRoot "data"
}
if ([string]::IsNullOrWhiteSpace($WeightPath)) {
    $WeightPath = Join-Path $ReidRepoRoot "pretrained\market1501\resnet50_model_120.pth"
}
if (-not (Test-Path $WeightPath)) {
    Write-Error "Weight not found: $WeightPath (see docs/reid-strong-baseline/REPRODUCTION.md)."
}

$market = Join-Path $DataRoot "market1501"
foreach ($sub in @("bounding_box_train", "query", "bounding_box_test")) {
    $p = Join-Path $market $sub
    if (-not (Test-Path $p)) { Write-Error "Missing dataset folder: $p" }
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = Join-Path $ReidRepoRoot "outputs\reproduction_acceptance\run_$stamp"
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$dataNorm = Resolve-NormalizedPath $DataRoot
$weightNorm = Resolve-NormalizedPath $WeightPath
$outNorm = Resolve-NormalizedPath $OutputDir

Write-Host "ReidRepoRoot: $ReidRepoRoot"
Write-Host "PythonExe:    $PythonExe"
Write-Host "DataRoot:     $dataNorm"
Write-Host "Weight:       $weightNorm"
Write-Host "OutputDir:    $outNorm"

Push-Location $ReidRepoRoot
try {
    & $PythonExe $testPy `
        --config_file "configs/softmax_triplet_with_center.yml" `
        MODEL.DEVICE_ID "('$DeviceId')" `
        DATASETS.NAMES "('market1501')" `
        DATASETS.ROOT_DIR "('$dataNorm')" `
        MODEL.PRETRAIN_CHOICE "('self')" `
        TEST.WEIGHT "('$weightNorm')" `
        TEST.NECK_FEAT "('after')" `
        TEST.FEAT_NORM "('yes')" `
        OUTPUT_DIR "('$outNorm')" `
        DATALOADER.NUM_WORKERS "($NumWorkers)"
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($code -ne 0) {
    Write-Error "test.py exited with code $code. See log under $OutputDir"
}
Write-Host "Done. Logs: $OutputDir\log.txt"
