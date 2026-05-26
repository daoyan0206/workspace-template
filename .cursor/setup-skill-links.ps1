<#
.SYNOPSIS
  在当前项目 .cursor\skills\ 下建立指向全局 skill 仓的软链(Windows = junction,Unix = symlink)。

.DESCRIPTION
  - 跨平台:Windows 用 New-Item -ItemType Junction;macOS/Linux 用 New-Item -ItemType SymbolicLink(需 PowerShell 7+)。
  - 幂等:已存在的链接跳过,不破坏。
  - 路径自适配:Windows = $env:USERPROFILE\.cursor\skills;Unix = $HOME/.cursor/skills。
  - 全局 skills 目录不存在时给出明确指引,而非默默失败。

.NOTES
  首次使用前请确保已按 PORTABILITY.md §2.2 准备好全局 skills 目录。
  全局目录约定:
    Windows : C:\Users\<you>\.cursor\skills
              C:\Users\<you>\.agents\skills           (可选,旧 agent skills)
              C:\Users\<you>\.claude\skills           (可选,claude skills)
              C:\Users\<you>\.cursor\skills-cursor    (可选,cursor 内置)
              C:\Users\<you>\.cursor\plugins\cache\...(可选,figma/notion 插件 skills)
    Unix    : $HOME/.cursor/skills
              $HOME/.agents/skills
              $HOME/.claude/skills
              ...
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ---- 平台检测(PS 5.1 没有 $IsWindows,需要兜底) ----
if ($null -eq $IsWindows -and $null -eq $IsMacOS -and $null -eq $IsLinux) {
  # Windows PowerShell 5.1
  $script:IsWin = $true
  $script:IsMac = $false
  $script:IsLin = $false
} else {
  $script:IsWin = [bool]$IsWindows
  $script:IsMac = [bool]$IsMacOS
  $script:IsLin = [bool]$IsLinux
}

# ---- 解析 HOME ----
if ($script:IsWin) {
  $homeDir = $env:USERPROFILE
} else {
  $homeDir = $env:HOME
  if (-not $homeDir) { $homeDir = [Environment]::GetFolderPath('UserProfile') }
}

# ---- 解析全局 skill 仓根 ----
$globalCursor   = Join-Path $homeDir '.cursor/skills'
$globalAgents   = Join-Path $homeDir '.agents/skills'
$globalClaude   = Join-Path $homeDir '.claude/skills'
$globalCursor2  = Join-Path $homeDir '.cursor/skills-cursor'
$globalFigmaCu  = Join-Path $homeDir '.cursor/plugins/cache/cursor-public/figma/a742f0a700a7772ff5ed85f7c9fc1dad5afa9fcc/skills'
$globalFigmaCl  = Join-Path $homeDir '.claude/plugins/cache/claude-plugins-official/figma/2.1.30/skills'

# ---- 项目本地 skill 目录(本脚本就在 .cursor 下;skills 是 .cursor 的兄弟目录) ----
$projectRoot = Split-Path -Parent $PSScriptRoot   # 项目根
$linkBase    = Join-Path $projectRoot '.cursor/skills'
New-Item -ItemType Directory -Force -Path $linkBase | Out-Null

# ---- 全局目录预检 ----
if (-not (Test-Path -LiteralPath $globalCursor)) {
  Write-Host ""
  Write-Host "[X] 全局 skills 目录不存在: $globalCursor" -ForegroundColor Red
  Write-Host ""
  Write-Host "请先按 PORTABILITY.md §2.2 准备全局 skill 仓:" -ForegroundColor Yellow
  if ($script:IsWin) {
    Write-Host "  New-Item -ItemType Directory -Force -Path `"$globalCursor`"" -ForegroundColor Yellow
  } else {
    Write-Host "  mkdir -p `"$globalCursor`"" -ForegroundColor Yellow
  }
  Write-Host "  # 然后把你的 skill 仓 clone / 装进该目录" -ForegroundColor Yellow
  Write-Host ""
  exit 1
}

