# 跨机器可移植性指南 (PORTABILITY)

> 目标：把 `F:\minicreata-v3` 这套 5-subagent 编排框架（prd-planner / figma-to-prd / code-impl / data-analyst / visual-design）+ `workspace-template` 模板，无痛迁移到任何一台新电脑（Windows 为主，兼顾 macOS/Linux），让"新机器从零到能跑出第一个新项目"控制在 30 分钟内。
>
> 本文档**不重复**讲 `init-project.ps1` 的设计细节（由骨架 worker 维护），只聚焦"换机器"这一维度。

---

## 0. 一图看懂

```
[新机器]
   │
   ├─ ① 装基础环境（Cursor / Git / Node / PowerShell）
   │
   ├─ ② 装并配置全局工具（lark-cli 登录、全局 skills 目录、Cursor MCP）
   │       —— 每台机器只装一次，所有项目复用
   │
   ├─ ③ 拉模板仓（git clone F:\workspace-template）
   │
   ├─ ④ 跑 init-project.ps1 → 生成新项目骨架
   │
   ├─ ⑤ 在新项目里跑 setup-skill-links.ps1 → 建 skill 软链
   │
   └─ ⑥ Cursor 打开新项目 → 5 个 subagent 立即可用
```

---

## 1. 依赖清单（新机器要装什么）

| 工具 | 最小版本 | 用途 | 必需? |
|---|---|---|---|
| **Cursor IDE** | 最新稳定版 | 主 IDE，承载 subagent / skill / MCP | ✅ |
| **Git** | ≥ 2.30 | 拉取模板仓、版本管理 | ✅ |
| **Node.js + npm** | Node ≥ 18 LTS / npm ≥ 9 | 安装全局 `lark-cli` | ✅ |
| **PowerShell** | ≥ 5.1（Win10/11 自带）；macOS/Linux 装 PowerShell 7 | 跑 `*.ps1` 脚本 | ✅ |
| **Python** | ≥ 3.8 | 可选：`python -m http.server` 启动 `board.html`（如果用 fetch 方案）；当前 BOARD 是 embed 方案，**非必需** | ⛔ 可选 |

### 1.1 下载链接

- Cursor：<https://cursor.com/download>
- Git：<https://git-scm.com/downloads>
- Node.js（建议 LTS）：<https://nodejs.org/>
- PowerShell 7（跨平台）：<https://github.com/PowerShell/PowerShell/releases>
- Python：<https://www.python.org/downloads/>

### 1.2 安装命令对照

**Windows（推荐用 winget，Win10 1809+ 自带）：**

```powershell
winget install --id=Anysphere.Cursor       -e
winget install --id=Git.Git                -e
winget install --id=OpenJS.NodeJS.LTS      -e
winget install --id=Microsoft.PowerShell   -e   # 可选：装 PS7
winget install --id=Python.Python.3.12     -e   # 可选
```

**macOS（推荐用 Homebrew）：**

```bash
brew install --cask cursor
brew install git node powershell
brew install python@3.12   # 可选
```

**Linux（Ubuntu/Debian 示例）：**

```bash
sudo apt update
sudo apt install -y git nodejs npm python3
# Cursor: 去官网下 .AppImage 或 .deb
# PowerShell: 见 https://learn.microsoft.com/powershell/scripting/install/install-ubuntu
```

### 1.3 验证安装

```powershell
cursor --version       # 可能需要先在 Cursor 里启用 'cursor' 命令
git --version          # ≥ 2.30
node --version         # ≥ v18
npm --version          # ≥ 9
$PSVersionTable.PSVersion    # ≥ 5.1
```

macOS/Linux 把 `$PSVersionTable.PSVersion` 换成 `pwsh -c '$PSVersionTable.PSVersion'`。

---

## 2. 全局工具一次性配置

> 以下都是**每台机器只配一次**的东西，不要写进每个新项目。

### 2.1 lark-cli 全局安装与登录

`lark-cli` 是飞书生态的 CLI，多个 skill（lark-doc / lark-base / lark-sheets / lark-wiki / lark-im 等）都依赖它。

