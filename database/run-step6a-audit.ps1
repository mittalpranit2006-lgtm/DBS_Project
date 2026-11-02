$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
& 'C:\oracle_sql_lite\dbhomeXE\bin\sqlplus.exe' /nolog '@database/step6a_verify.sql'
Write-Host "SQL*Plus exited with code $LASTEXITCODE. Audit log: evidence/step6a-final-oracle-audit.log"
