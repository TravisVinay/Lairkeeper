# Runs Lairkeeper headless and prints only script errors and test output.
#   tools\check.ps1            re-import the project and report script errors
#   tools\check.ps1 -Sim       also run the headless playtest in tests/sim.tscn
# Set $env:GODOT to your Godot console executable if it lives somewhere else.
param([switch]$Sim)
$g = if ($env:GODOT) { $env:GODOT } else { "D:\godot engine\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" }
$p = Split-Path -Parent $PSScriptRoot
$out = & $g --headless --path $p --import 2>&1
if ($Sim) { $out += & $g --headless --path $p res://tests/sim.tscn 2>&1 }
$out | ForEach-Object { "$_" } |
  Where-Object { $_ -match "ERROR|Parse|at: |SIM|UI smoke|lost|ok\(|STALE|BAD|WARNING" -and $_ -notmatch "first_scan|update_scripts" } |
  Select-Object -First 80