```powershell
# Windows / macOS / Linux 通用
npm i -g @larksuite/lark-cli

# 验证
lark-cli --version

# 登录（会打开浏览器扫码 / OAuth）
lark-cli auth login

# 检查身份
lark-cli auth whoami
```

> ⚠️ **token 绑机器**：lark-cli 的登录凭证存在 `~/.lark-cli/`（Windows 在 `C:\Users\<you>\.lark-cli\`）。换机器**必须重新 login**，不能直接拷贝（拷过去通常也能用，但官方不保证）。

### 2.2 Cursor 全局 skills 目录

本工作区的 `setup-skill-links.ps1` 会在新项目里建 **junction（Windows 软链）/ symlink（Unix 软链）** 指向全局 skills 目录。所以**全局 skills 目录必须先存在并装好**。

**默认路径：**

- Windows：`C:\Users\<you>\.cursor\skills\`
- macOS/Linux：`~/.cursor/skills/`

**第一次使用：**

```powershell
# Windows
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.cursor\skills" | Out-Null

# 然后从 Cursor Marketplace / 你自己的 skill 仓库装入需要的 skill
# 例如把 figma / lark / brainstorming / change-verification 等放进去
```

```bash
# macOS/Linux
mkdir -p ~/.cursor/skills
```

> 💡 **建议**：把你常用的全局 skill 集合也做成一个 git 仓（例如 `your-cursor-skills`），新机器一并 clone 进 `~/.cursor/skills/`。这样"全局 skill"也是可同步、可版本化的。

### 2.3 Cursor 全局 MCP 配置（`~/.cursor/mcp.json`）

Figma MCP / Notion MCP / Datadog MCP 等都是**全局生效**的，配置文件：

- Windows：`C:\Users\<you>\.cursor\mcp.json`
- macOS/Linux：`~/.cursor/mcp.json`

最小配置示例（只开 Figma）：

```json
{
  "mcpServers": {
    "figma": {
      "command": "npx",
      "args": ["-y", "figma-developer-mcp", "--stdio"],
      "env": {
        "FIGMA_API_KEY": "figd_xxxxxxxxxxxxxxxxxxxx"
      }
    }
  }
}
```

> 🔑 **Figma Token 怎么拿**：<https://www.figma.com/settings> → Personal access tokens → Create new token（勾选 File content + Dev resources read）。
>
> 🔒 **不要把 token 写进项目仓**，永远只放在用户 home 下的全局 `mcp.json`，避免误推 GitHub。

### 2.4 全局配置 checklist

| 项 | 路径 | 状态检查 |
|---|---|---|
| lark-cli 已登录 | `~/.lark-cli/` | `lark-cli auth whoami` 有返回 |
| 全局 skills 目录存在 | `~/.cursor/skills/` | `ls ~/.cursor/skills` 非空 |
| 全局 MCP 配置 | `~/.cursor/mcp.json` | 内含 figma server 且 token 有效 |

---

## 3. 模板仓的存放与同步策略

`F:\workspace-template\` 是"模板源头"，需要在多台机器之间保持同步。三种策略对比：

| 策略 | 同步方式 | 优点 | 缺点 | 推荐场景 |
|---|---|---|---|---|
| **A. 私有 Git 仓** ⭐ | 推到 GitHub / Gitee / GitLab 私有仓库，新机器 `git clone` | 版本可追溯、可分支、可 PR、跨平台无差异 | 需要 git 账号 + 网络 | **默认推荐**，团队 / 多台个人机 |
| **B. 云盘同步** | OneDrive / iCloud Drive / Dropbox 直接同步整个目录 | 零配置、改完即同步 | 软链 / `.git` 目录在不同 OS 间可能出问题；冲突难处理；含敏感信息易泄露 | 个人 1-2 台机器、纯文档型模板 |
| **C. 手动复制** | U 盘 / scp / `robocopy` | 完全离线、无依赖 | 容易忘同步、版本会漂 | 临时机 / 离线环境 |

### 3.1 为什么默认推荐策略 A（Git）

1. **模板本身就在演进**：BOARD 机制 / init-project.ps1 / 各 role 提示词都会迭代，需要 commit history。
2. **跨 OS 安全**：Git 会正确处理换行符（配合 `.gitattributes`），云盘则会原样同步 CRLF 导致 macOS 端报错。
3. **可分叉、可 PR**：团队成员可以提改进，主仓 review 后 merge。
4. **天然排除敏感**：`.gitignore` 可以稳定排除 `mcp.json` / `*.token` 等。

### 3.2 策略 A 推荐姿势

```powershell
# 在源机器上初始化
cd F:\workspace-template
git init
git add .
git commit -m "init workspace template"
git remote add origin git@github.com:<you>/workspace-template.git
git push -u origin main

