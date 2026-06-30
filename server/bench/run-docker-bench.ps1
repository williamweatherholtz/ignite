# issue004 — honest end-to-end Ignis-vs-Ignite benchmark in Docker's bind-mount context.
# Fills the 2x2 matrix {Ignite parallel-Rust, Ignis sequential-Node} x {native, Docker}.
# Native numbers are already recorded (Ignite ~20ms; Node 657ms cold / 216ms warm).
# This script fills the DOCKER row. Requires Docker Desktop running.
#
#   pwsh server/bench/run-docker-bench.ps1 "C:\Users\WilliamWeatherholtz\Downloads\Games"

param([Parameter(Mandatory=$true)][string]$VaultPath)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverDir = Split-Path -Parent $here

Write-Host "=== Building Ignite bench image (binary on fast container FS) ===" -ForegroundColor Cyan
docker build -t ignite-bench $serverDir

Write-Host "`n=== [Docker] Ignite (parallel Rust) reading bind-mounted vault ===" -ForegroundColor Cyan
docker run --rm -v "${VaultPath}:/vault:ro" ignite-bench /vault

Write-Host "`n=== [Docker] Ignis-algorithm (sequential Node) on the SAME bind mount ===" -ForegroundColor Cyan
docker run --rm -v "${VaultPath}:/vault:ro" -v "${here}:/bench:ro" node:24-slim `
    node /bench/ignis-walk-baseline.js /vault

Write-Host "`nCompare these Docker numbers to the recorded NATIVE numbers (Ignite ~20ms; Node 657/216ms)." -ForegroundColor Yellow
Write-Host "If both Docker numbers balloon vs native -> Docker bind-mount FS is the dominant factor (issue004 confirmed)." -ForegroundColor Yellow
