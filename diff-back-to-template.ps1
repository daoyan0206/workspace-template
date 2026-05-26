<#
.SYNOPSIS
    项目 → 模板 反向同步(回流)脚本。

.DESCRIPTION
    逐项对比项目侧与模板侧的"框架资产"文件,忽略占位符差异,交互式让用户挑选
    哪些改动推回模板。被选中的改动写入模板仓新分支 backflow/<project>-<ts>,
    脚本不真正 push,留给用户人工 review + PR。

    单一事实源:TRACKED_PATHS.txt(与 .cursor/BACKFLOW.md 共享)。

    用户拍板方案:混合 D —— 平时 diff 逐项推,批量走 git subtree。
    本脚本负责"diff 逐项推"那一档。

.PARAMETER ProjectPath
    项目仓根目录(必填,例:F:\minicreata-v3)。

.PARAMETER TemplatePath
    模板仓根目录(默认为脚本所在目录)。

.PARAMETER DryRun
    只看 diff,不做任何写操作(不建分支、不 commit)。

.PARAMETER Interactive
    交互式逐项问(默认 $true)。设 $false 时会跳过所有写操作,等同 -DryRun。

.EXAMPLE
    .\diff-back-to-template.ps1 -ProjectPath F:\minicreata-v3 -DryRun

.EXAMPLE
    .\diff-back-to-template.ps1 -ProjectPath F:\minicreata-v3

.NOTES
    跨平台:Windows PowerShell 5+ / PowerShell 7+(macOS/Linux)兼容。
    GitHub readiness 维护的文件(.gitignore / setup-skill-links.ps1 等)只读不写,
    脚本会显眼提示用户去 readiness PR 合并。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$TemplatePath = $PSScriptRoot,

    [switch]$DryRun,

    [bool]$Interactive = $true
)

# ============================================================
# 全局常量
# ============================================================

$Script:READINESS_OWNED = @(
    '.gitignore',
    '.gitattributes',
    '.cursor/setup-skill-links.ps1',
    'init-project.ps1',
    'TEMPLATE-README.md'
)

# 占位符反向映射(项目侧值 → 模板侧占位符)
# 注意:这些值在 init 时从用户输入填入,脚本无法静态知道项目实际填了什么;
# 因此我们在比对时,把项目侧"看起来像占位符位置"的内容也做模糊处理。
# 当前实现保守:仅对已知会出现在 .template 文件头部的几类做替换。
$Script:PLACEHOLDER_PATTERNS = @(
    @{ Project = '<PROJECT_NAME>';     Template = '<PROJECT_NAME>' }
    @{ Project = '<INIT_TIMESTAMP>';   Template = '<INIT_TIMESTAMP>' }
    @{ Project = '<PROJECT_OWNER>';    Template = '<PROJECT_OWNER>' }
)

# ============================================================
# 工具函数
# ============================================================

function Write-Section($Text) {
    Write-Host ''
    Write-Host ('=' * 72) -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ('=' * 72) -ForegroundColor Cyan
}

function Write-Info($Text)    { Write-Host "[INFO] $Text" -ForegroundColor Gray }
function Write-Ok($Text)      { Write-Host "[ OK ] $Text" -ForegroundColor Green }
function Write-Warn2($Text)   { Write-Host "[WARN] $Text" -ForegroundColor Yellow }
function Write-Err2($Text)    { Write-Host "[ERR ] $Text" -ForegroundColor Red }

function Get-PathSeparator {
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) { return '\' } else { return '/' }
}

