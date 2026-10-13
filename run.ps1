# Windows PowerShell Simulation Runner for 8085 RTL Core
param(
    [string]$Testbench = "all"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   8085 Verilog Core - PowerShell Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Locate iverilog
$iverilog = Get-Command iverilog -ErrorAction SilentlyContinue
$vvp = Get-Command vvp -ErrorAction SilentlyContinue

if (-not $iverilog -or -not $vvp) {
    # Check default path C:\iverilog\bin
    if (Test-Path "C:\iverilog\bin\iverilog.exe") {
        $iverilogPath = "C:\iverilog\bin\iverilog.exe"
        $vvpPath = "C:\iverilog\bin\vvp.exe"
    } else {
        Write-Error "Icarus Verilog (iverilog.exe / vvp.exe) not found in PATH or C:\iverilog\bin."
        exit 1
    }
} else {
    $iverilogPath = $iverilog.Source
    $vvpPath = $vvp.Source
}

$allTests = @("tb_core_basic", "tb_core_16bit", "tb_core_stack_branch", "tb_core_sys_io", "tb_core_advanced")
$srcFiles = (Get-ChildItem src/*.v | ForEach-Object { $_.FullName })

if ($Testbench -eq "all") {
    $testsToRun = $allTests
} elseif ($allTests -contains $Testbench) {
    $testsToRun = @($Testbench)
} else {
    Write-Host "Invalid testbench name '$Testbench'." -ForegroundColor Red
    Write-Host "Available options: $($allTests -join ', '), all"
    exit 1
}

foreach ($t in $testsToRun) {
    Write-Host "`n>> Compiling testbench: $t..." -ForegroundColor Yellow
    & $iverilogPath -o "$t.vvp" $srcFiles "testbench/$t.v"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Compilation failed for $t!"
        exit 1
    }
    
    Write-Host ">> Executing simulation: $t..." -ForegroundColor Green
    & $vvpPath "$t.vvp"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Simulation failed for $t!"
        exit 1
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host ">> All requested simulations completed!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
