# ============================================================
#  化语智答 一键停止脚本
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "正在停止所有服务 ..." -ForegroundColor Yellow

# 停止后端 (Maven / Java 进程)
Write-Host "  停止后端 ..." -ForegroundColor DarkGray
Get-WmiObject Win32_Process -Filter "Name='java.exe'" | Where-Object {
    $_.CommandLine -like "*smartqa*" -or $_.CommandLine -like "*spring-boot*" -or $_.CommandLine -like "*maven*"
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

# 停止 Kafka
Write-Host "  停止 Kafka ..." -ForegroundColor DarkGray
Get-WmiObject Win32_Process -Filter "Name='java.exe'" | Where-Object {
    $_.CommandLine -like "*kafka*"
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

# 停止 Elasticsearch
Write-Host "  停止 Elasticsearch ..." -ForegroundColor DarkGray
Get-Process elasticsearch -ErrorAction SilentlyContinue | Stop-Process -Force
Get-WmiObject Win32_Process -Filter "Name='java.exe'" | Where-Object {
    $_.CommandLine -like "*elasticsearch*"
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

# 停止 MinIO
Write-Host "  停止 MinIO ..." -ForegroundColor DarkGray
Get-Process minio -ErrorAction SilentlyContinue | Stop-Process -Force

# Redis 不停止（可能被其他项目共用）
Write-Host "  Redis 保留运行（共享服务）" -ForegroundColor DarkGray

Write-Host ""
Write-Host "全部停止完成（Redis 保留）" -ForegroundColor Green
Start-Sleep -Seconds 2