function Join-PathSafe([string]$Base, [string]$Relative) {
    # 把 TRACKED_PATHS 里的 / 形式路径,在 Windows 下转为 \
    $sep = Get-PathSeparator
    $normalized = $Relative -replace '[\\/]+', [Regex]::Escape($sep)
    # 上面那行用 escape 会过度转义,用更直接的写法:
    if ($sep -eq '\') { $normalized = $Relative -replace '/', '\' } else { $normalized = $Relative -replace '\\', '/' }
    return (Join-Path -Path $Base -ChildPath $normalized)
}

function Read-TrackedPaths([string]$TemplateRoot) {
    $file = Join-Path $TemplateRoot 'TRACKED_PATHS.txt'
    if (-not (Test-Path -LiteralPath $file)) {
        throw "TRACKED_PATHS.txt 不存在:$file"
    }
    $entries = @()
    foreach ($raw in Get-Content -LiteralPath $file -Encoding UTF8) {
        $line = $raw.Trim()
        if (-not $line) { continue }
        if ($line.StartsWith('#')) { continue }
        $parts = $line -split '\|', 2
        $proj = $parts[0].Trim()
        $tmpl = if ($parts.Count -eq 2) { $parts[1].Trim() } else { $proj }
        $entries += [pscustomobject]@{ ProjectRel = $proj; TemplateRel = $tmpl }
    }
    return $entries
}

function Test-ReadinessOwned([string]$ProjectRel) {
    $norm = $ProjectRel -replace '\\', '/'
    return ($Script:READINESS_OWNED -contains $norm)
}

function Normalize-ContentForCompare([string]$Content) {
    if ($null -eq $Content) { return '' }
    $out = $Content
    foreach ($p in $Script:PLACEHOLDER_PATTERNS) {
        # 这里两侧本就是占位符同名,留给未来真有差异时扩展。
        # 真实场景中,init-project.ps1 会把 <PROJECT_NAME> 替换成具体项目名。
        # 我们没法静态反推出项目名,所以只保证"已是占位符的位置"不会因换行差异误报。
    }
    # 统一换行
    $out = $out -replace "`r`n", "`n"
    # 统一行尾空白
    $out = ($out -split "`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"
    return $out
}

function Reverse-PlaceholderForWrite([string]$Content, [string]$ProjectName, [string]$InitTimestamp, [string]$ProjectOwner) {
    # 把项目侧的具体值还原回占位符,再写入模板。
    if ($null -eq $Content) { return '' }
    $out = $Content
    if ($ProjectName)    { $out = $out -replace [Regex]::Escape($ProjectName),    '<PROJECT_NAME>' }
    if ($InitTimestamp)  { $out = $out -replace [Regex]::Escape($InitTimestamp),  '<INIT_TIMESTAMP>' }
    if ($ProjectOwner)   { $out = $out -replace [Regex]::Escape($ProjectOwner),   '<PROJECT_OWNER>' }
    return $out
}

function Try-ReadProjectMeta([string]$ProjectRoot) {
    # 从项目侧 shared/PROJECT.md 或根目录文件提取项目名/时间戳/负责人(尽力而为)。
    $meta = [pscustomobject]@{ ProjectName = $null; InitTimestamp = $null; ProjectOwner = $null }
    $candidates = @(
        (Join-PathSafe $ProjectRoot 'shared/PROJECT.md'),
        (Join-PathSafe $ProjectRoot '.cursor/rules/PROJECT.md')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) {
            $txt = Get-Content -LiteralPath $c -Raw -Encoding UTF8
            if (-not $meta.ProjectName)   { if ($txt -match '(?im)^\s*[-*]\s*项目名[::\s]*(.+?)\s*$') { $meta.ProjectName = $Matches[1].Trim() } }
            if (-not $meta.ProjectName)   { if ($txt -match '(?im)^#\s+(.+?)\s*$') { $meta.ProjectName = $Matches[1].Trim() } }
            if (-not $meta.InitTimestamp) { if ($txt -match '(?im)^\s*[-*]\s*初始化[::\s]*(.+?)\s*$') { $meta.InitTimestamp = $Matches[1].Trim() } }
            if (-not $meta.ProjectOwner)  { if ($txt -match '(?im)^\s*[-*]\s*(负责人|owner)[::\s]*(.+?)\s*$') { $meta.ProjectOwner = $Matches[2].Trim() } }
        }
    }
    # 兜底:用项目根目录名当 ProjectName
    if (-not $meta.ProjectName) { $meta.ProjectName = Split-Path -Leaf $ProjectRoot }
    return $meta
}

function Invoke-GitDiff([string]$LeftFile, [string]$RightFile, [string]$LeftLabel, [string]$RightLabel) {
    # 用 git diff --no-index 输出带色 diff。LeftFile / RightFile 必须真实存在(可为空文件)。
    $args = @('--no-pager', 'diff', '--no-index', '--color=always')
    if ($LeftLabel)  { $args += @('--src-prefix', "$LeftLabel/") }
    if ($RightLabel) { $args += @('--dst-prefix', "$RightLabel/") }
    $args += @('--', $LeftFile, $RightFile)
    try {
        & git @args 2>$null
    } catch {
        Write-Warn2 "git diff 调用失败:$($_.Exception.Message)"
    }
}

function Get-NormalizedFileBytes([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return (Normalize-ContentForCompare $raw)
}

function Ensure-GitRepo([string]$Root) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
        throw @"
模板仓 $Root 不是 git 仓库。请先初始化:
    cd $Root
    git init
    git add -A
    git commit -m "chore: bootstrap workspace-template"
然后再跑本脚本。
"@
    }
}