# ---- skill 清单(name = 软链名;src = 全局路径) ----
$links = @(
  @{ name = 'brainstorming';                    src = (Join-Path $globalAgents 'brainstorming') },
  @{ name = 'find-skills';                      src = (Join-Path $globalAgents 'find-skills') },
  @{ name = 'prd';                              src = (Join-Path $globalAgents 'prd') },

  @{ name = 'change-verification';              src = (Join-Path $globalCursor 'change-verification') },
  @{ name = 'code-prd-sync';                    src = (Join-Path $globalCursor 'code-prd-sync') },
  @{ name = 'figma-to-prd';                     src = (Join-Path $globalCursor 'figma-to-prd') },
  @{ name = 'markdown-to-lark-doc';             src = (Join-Path $globalCursor 'markdown-to-lark-doc') },
  @{ name = 'prd-creator';                      src = (Join-Path $globalCursor 'prd-creator') },
  @{ name = 'skill-distill';                    src = (Join-Path $globalCursor 'skill-distill') },

  @{ name = 'ui-requirement-execution';         src = (Join-Path $globalClaude 'ui-requirement-execution') },

  @{ name = 'babysit';                          src = (Join-Path $globalCursor2 'babysit') },
  @{ name = 'canvas';                           src = (Join-Path $globalCursor2 'canvas') },
  @{ name = 'create-rule';                      src = (Join-Path $globalCursor2 'create-rule') },
  @{ name = 'create-hook';                      src = (Join-Path $globalCursor2 'create-hook') },
  @{ name = 'loop';                             src = (Join-Path $globalCursor2 'loop') },
  @{ name = 'sdk';                              src = (Join-Path $globalCursor2 'sdk') },
  @{ name = 'shell';                            src = (Join-Path $globalCursor2 'shell') },
  @{ name = 'split-to-prs';                     src = (Join-Path $globalCursor2 'split-to-prs') },

  @{ name = 'lark-shared';                      src = (Join-Path $globalAgents 'lark-shared') },
  @{ name = 'lark-doc';                         src = (Join-Path $globalAgents 'lark-doc') },
  @{ name = 'lark-wiki';                        src = (Join-Path $globalAgents 'lark-wiki') },
  @{ name = 'lark-sheets';                      src = (Join-Path $globalAgents 'lark-sheets') },
  @{ name = 'lark-base';                        src = (Join-Path $globalAgents 'lark-base') },
  @{ name = 'lark-markdown';                    src = (Join-Path $globalAgents 'lark-markdown') },

  @{ name = 'figma-use';                        src = (Join-Path $globalFigmaCu 'figma-use') },
  @{ name = 'figma-create-new-file';            src = (Join-Path $globalFigmaCu 'figma-create-new-file') },
  @{ name = 'figma-generate-design';            src = (Join-Path $globalFigmaCu 'figma-generate-design') },
  @{ name = 'figma-generate-library';           src = (Join-Path $globalFigmaCu 'figma-generate-library') },
  @{ name = 'figma-generate-diagram';           src = (Join-Path $globalFigmaCu 'figma-generate-diagram') },
  @{ name = 'figma-code-connect';               src = (Join-Path $globalFigmaCu 'figma-code-connect') },
  @{ name = 'figma-use-figjam';                 src = (Join-Path $globalFigmaCu 'figma-use-figjam') },
  @{ name = 'figma-use-slides';                 src = (Join-Path $globalFigmaCu 'figma-use-slides') },

  @{ name = 'figma-implement-design';           src = (Join-Path $globalFigmaCl 'figma-implement-design') },
  @{ name = 'figma-create-design-system-rules'; src = (Join-Path $globalFigmaCl 'figma-create-design-system-rules') }
)

# ---- 链接类型(Windows 用 Junction,Unix 用 SymbolicLink) ----
$linkType = if ($script:IsWin) { 'Junction' } else { 'SymbolicLink' }

Write-Host ""
Write-Host "[setup-skill-links] platform=$(if($script:IsWin){'Windows'}elseif($script:IsMac){'macOS'}else{'Linux'})  linkType=$linkType" -ForegroundColor Cyan
Write-Host "[setup-skill-links] linkBase = $linkBase" -ForegroundColor DarkGray
Write-Host ""

$ok = 0; $skip = 0; $miss = 0; $err = 0
foreach ($link in $links) {
  $dst = Join-Path $linkBase $link.name
  $src = $link.src

  if (-not (Test-Path -LiteralPath $src)) {
    Write-Host ("MISS  {0,-38}  <-  {1}" -f $link.name, $src) -ForegroundColor Yellow
    $miss++
    continue
  }

  if (Test-Path -LiteralPath $dst) {
    Write-Host ("SKIP  {0,-38}  (already exists)" -f $link.name)
    $skip++
    continue
  }

  try {
    New-Item -ItemType $linkType -Path $dst -Target $src -ErrorAction Stop | Out-Null
    Write-Host ("OK    {0,-38}  ->  {1}" -f $link.name, $src) -ForegroundColor Green
    $ok++
  } catch {
    Write-Host ("ERR   {0,-38}  :  {1}" -f $link.name, $_) -ForegroundColor Red
    if (-not $script:IsWin -and $_ -match 'denied|permission|privilege') {
      Write-Host "      提示: Unix 系下创建 symlink 通常需要在自己 home 内有写权限,且 PowerShell 7+" -ForegroundColor DarkYellow
    }
    if ($script:IsWin -and $_ -match 'privilege|administrator|denied') {
      Write-Host "      提示: Windows 下若 junction 仍失败,试以管理员身份运行,或开启开发者模式" -ForegroundColor DarkYellow
    }
    $err++
  }
}

Write-Host ""
Write-Host ("SUMMARY  ok={0}  skip={1}  miss={2}  err={3}  total={4}" -f $ok, $skip, $miss, $err, $links.Count) -ForegroundColor Cyan

if ($miss -gt 0) {
  Write-Host ""
  Write-Host "[!] 有 $miss 个 skill 在全局目录中缺失。可参考 PORTABILITY.md §2.2 把对应 skill 仓装进 ~/.cursor/skills/ 等目录后重跑本脚本。" -ForegroundColor Yellow
}