# 在新机器上
git clone git@github.com:<you>/workspace-template.git F:\workspace-template
```

> 🚫 **不要把 `~/.cursor/mcp.json`、lark-cli token、Figma token 推进仓库**。模板仓只放"骨架 + 脚本 + 文档"。

---

## 4. 新机器从零到能用：分步指南

> 假设你已经按 §1 装好 Cursor / Git / Node / PowerShell，现在从 "全新 Windows 系统" 起步。

```powershell
# === 第 1 步：装并登录 lark-cli ===
npm i -g @larksuite/lark-cli
lark-cli auth login              # 浏览器会弹出来扫码
lark-cli auth whoami             # 确认登录成功

# === 第 2 步：准备全局 skills 目录 ===
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.cursor\skills" | Out-Null
# 把你的 skill 仓 clone 进来（如果你维护了一个）
# git clone git@github.com:<you>/cursor-skills.git $env:USERPROFILE\.cursor\skills

# === 第 3 步：准备全局 MCP 配置 ===
# 用编辑器打开 $env:USERPROFILE\.cursor\mcp.json
# 按 §2.3 填好 figma 等 server 的 token
notepad "$env:USERPROFILE\.cursor\mcp.json"

# === 第 4 步：拉模板仓 ===
git clone git@github.com:<you>/workspace-template.git F:\workspace-template

# === 第 5 步：初始化新项目 ===
cd F:\workspace-template
.\init-project.ps1 -Name "my-project" -Path "F:\my-project"

# === 第 6 步：在新项目里建 skill 软链 ===
cd F:\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor\setup-skill-links.ps1

# === 第 7 步：用 Cursor 打开 ===
cursor F:\my-project
# 或在 Cursor 里 File → Open Folder → F:\my-project
```

**macOS / Linux 等价命令：**

```bash
# 1
npm i -g @larksuite/lark-cli && lark-cli auth login

# 2
mkdir -p ~/.cursor/skills

# 3
nano ~/.cursor/mcp.json

# 4
git clone git@github.com:<you>/workspace-template.git ~/workspace-template

# 5
cd ~/workspace-template
pwsh ./init-project.ps1 -Name "my-project" -Path "$HOME/my-project"

# 6
cd ~/my-project
pwsh ./.cursor/setup-skill-links.ps1     # 见 §5.1 关于 macOS symlink 的说明