# ============================================================
# 主流程
# ============================================================

function Main {
    Write-Section "项目 → 模板 反向同步(回流)"

    if (-not (Test-Path -LiteralPath $ProjectPath)) {
        Write-Err2 "ProjectPath 不存在:$ProjectPath"; exit 2
    }
    if (-not (Test-Path -LiteralPath $TemplatePath)) {
        Write-Err2 "TemplatePath 不存在:$TemplatePath"; exit 2
    }

    $effectiveDryRun = $DryRun -or (-not $Interactive)

    Write-Info "项目仓     : $ProjectPath"
    Write-Info "模板仓     : $TemplatePath"
    Write-Info "DryRun     : $effectiveDryRun"
    Write-Info "Interactive: $Interactive"

    if (-not $effectiveDryRun) {
        try { Ensure-GitRepo -Root $TemplatePath } catch { Write-Err2 $_; exit 3 }
    }

    $entries = Read-TrackedPaths -TemplateRoot $TemplatePath
    Write-Info "TRACKED_PATHS 共 $($entries.Count) 项"

    $meta = Try-ReadProjectMeta -ProjectRoot $ProjectPath
    Write-Info "项目元信息 : Name=$($meta.ProjectName) / Ts=$($meta.InitTimestamp) / Owner=$($meta.ProjectOwner)"

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("backflow-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $picked    = New-Object System.Collections.Generic.List[object]
    $aborted   = $false

    foreach ($e in $entries) {
        $projAbs = Join-PathSafe $ProjectPath  $e.ProjectRel
        $tmplAbs = Join-PathSafe $TemplatePath $e.TemplateRel

        Write-Section "$($e.ProjectRel)  →  $($e.TemplateRel)"

        if (Test-ReadinessOwned $e.ProjectRel) {
            Write-Warn2 "$($e.ProjectRel) 由 GitHub readiness 流程维护,本脚本不会推它。"
            Write-Warn2 "如确有改动,请在 readiness PR 上合并。"
            continue
        }

        $projExists = Test-Path -LiteralPath $projAbs
        $tmplExists = Test-Path -LiteralPath $tmplAbs

        if (-not $projExists -and -not $tmplExists) {
            Write-Warn2 "两侧都没有此文件,跳过。"; continue
        }
        if (-not $projExists) {
            Write-Warn2 "项目侧不存在($projAbs),跳过(模板有 = 项目还没用到这个资产)。"; continue
        }

        # 占位符规范化后比内容
        $projNorm = Get-NormalizedFileBytes $projAbs
        $tmplNorm = if ($tmplExists) { Get-NormalizedFileBytes $tmplAbs } else { '' }

        # 把项目侧具体值还原成占位符,再做最终比对,避免假阳性。
        $projForCompare = Reverse-PlaceholderForWrite -Content $projNorm `
                            -ProjectName $meta.ProjectName `
                            -InitTimestamp $meta.InitTimestamp `
                            -ProjectOwner $meta.ProjectOwner

        if ($projForCompare -eq $tmplNorm) {
            Write-Ok "无框架级差异。"; continue
        }

        # 真有差异 → 写到临时文件,跑 git diff 着色
        $leftTmp  = Join-Path $tempDir ((Split-Path -Leaf $e.TemplateRel) + '.tmpl')
        $rightTmp = Join-Path $tempDir ((Split-Path -Leaf $e.TemplateRel) + '.proj')
        if (-not $tmplExists) {
            Set-Content -LiteralPath $leftTmp -Value '' -Encoding UTF8
        } else {
            Set-Content -LiteralPath $leftTmp -Value $tmplNorm -Encoding UTF8
        }
        Set-Content -LiteralPath $rightTmp -Value $projForCompare -Encoding UTF8

        Invoke-GitDiff -LeftFile $leftTmp -RightFile $rightTmp `
            -LeftLabel "template" -RightLabel "project"

        if ($effectiveDryRun) {
            Write-Info "[DryRun] 仅展示 diff,不询问。"
            continue
        }

        if (-not $Interactive) {
            Write-Info "[NonInteractive] 跳过(未启用交互)。"
            continue
        }

        while ($true) {
            Write-Host ''
            $ans = Read-Host "推回模板? [P]ush / [S]kip / [A]bort"
            switch -Regex ($ans.Trim().ToLower()) {
                '^p(ush)?$' {
                    $picked.Add([pscustomobject]@{
                        Entry          = $e
                        ProjectAbs     = $projAbs
                        TemplateAbs    = $tmplAbs
                        WriteContent   = $projForCompare
                    }) | Out-Null
                    Write-Ok "已加入待推清单。"
                    break
                }
                '^s(kip)?$' { Write-Info "跳过。"; break }
                '^a(bort)?$' { $aborted = $true; break }
                default { Write-Warn2 "无效输入,请输 P/S/A。"; continue }
            }
            break
        }
        if ($aborted) { break }
    }

    if ($aborted) {
        Write-Warn2 "用户中止。已选中的 $($picked.Count) 项不会被写入。"
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
        exit 1
    }

    if ($picked.Count -eq 0) {
        Write-Info "没有要推回的改动。结束。"
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
        exit 0
    }

    if ($effectiveDryRun) {
        Write-Info "[DryRun] 不写入。结束。"
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
        exit 0
    }

    # ============================================================
    # 写入模板分支
    # ============================================================
    $ts        = Get-Date -Format 'yyyyMMddHHmmss'
    $safeName  = ($meta.ProjectName -replace '[^A-Za-z0-9._-]', '-')
    $branch    = "backflow/$safeName-$ts"

    Write-Section "在模板仓建分支 $branch 并落盘"

    Push-Location -LiteralPath $TemplatePath
    try {
        # 检查工作区是否干净
        $statusOut = & git status --porcelain
        if ($LASTEXITCODE -ne 0) { throw "git status 失败" }
        if ($statusOut) {
            Write-Warn2 "模板仓工作区非干净,先 stash:"
            Write-Host $statusOut
            & git stash push -u -m "backflow-auto-stash-$ts" | Out-Null
        }

        & git checkout -b $branch 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "无法创建分支 $branch" }

        foreach ($p in $picked) {
            $targetDir = Split-Path -Parent $p.TemplateAbs
            if (-not (Test-Path -LiteralPath $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Set-Content -LiteralPath $p.TemplateAbs -Value $p.WriteContent -Encoding UTF8 -NoNewline:$false
            & git add -- $p.TemplateAbs | Out-Null
            Write-Ok "落盘: $($p.Entry.TemplateRel)"
        }

        $msgFile = Join-Path $tempDir 'commit-msg.txt'
        $bodyLines = @(
            "backflow($safeName): 框架资产回流 ($($picked.Count) 项)",
            '',
            "来源项目: $ProjectPath",
            "回流时间: $ts",
            '',
            '文件清单:'
        )
        foreach ($p in $picked) { $bodyLines += "  - $($p.Entry.TemplateRel)" }
        $bodyLines += @(
            '',
            '请人工 review:',
            '  1. 占位符还原是否正确(<PROJECT_NAME> / <INIT_TIMESTAMP> 等)',
            '  2. 是否引入业务字段(不应该)',
            '  3. 是否破坏 init-project.ps1 兼容性'
        )
        Set-Content -LiteralPath $msgFile -Value ($bodyLines -join "`n") -Encoding UTF8

        & git commit -F $msgFile | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }

        Write-Section "完成"
        Write-Ok "已在模板仓提交到分支: $branch"
        Write-Info "下一步(人工执行):"
        Write-Host "    cd $TemplatePath" -ForegroundColor Yellow
        Write-Host "    git push origin $branch" -ForegroundColor Yellow
        Write-Host "    # 然后到 GitHub 提 PR -> main" -ForegroundColor Yellow

    } catch {
        Write-Err2 "回流失败:$($_.Exception.Message)"
        Write-Warn2 "请手工检查模板仓状态;如刚 stash 过,可 git stash pop 还原。"
        Pop-Location
        Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
        exit 4
    }
    Pop-Location

    Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
}

Main
