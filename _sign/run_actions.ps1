# 拿 GitHub Actions 里跑出来的 ipa
#
#   powershell -ExecutionPolicy Bypass -File run_actions.ps1 -Repo 用户名/仓库名
#
# 流程：查最近一次 Build IPA 运行 -> 等它结束 -> 下载 artifact(HTML-ipa) -> 解压到 _sign\ipa
# 需要仓库是 public，或者提前跑一次 `gh auth login`（脚本会自动优先用 gh）。
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Workflow = 'build-ipa.yml',
  [string]$Artifact = 'HTML-ipa',
  [int]$TimeoutMinutes = 15
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root 'ipa'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$headers = @{ 'User-Agent' = 'dsh-run-actions'; 'Accept' = 'application/vnd.github+json' }

function Say($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "   [!] $m" -ForegroundColor Yellow }

$gh = Get-Command gh -ErrorAction SilentlyContinue
$ghReady = $false
if ($gh) {
  $status = (& gh auth status 2>&1 | Out-String)
  if ($status -match 'Logged in') { $ghReady = $true }
}

Say "仓库：$Repo"
if ($ghReady) {
  Say '用 gh 拉取最近一次运行'
  & gh run list --repo $Repo --workflow $Workflow --limit 1
  & gh run watch --repo $Repo --exit-status
  Say '下载 artifact'
  & gh run download --repo $Repo --name $Artifact --dir $outDir
} else {
  Say '没找到已登录的 gh，改用公开 API（仓库需为 public）'
  $runs = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/workflows/$Workflow/runs?per_page=1" -Headers $headers -TimeoutSec 60
  if (-not $runs.workflow_runs -or $runs.workflow_runs.Count -eq 0) {
    throw "没查到 $Workflow 的运行记录：先在网页 Actions -> Build IPA -> Run workflow 跑一次"
  }
  $run = $runs.workflow_runs[0]
  Say "运行 #$($run.run_number) 状态=$($run.status) 分支=$($run.head_branch)"

  $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
  while ($run.status -ne 'completed') {
    if ((Get-Date) -gt $deadline) { throw "等待超时（$TimeoutMinutes 分钟），去 $($run.html_url) 看看日志" }
    Start-Sleep -Seconds 15
    $run = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/runs/$($run.id)" -Headers $headers -TimeoutSec 60
    Write-Host ("    状态 {0} 已运行 {1:N1} 分钟" -f $run.status, (((Get-Date) - [datetime]$run.run_started_at).TotalMinutes))
  }
  if ($run.conclusion -ne 'success') { throw "这次运行结论是 $($run.conclusion)：$($run.html_url)" }
  Say '运行成功，开始下载 artifact'

  $arts = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/runs/$($run.id)/artifacts" -Headers $headers -TimeoutSec 60
  $art = $arts.artifacts | Where-Object { $_.name -eq $Artifact } | Select-Object -First 1
  if (-not $art) { throw "这次运行里没有名为 $Artifact 的 artifact" }

  $zip = Join-Path $outDir ($Artifact + '.zip')
  Invoke-WebRequest -Uri $art.archive_download_url -Headers $headers -OutFile $zip -TimeoutSec 600
  Expand-Archive -Path $zip -DestinationPath $outDir -Force
  Remove-Item $zip -Force
}

$ipa = Get-ChildItem $outDir -Filter *.ipa -Recurse | Select-Object -First 1
if ($ipa) {
  Write-Host ""
  Write-Host "ipa 就绪：$($ipa.FullName)（$([math]::Round($ipa.Length/1MB,2)) MB）" -ForegroundColor Green
  Write-Host "接下来：打开 Sideloadly -> 插上 iPhone -> 拖入这个 ipa -> 填自己的 Apple ID -> Start"
} else {
  Warn "没在 $outDir 里找到 ipa，检查 artifact 内容"
}