# 7
cursor ~/my-project
```

### 4.1 一次性完成检查

打开新项目后，在 Cursor 里：

1. 看 chat 左侧 agent picker，应能看到 `prd-planner` / `figma-to-prd` / `code-impl` / `data-analyst` / `visual-design` 5 个 subagent。
2. 随便问一句 "列出可用 skills"，应包含 `brainstorming` / `change-verification` / `lark-doc` / `figma-use` 等。
3. 试一句 `用 figma mcp 看一下这个 file: <任意 figma url>`，能拿到 metadata 即 MCP 正常。

---

## 5. 跨平台注意事项

### 5.1 软链：Windows junction vs macOS/Linux symlink

`setup-skill-links.ps1` 当前用 `New-Item -ItemType Junction`（Windows 专属）。在 macOS/Linux 上：

- **PowerShell 7 + `New-Item -ItemType SymbolicLink`** 可以跨平台工作，**但需要权限**：
  - macOS：普通用户即可
  - Linux：普通用户即可
  - Windows：需要开发者模式 或 管理员权限（junction 反而不需要，所以 Windows 仍优先 junction）

**建议方案**：在 `setup-skill-links.ps1` 内部按 `$IsWindows` 分支处理，**不需要额外 `.sh` 版本**（PowerShell 7 已经是 macOS/Linux 一等公民）。

伪代码示意（仅作思路参考，实际由骨架 worker 落地）：

```powershell
if ($IsWindows) {
    New-Item -ItemType Junction -Path $link -Target $target
} else {
    New-Item -ItemType SymbolicLink -Path $link -Target $target
}
```

> ⚠️ 如果团队里确实有同事不愿装 PowerShell 7，**再**补一个 `setup-skill-links.sh`（用 `ln -s`）。但优先单脚本方案。

### 5.2 路径分隔符（`\` vs `/`）

**原则**：规则文件 / 文档 / SKILL.md 里**不要硬编码绝对路径**，能用相对路径就用相对路径。

如果确实有遗留的 Windows 绝对路径（例如 `F:\minicreata-v3\...`），迁到 mac 时批量替换：

```bash
# macOS / Linux：把 F:\workspace-template\ 全部替换成 $HOME/workspace-template/
cd ~/workspace-template
grep -rl 'F:\\workspace-template\\' . | xargs sed -i '' 's#F:\\\\workspace-template\\\\#'"$HOME"'/workspace-template/#g'
# Linux 上把 sed -i '' 改成 sed -i
```

更稳妥的做法：在脚本里用 `$PSScriptRoot` / `Join-Path`，让路径自适配。

### 5.3 行尾符（CRLF vs LF）

强烈建议模板仓加 `.gitattributes`：

```gitattributes
# 默认按平台自动转换（Windows 检出 CRLF，提交 LF）
* text=auto eol=lf

# 这些类型强制 LF（脚本 / 配置）
*.sh        text eol=lf
*.ps1       text eol=lf
*.md        text eol=lf
*.json      text eol=lf
*.yml       text eol=lf
*.yaml      text eol=lf

# 二进制
*.png       binary
*.jpg       binary
*.pdf       binary
```

> 📌 **需要骨架 worker 配合**：把 `.gitattributes` 加进 `F:\workspace-template\` 根目录。本文档已记录原因和内容，落地由骨架 worker 处理（见文末 §8）。

---

## 6. 已有项目迁移到新机器

假设你要把**整个 `F:\minicreata-v3`**（不是新建，而是迁移）搬到另一台机器：

### 6.1 步骤

```powershell
# 1. 在源机器上提交所有未提交改动并推送
cd F:\minicreata-v3
git status                       # 确保 clean
git push

# 2. 在新机器上 clone
git clone <repo-url> F:\minicreata-v3

# 3. 重跑 skill 软链脚本（软链不会跟着 git 走）
cd F:\minicreata-v3
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor\setup-skill-links.ps1

# 4. 确认 lark-cli 已登录
lark-cli auth whoami
# 若提示未登录：
#   lark-cli auth login

# 5. 确认 Cursor 全局 MCP 配置就位
Test-Path "$env:USERPROFILE\.cursor\mcp.json"
# 若不存在或缺 figma，按 §2.3 补齐

# 6. 确认全局 skills 目录就位
Test-Path "$env:USERPROFILE\.cursor\skills"

