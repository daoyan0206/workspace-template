<#
.SYNOPSIS
  从 workspace-template 初始化一个新项目工作区。

.DESCRIPTION
  1. 复制模板到目标路径(排除 init-project.ps1 / TEMPLATE-README.md 等模板基础设施)
  2. 把 *.template 文件重命名为去掉 .template 后缀
  3. 替换占位符 <PROJECT_NAME> / <INIT_TIMESTAMP>
  4. 输出"下一步"引导(由用户手工跑 setup-skill-links.ps1)

.PARAMETER Name
  新项目名称。会替换模板内的 <PROJECT_NAME> 占位符。

.PARAMETER Path
  目标路径,例如 F:\my-new-project 或 /Users/me/my-new-project。

.PARAMETER Force
  目标路径已存在时是否强制覆盖(合并写入,不删旧文件)。

.EXAMPLE
  .\init-project.ps1 -Name "my-new-project" -Path "F:\my-new-project"

.EXAMPLE
  pwsh ./init-project.ps1 -Name "my-new-project" -Path "$HOME/my-new-project"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Name,

  [Parameter(Mandatory = $true)]
  [string]$Path,

  [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ---- PowerShell 版本检查 ----
if ($PSVersionTable.PSVersion.Major -lt 5) {
  Write-Error "需要 PowerShell >= 5.1,当前为 $($PSVersionTable.PSVersion). 请升级到 Windows PowerShell 5.1 或安装 PowerShell 7+: https://github.com/PowerShell/PowerShell/releases"
  exit 1
}

# ---- 平台检测(用于末尾引导文案) ----
if ($null -eq $IsWindows -and $null -eq $IsMacOS -and $null -eq $IsLinux) {
  $script:IsWin = $true
} else {
  $script:IsWin = [bool]$IsWindows
}

$templateRoot = $PSScriptRoot
if (-not (Test-Path "$templateRoot/.cursor/rules/ORCHESTRATOR.md")) {
  Write-Error "当前脚本所在目录不像 workspace-template 根 (找不到 .cursor/rules/ORCHESTRATOR.md): $templateRoot"
  exit 1
}

# ---- 目标路径冲突检测 ----
if (Test-Path $Path) {
  if (-not $Force) {
    Write-Error "目标路径已存在:$Path  (使用 -Force 强制合并写入,或换个路径)"
    exit 1
  }
  Write-Host "[!] 目标路径已存在,以 Force 模式合并写入:$Path" -ForegroundColor Yellow
} else {
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

Write-Host "[1/4] 复制模板文件到 $Path" -ForegroundColor Cyan

# 排除模板基础设施(不进新项目)
$exclude = @(
  'init-project.ps1',
  'TEMPLATE-README.md',
  'BOOTSTRAP.md',
  'PUBLISH.md'
)
# 同时排除 .git/ 目录(模板仓自身的 git 数据)
Get-ChildItem -Path $templateRoot -Recurse -Force | Where-Object {
  $_.Name -notin $exclude -and
  $_.FullName -notmatch '[\\/]\.git[\\/]' -and
  $_.FullName -notmatch '[\\/]\.git$'
} | ForEach-Object {
  $rel = $_.FullName.Substring($templateRoot.Length).TrimStart('\','/')
  $dest = Join-Path $Path $rel
  if ($_.PSIsContainer) {
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
  } else {
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
    Copy-Item $_.FullName -Destination $dest -Force
  }
}

Write-Host "[2/4] 处理 *.template 占位文件 (去后缀)" -ForegroundColor Cyan

Get-ChildItem -Path $Path -Recurse -Force -File -Filter '*.template' | ForEach-Object {
  $newName = $_.FullName -replace '\.template$', ''
  if (Test-Path $newName) {
    Write-Host "  跳过(目标已存在): $($_.FullName) -> $newName" -ForegroundColor DarkYellow
    Remove-Item $_.FullName -Force
  } else {
    Rename-Item $_.FullName -NewName ([System.IO.Path]::GetFileName($newName))
    Write-Host "  $($_.Name) -> $([System.IO.Path]::GetFileName($newName))" -ForegroundColor DarkGray
  }
}

Write-Host "[3/4] 替换占位符 <PROJECT_NAME> / <INIT_TIMESTAMP>" -ForegroundColor Cyan

$iso = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
# 需要做占位符替换的文本类型
$textExts = @('.md','.json','.html','.yml','.yaml','.txt','.css','.js','.ts')
Get-ChildItem -Path $Path -Recurse -Force -File | Where-Object {
  $textExts -contains $_.Extension.ToLower()
} | ForEach-Object {
  try {
    $content = Get-Content $_.FullName -Raw -ErrorAction Stop
  } catch { return }
  if ($null -eq $content) { return }
  $orig = $content
  $content = $content -replace '<PROJECT_NAME>', $Name
  $content = $content -replace '<INIT_TIMESTAMP>', $iso
  if ($content -ne $orig) {
    Set-Content -Path $_.FullName -Value $content -NoNewline -Encoding UTF8
    Write-Host "  占位符已替换:$($_.FullName.Substring($Path.Length).TrimStart('\','/'))" -ForegroundColor DarkGray
  }
}

Write-Host "[4/4] 初始化完成" -ForegroundColor Green

# ---- 末尾引导(P1-b) ----
$setupCmd = if ($script:IsWin) {
  "powershell -NoProfile -ExecutionPolicy Bypass -File .cursor\setup-skill-links.ps1"
} else {
  "pwsh ./.cursor/setup-skill-links.ps1"
}
$cdPath = $Path
$boardPath = if ($script:IsWin) { "$Path\shared\board.html" } else { "$Path/shared/board.html" }
$projectMdPath = if ($script:IsWin) { "$Path\shared\PROJECT.md" } else { "$Path/shared/PROJECT.md" }
$inputsPath = if ($script:IsWin) { "$Path\shared\inputs\" } else { "$Path/shared/inputs/" }

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  ✅ 项目已初始化:$Path" -ForegroundColor Green
Write-Host "     项目名:$Name" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步(必做):" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1) cd $cdPath" -ForegroundColor White
Write-Host ""
Write-Host "  2) $setupCmd" -ForegroundColor White
Write-Host "     (此步会创建本机的 skill 软链;首次跑前确保已按 PORTABILITY.md §2 装好全局 skills)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3) 用 Cursor 打开 $cdPath" -ForegroundColor White
Write-Host ""
Write-Host "  4) 填写 $projectMdPath 的项目背景占位" -ForegroundColor White
Write-Host "     把原料文档/截图放入 $inputsPath" -ForegroundColor White
Write-Host ""
Write-Host "  5) 双击 $boardPath 查看需求看板(目前为空,等 prd-planner 派单后更新)" -ForegroundColor White
Write-Host ""
