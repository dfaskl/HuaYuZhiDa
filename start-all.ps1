# ============================================================
#  化语智答 一键启动脚本
#  用法: 右键 -> 用 PowerShell 运行，或在终端执行:
#    powershell -ExecutionPolicy Bypass -File start-all.ps1
# ============================================================

$ErrorActionPreference = "SilentlyContinue"
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------- 配置区（按需修改） ----------
$JAVA_HOME_23  = "C:\Program Files\Java\jdk-23"
$JAVA_HOME_ES  = "D:\tools\elasticsearch-8.10.0\jdk"

$MINIO_EXE     = "D:\tools\minio.exe"
$MINIO_DATA    = "D:\tools\minio-data"
$MINIO_PORT    = 19000

$ES_HOME       = "D:\tools\elasticsearch-8.10.0"
$ES_PORT       = 9200

$KAFKA_HOME    = "D:\tools\kafka_2.13-3.6.0"
$KAFKA_PORT    = 9092

$REDIS_EXE     = "D:\tools\redis\redis-server.exe"
$REDIS_PORT    = 6379

$BACKEND_PORT  = 8081
$FRONTEND_PORT = 9527
# -----------------------------------------

function Test-Port($port) {
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    return $null -ne $conn
}

function Wait-Port($port, $name, $timeout = 60) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeout) {
        if (Test-Port $port) {
            Write-Host "  [OK] $name 就绪 (port $port)" -ForegroundColor Green
            return $true
        }
        Start-Sleep -Seconds 2
    }
    Write-Host "  [FAIL] $name 启动超时" -ForegroundColor Red
    return $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  化语智答 - 一键启动" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Redis ----
Write-Host "[1/6] Redis ..." -ForegroundColor Yellow
if (Test-Port $REDIS_PORT) {
    Write-Host "  [OK] Redis 已在运行" -ForegroundColor Green
} else {
    Start-Process -FilePath $REDIS_EXE -WindowStyle Hidden
    Wait-Port $REDIS_PORT "Redis" 10
}

# ---- 2. MinIO ----
Write-Host "[2/6] MinIO ..." -ForegroundColor Yellow
if (Test-Port $MINIO_PORT) {
    Write-Host "  [OK] MinIO 已在运行" -ForegroundColor Green
} else {
    $env:MINIO_ROOT_USER = "admin"
    $env:MINIO_ROOT_PASSWORD = "HuaYu2025"
    Start-Process -FilePath $MINIO_EXE -ArgumentList "server", $MINIO_DATA, "--console-address", ":19001" -WindowStyle Hidden
    Wait-Port $MINIO_PORT "MinIO" 15
}

# ---- 3. Elasticsearch ----
Write-Host "[3/6] Elasticsearch ..." -ForegroundColor Yellow
if (Test-Port $ES_PORT) {
    Write-Host "  [OK] Elasticsearch 已在运行" -ForegroundColor Green
} else {
    $env:JAVA_HOME = $JAVA_HOME_ES
    $env:ES_JAVA_OPTS = "-Xms512m -Xmx512m"
    Start-Process -FilePath "$ES_HOME\bin\elasticsearch.bat" -WindowStyle Hidden
    Wait-Port $ES_PORT "Elasticsearch" 60
}

# ---- 4. Kafka ----
Write-Host "[4/6] Kafka ..." -ForegroundColor Yellow
if (Test-Port $KAFKA_PORT) {
    Write-Host "  [OK] Kafka 已在运行" -ForegroundColor Green
} else {
    $env:JAVA_HOME = $JAVA_HOME_23
    Start-Process -FilePath "$KAFKA_HOME\bin\windows\kafka-server-start.bat" -ArgumentList "$KAFKA_HOME\config\kraft\server.properties" -WindowStyle Hidden
    Wait-Port $KAFKA_PORT "Kafka" 30
}

# ---- 5. 后端 ----
Write-Host "[5/6] 后端 (Spring Boot) ..." -ForegroundColor Yellow
if (Test-Port $BACKEND_PORT) {
    Write-Host "  [OK] 后端已在运行" -ForegroundColor Green
} else {
    $env:JAVA_HOME = $JAVA_HOME_23
    Set-Location $ROOT
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "cd /d $ROOT && set JAVA_HOME=$JAVA_HOME_23 && D:\tools\apache-maven-3.9.9\bin\mvnw.cmd spring-boot:run -Dmaven.test.skip=true" -WindowStyle Minimized
    Write-Host "  等待后端启动 (可能需要 30-60 秒) ..."
    Wait-Port $BACKEND_PORT "后端" 120
}

# ---- 6. 前端 ----
Write-Host "[6/6] 前端 (Vite Dev Server) ..." -ForegroundColor Yellow
if (Test-Port $FRONTEND_PORT) {
    Write-Host "  [OK] 前端已在运行" -ForegroundColor Green
} else {
    Set-Location "$ROOT\frontend"
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "cd /d $ROOT\frontend && pnpm dev" -WindowStyle Minimized
    Wait-Port $FRONTEND_PORT "前端" 30
}

# ---- 完成 ----
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  全部启动完成！" -ForegroundColor Cyan
Write-Host "  前端: http://localhost:$FRONTEND_PORT/#/login" -ForegroundColor Cyan
Write-Host "  后端: http://localhost:$BACKEND_PORT" -ForegroundColor Cyan
Write-Host "  MinIO Console: http://localhost:19001" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "按任意键退出 ..." -ForegroundColor DarkGray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