# 7. Cursor 打开
cursor F:\minicreata-v3
```

### 6.2 哪些东西"跟着 git 走"，哪些"不会跟着 git 走"

| 内容 | 走 git? | 备注 |
|---|---|---|
| `roles/`、`shared/`、`README.md` | ✅ | 项目核心 |
| `.cursor/agents/`、`.cursor/rules/`、`.cursor/*.ps1` | ✅ | 编排框架 |
| `.cursor/skills/`（junction） | ❌ | 软链本身可能 commit 成奇怪东西，建议 `.gitignore` 排除，每台机器重建 |
| `~/.cursor/mcp.json` | ❌ | 用户级配置，含 token |
| `~/.cursor/skills/` | ❌ | 全局 skill 仓 |
| `~/.lark-cli/` | ❌ | 登录凭证，机器绑定 |

> 📌 **需要骨架 worker 配合**：在 `.gitignore` 里加 `.cursor/skills/`（如果是软链）。

---

## 7. 故障排查 FAQ

### Q1: Cursor 提示 "skill not found" 或 skill picker 是空的

**原因**：
1. 没跑 `setup-skill-links.ps1`
2. 全局 `~/.cursor/skills/` 目录不存在 / 是空的
3. junction 创建失败（Windows 上偶发权限问题）

**排查**：

```powershell
# 检查软链
Get-ChildItem F:\my-project\.cursor\skills -Force
# 看 Mode 列有没有 'l'（link）或 'j'（junction）

# 检查目标
Test-Path "$env:USERPROFILE\.cursor\skills"
Get-ChildItem "$env:USERPROFILE\.cursor\skills"
```

**修复**：

```powershell
# 删旧软链，重跑脚本
Remove-Item F:\my-project\.cursor\skills -Force -Recurse
cd F:\my-project
powershell -NoProfile -ExecutionPolicy Bypass -File .cursor\setup-skill-links.ps1
```

### Q2: `lark-cli: command not found`

**原因**：npm 全局 bin 目录没在 PATH 里。

**排查**：

```powershell
npm config get prefix
# Windows 典型输出：C:\Users\<you>\AppData\Roaming\npm
# 把这个目录加入 PATH
```

**修复（Windows，永久）**：

```powershell
$npmPrefix = npm config get prefix
[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path","User") + ";$npmPrefix",
    "User"
)
# 重开 PowerShell 生效
```

**修复（macOS/Linux）**：把 `$(npm config get prefix)/bin` 加到 `~/.zshrc` 或 `~/.bashrc` 的 `PATH`。

### Q3: Figma MCP 不工作 / agent 调用 `mcp_figma_*` 报 timeout

**原因**：
1. `~/.cursor/mcp.json` 不存在或没配 figma
2. `FIGMA_API_KEY` 失效 / 过期 / 权限不够
3. `npx figma-developer-mcp` 第一次拉包很慢，超时

**排查**：

```powershell
# 1. 配置文件存在?
Get-Content "$env:USERPROFILE\.cursor\mcp.json"

# 2. token 还有效?
# 去 https://www.figma.com/settings → Personal access tokens 看是否还在 / 没过期

# 3. 手动跑一下 MCP server，看是否报错
npx -y figma-developer-mcp --stdio
# 应该卡在等待 stdin 输入（这是对的），按 Ctrl+C 退出
```

**修复**：
- 重生成 token 并替换 `mcp.json` 里的值
- 在 Cursor 设置里 Reload MCP servers

### Q4: `init-project.ps1` 报错 "execution policy"

**原因**：Windows 默认禁止跑未签名脚本。

**修复**：

```powershell
# 临时（推荐）
powershell -NoProfile -ExecutionPolicy Bypass -File .\init-project.ps1 -Name "x" -Path "F:\x"

# 永久（仅当前用户，安全）
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Q5: `board.html` 打不开 / 一直显示 "加载中"

**说明**：当前 BOARD 用的是 **embed 方案**（数据直接内嵌在 html 里 / 同目录读 json），**不依赖** `http.server`，本地双击即可打开。

如果你的 BOARD 是 fetch 方案（远程或本地 http 拉 json），双击打开会因 CORS 失败，需要：

```powershell
# Windows / 任意平台
cd <board.html 所在目录>
python -m http.server 8000
# 浏览器打开 http://localhost:8000/board.html
```

> 当前架构是 embed，**预期遇不到这个问题**。如果遇到了，说明骨架 worker 切回了 fetch，请通知。

### Q6: macOS / Linux 上 `setup-skill-links.ps1` 报 "Cannot create junction"

**原因**：junction 是 Windows-only，Unix 系应该用 symlink。

**修复**：
- 用 PowerShell 7 跑（`pwsh ./setup-skill-links.ps1`），脚本应有 `$IsWindows` 分支自动切换。
- 若脚本没分支，临时改成 `ln -s ~/.cursor/skills .cursor/skills`。
- **长期方案**：骨架 worker 给脚本加跨平台分支（见 §5.1）。

### Q7: 行尾符问题 → 脚本在 macOS 上报 `bad interpreter: ^M`

**原因**：从 Windows clone 下来时行尾被转成 CRLF，bash 不认。

**修复**：

```bash
# 单文件
sed -i '' 's/\r$//' setup-skill-links.sh   # macOS
sed -i 's/\r$//' setup-skill-links.sh      # Linux

# 永久修复：加 §5.3 的 .gitattributes，重新 clone
```

### Q8: 切换网络环境后 `npm i -g` 卡死 / `git clone` 超时

**典型场景**：公司网 vs 家里网，npm 源 / git 代理不一致。

**修复**：

```powershell
# 切 npm 源到国内镜像
npm config set registry https://registry.npmmirror.com
# 切回官方
npm config set registry https://registry.npmjs.org

# git 走代理
git config --global http.proxy http://127.0.0.1:7890
# 取消代理
git config --global --unset http.proxy
```

---

## 8. 需要其他 worker 配合的事项

本文档只能"描述"理想行为，以下落地工作请对应 worker 跟进：

| # | 事项 | 归属 worker | 优先级 |
|---|---|---|---|
| ① | 在 `F:\workspace-template\` 根加 `.gitattributes`（内容见 §5.3） | 骨架 worker | P0 |
| ② | 在 `F:\workspace-template\.gitignore` 加 `.cursor/skills/`（避免软链被 commit） | 骨架 worker | P0 |
| ③ | `setup-skill-links.ps1` 内部按 `$IsWindows` 分支创建 junction / symlink，跨平台单脚本 | 骨架 worker | P1 |
| ④ | `init-project.ps1` 完成后输出 "下一步" 提示（建议提示用户跑 `setup-skill-links.ps1`） | 骨架 worker | P1 |
| ⑤ | （可选）维护一个 `your-cursor-skills` 仓，方便新机器一次 clone 进 `~/.cursor/skills/` | 团队基建 | P2 |
| ⑥ | （可选）写一个 `bootstrap.ps1` 把 §4 的步骤 1-5 串起来，新机器一行命令搞定 | 骨架 worker | P2 |

---

## 附录 A：一行命令快速体检（新机器装完后跑）

```powershell
@(
  @{ Name = "Cursor";        Cmd = "cursor --version" },
  @{ Name = "Git";           Cmd = "git --version" },
  @{ Name = "Node";          Cmd = "node --version" },
  @{ Name = "npm";           Cmd = "npm --version" },
  @{ Name = "PowerShell";    Cmd = '$PSVersionTable.PSVersion.ToString()' },
  @{ Name = "lark-cli";      Cmd = "lark-cli --version" },
  @{ Name = "lark 登录态";   Cmd = "lark-cli auth whoami" }
) | ForEach-Object {
    $r = try { Invoke-Expression $_.Cmd 2>&1 | Out-String } catch { "❌ $_" }
    "{0,-18} : {1}" -f $_.Name, ($r.Trim() -replace "`r?`n"," | ")
}

# 检查关键路径
"$env:USERPROFILE\.cursor\skills",
"$env:USERPROFILE\.cursor\mcp.json" | ForEach-Object {
    "{0,-50} : {1}" -f $_, $(if (Test-Path $_) {"✅"} else {"❌ 缺失"})
}
```

预期全部 ✅ 即可开始用 `init-project.ps1` 新建项目。

---

**文档版本**：v1.0  
**最后更新**：2026-05-26  
**维护**：跨平台 / 移植性方向由本文档负责，骨架 / 编排细节由各对应文档负责。
