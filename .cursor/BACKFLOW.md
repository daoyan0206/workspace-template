# 项目经验回流机制(BACKFLOW)

> 本文档讲清楚一件事:**当某个具体项目(基于本模板 init 出来的)在演进过程中,把框架性的改进沉淀下来后,如何把这些改进"反向流"回模板仓,供之后所有新项目复用**。
>
> 用户拍板的方案:**混合 D** —— 平时用 diff 脚本逐项手工选推,批量同步走 git subtree。
>
> 追踪范围:**框架文件 + 项目沉淀的新 skill**(skill 提案要人工评审是否通用)。

---

## 1. 概念模型

### 1.1 三层架构

```
┌─────────────────────────────────────────────────────────────┐
│  全局 Skills 仓(~/.cursor/skills/ 或团队 skills repo)        │
│  - 真正的 skill 实现文件                                       │
│  - 各项目通过 setup-skill-links.ps1 软链使用                  │
└────────────────────────┬────────────────────────────────────┘
                         │ ③ 评审通过的 skill 从模板进入全局
                         │
┌────────────────────────┴────────────────────────────────────┐
│  模板仓(workspace-template,GitHub 托管)                     │
│  - 框架文件(rules / agents / 看板骨架 / init 脚本)          │
│  - skills-proposals/(只放"待评审 skill 提案"骨架)            │
│  - TRACKED_PATHS.txt(单一事实源,框架文件清单)                │
└──────┬──────────────────────────────────────────────┬───────┘
       │ ① 正向流:init-project.ps1 / git subtree pull │ ② 反向流:diff-back-to-template.ps1
       │                                              │   或 git subtree push
       ▼                                              │
┌──────────────────────────────────────────────────────┴──────┐
│  项目仓(基于模板 init 出来,例 minicreata-v3)                │
│  - 框架文件已被占位符替换(<PROJECT_NAME> 等)               │
│  - shared/inputs/、shared/outputs/、roles/*/workspace/ 业务  │
│  - .cursor/skills/_proposals/(项目里在孵化的 skill 草稿)    │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 正向流 vs 反向流

| 方向 | 时机 | 工具 | 谁触发 |
|---|---|---|---|
| **正向流**(模板 → 项目) | 新项目初始化 | `init-project.ps1` | 项目负责人 |
| **正向流**(模板 → 项目) | 已有项目同步模板新版 | `git subtree pull --prefix=. template main --squash` | 项目负责人 |
| **反向流**(项目 → 模板) | 平时逐项推 | `diff-back-to-template.ps1` | 项目负责人 + 模板维护人 |
| **反向流**(项目 → 模板) | 批量合并(项目作了大量框架改造) | `git subtree push --prefix=. template feature/<...>` | 模板维护人 |

### 1.3 哪些文件归"框架"(可回流),哪些归"业务"(不可回流)

> **核心判据**:文件内容是否与"具体业务领域 / 具体产品功能 / 具体团队组织"绑定。绑定的就是业务,不绑定的就是框架。

**可回流(框架资产)** — 详见 §2:
- 主 agent 编排规则、subagent 定义、跨平台脚本、看板模板、init 脚本、模板说明、PORTABILITY/BACKFLOW 自身。

**不可回流(业务资产)**:

```
shared/inputs/          ← 业务原料(产品结构、调研、参考链接)
shared/outputs/         ← 业务产出(PRD / 设计稿 / 数据报告)
shared/handoffs/        ← 业务交接单
shared/risks/           ← 业务风险登记
shared/PROJECT.md       ← 业务项目主信息(项目名、负责人、里程碑)
shared/GLOSSARY.md      ← 业务术语表
shared/DECISIONS.md     ← 业务决策记录
roles/*/workspace/      ← 角色级业务工作空间
.cursor/skills/         ← 软链到全局,**模板不持有内容**
```

> ⚠️ 例外:`shared/PROJECT.md` 在**模板侧**叫 `PROJECT.md.template`,只有占位符骨架,这部分是框架;项目侧实例化后产生的业务内容不回流。

---

## 2. 受追踪文件清单(TRACKED_PATHS)

**单一事实源**:[`F:\workspace-template\TRACKED_PATHS.txt`](../TRACKED_PATHS.txt)

`diff-back-to-template.ps1` 与本文档共同读取该文件。每行一个相对路径;若模板侧命名带 `.template` 后缀,用 `|` 分隔(`项目侧|模板侧`)。

清单(摘录,以 `TRACKED_PATHS.txt` 为准):

```
.cursor/rules/ORCHESTRATOR.md
.cursor/rules/PROJECT.md|.cursor/rules/PROJECT.md.template
.cursor/agents/code-impl.yaml
.cursor/agents/data-analyst.yaml
.cursor/agents/figma-to-prd.yaml
.cursor/agents/prd-planner.yaml
.cursor/agents/visual-design.yaml
.cursor/setup-skill-links.ps1
.cursor/PORTABILITY.md
.cursor/BACKFLOW.md
shared/board.html|shared/board.html.template
shared/board.json|shared/board.json.template
shared/BOARD.md
init-project.ps1
TEMPLATE-README.md
```

**不追踪**(列出来防止误推):

```
shared/inputs/ shared/outputs/ shared/handoffs/ shared/risks/
shared/PROJECT.md shared/GLOSSARY.md shared/DECISIONS.md
roles/*/workspace/
.cursor/skills/              ← 软链,不持有内容
.cursor/skills/_proposals/   ← 项目里的草稿,推回时映射到模板 .cursor/skills-proposals/<name>/
```

---

## 3. 平时使用:`diff-back-to-template.ps1` 工作流

### 3.1 它做什么

逐项对比"项目侧文件 vs 模板侧文件",**忽略占位符差异**,把"真正的框架级改动"挑出来交互式问用户是否推回模板。

### 3.2 标准用法

```powershell
# 默认交互模式:逐项问"推 / 跳过 / 中止"
.\diff-back-to-template.ps1 -ProjectPath F:\minicreata-v3

# Dry-run:只展示 diff 不做任何写操作
.\diff-back-to-template.ps1 -ProjectPath F:\minicreata-v3 -DryRun

# 指定模板路径(默认为脚本所在目录)
.\diff-back-to-template.ps1 -ProjectPath F:\minicreata-v3 -TemplatePath F:\workspace-template
```

### 3.3 行为流程

1. 读 `TRACKED_PATHS.txt`,逐路径在项目侧 + 模板侧定位文件。
2. 对每对文件做占位符规范化(把项目侧 `项目名` 还原为 `<PROJECT_NAME>`、时间戳还原为 `<INIT_TIMESTAMP>` 等)。
3. 用 `git diff --no-index` 着色展示差异。
4. 交互式问:`[P]ush / [S]kip / [A]bort`。
5. 用户对至少 1 项选 P:
   - 在模板仓拉新分支 `backflow/<project-name>-<yyyyMMddHHmmss>`
   - 把项目侧文件**做反向占位符替换后**写入模板对应路径
   - `git add` + `git commit`(commit message 引用项目名 + 选中的文件清单)
   - 输出:"已落到分支 `backflow/...`,请到模板仓 `git push origin <branch>` 并提 PR"
6. **不真正 push**,留给用户人工 review。

详见脚本头部注释。

---

## 4. 批量同步:`git subtree` 工作流

适用场景:**项目对框架做了大量同步改造**(例如重写了 ORCHESTRATOR.md + 加了 2 个 agent + 改了看板格式),一条一条用 diff 推不划算,直接整段 subtree push。

### 4.1 一次性准备:在项目仓登记 upstream 模板

```powershell
cd F:\minicreata-v3
git remote add template https://github.com/<org>/workspace-template.git
git fetch template
```

### 4.2 项目演进后想推回模板

```powershell
# 在项目仓的 main(或 release 分支)上:
git subtree push --prefix=. template feature/from-minicreata-v3
# 然后到 GitHub 模板仓提 PR:feature/from-minicreata-v3 -> main
```

### 4.3 想从模板拉最新

```powershell
# 在项目仓:
git subtree pull --prefix=. template main --squash
```

### 4.4 ⚠️ "整个项目即子树"场景的局限

本模板初始化出来的项目,**项目根 == 子树根**,导致 `--prefix=.` 会把整个项目当作子树。这会带来两个问题:

1. **业务文件污染模板 PR**:`shared/inputs/`、`shared/outputs/` 等业务内容会跟着被 push 进模板 feature 分支,审 PR 时需要手工剔除。
2. **subtree 历史链与正常 commit 历史混合**:`git subtree push` 会重写一段提交历史,首次执行可能比较慢。

**替代方案 / 缓解策略**:

| 策略 | 适用场景 | 操作 |
|---|---|---|
| **策略 A:用 diff 脚本逐项推** | 改动少 / 想精细控制 | 走 §3,默认方案 |
| **策略 B:为每个 TRACKED_PATH 单独 subtree** | 想批量推但又怕业务文件污染 | 略复杂,见下 |
| **策略 C:在模板侧 PR 上手工 revert 业务文件** | 改动多但不频繁 | 走 §4.2 + PR 上手工清理 |

**策略 B 示例**(为 `.cursor/rules/` 单独建 subtree):

```powershell
# 一次性把模板的 .cursor/rules 拉成项目里的子树
git subtree add --prefix=.cursor/rules template main --squash
# 之后该目录的改动可以独立 push
git subtree push --prefix=.cursor/rules template feature/rules-from-<project>
```

> 👉 **推荐**:默认走策略 A(diff 脚本),只有当改动规模 >5 个 TRACKED_PATH 时才考虑策略 C 一锅端。

---

## 5. Skill 沉淀的特殊流程

> 关键洞察:**模板里不放真实 skill 实现文件**,只放"待评审 skill 提案"目录骨架。真正的 skill 实现归全局 skills 仓,各项目通过 `setup-skill-links.ps1` 软链使用。

### 5.1 在项目里孵化(草稿)

项目里如果出现"这个套路应该沉淀为 skill"的信号:

```
F:\minicreata-v3\.cursor\skills\_proposals\<skill-name>\
├── SKILL.md       # 触发条件 + 步骤 + 至少 2 个用例 + 反例
├── PROPOSAL.md    # 提案人 / 来源项目 / 稳定运行时长 / 复用证据
└── examples/      # 可选,真实跑过的输入输出
```

### 5.2 主 agent 通用性自检(5 维度)

主 agent 在推回前**必须**逐项打勾:

| 维度 | 通过标准 |
|---|---|
| **业务无关性** | SKILL.md 里不含具体业务字段名 / 项目名 / 业务术语 |
| **复用广度** | 至少列出 **2 个不同业务领域**的用例(不是同一项目的两个模块) |
| **触发清晰** | 触发短语具体且不会与现有 skills 大面积重叠 |
| **命令可执行** | 步骤里的命令/工具调用在干净环境里能跑通 |
| **稳定时长** | 源项目里已稳定 ≥1 周,期间至少触发 ≥3 次且没回滚 |

任一不达标 → 留在项目内 `_proposals/` 继续观察,**不要**急着推回模板。

### 5.3 推回模板(待评审)

通过自检后,用 diff 脚本推回:

```powershell
.\diff-back-to-template.ps1 -ProjectPath F:\minicreata-v3
# 选中 _proposals/<skill-name>/ 整个目录推到模板的 .cursor/skills-proposals/<skill-name>/
```

> ⚠️ 脚本对 `skills/_proposals/<name>/` 这条路径做特殊映射:项目侧 `.cursor/skills/_proposals/<name>/` → 模板侧 `.cursor/skills-proposals/<name>/`。

### 5.4 模板维护人评审

模板维护人在模板仓 PR 上审 `PROPOSAL.md` 的评审元数据,在评审记录段追加意见,改 `评审结论` 字段。

### 5.5 进入全局 skills 仓

评审通过后:

1. 把整个目录搬到全局 skills 仓(`~/.cursor/skills/<name>/` 或团队 skills repo)
2. 从模板 `.cursor/skills-proposals/<name>/` **删除**(模板不留 skill 内容)
3. 各项目重新跑 `setup-skill-links.ps1` 即可拿到新 skill

详细评审模板见 [`.cursor/skills-proposals/README.md`](./skills-proposals/README.md)。

---

## 6. 冲突处理

### 6.1 三方对比场景

项目侧改过同一文件 + 模板侧也改过同一文件 → 简单的两方 diff 会丢上下文。

`diff-back-to-template.ps1` 在检测到模板侧 mtime 晚于项目 init 时间(从 `shared/PROJECT.md` 头部 `<INIT_TIMESTAMP>` 反推)时,会提示用户:

```
⚠️ 模板侧文件在你 init 之后被改过,建议先 git subtree pull --squash 同步模板新版,
   再用 diff-back-to-template.ps1 推你的改动。
```

### 6.2 推荐冲突解决工具

| 工具 | 平台 | 用法 |
|---|---|---|
| **VS Code 内置 3-way merge** | 全平台 | `code --diff <项目侧> <模板侧>` |
| **kdiff3** | Win/macOS/Linux | `kdiff3 <共同祖先> <项目侧> <模板侧>` |
| **PowerShell `Compare-Object`** | PS 5+/7+ | `Compare-Object (gc a) (gc b)` 适合脚本快速判 |

### 6.3 冲突解决后续

冲突手工 merge 完,再走一遍 §3 的 diff 脚本确认推哪些 hunk。

---

## 7. 何时回流的判断准则(自检清单)

主 agent / 项目负责人在执行回流前,**全部**满足才推:

- [ ] 改动已在源项目里**稳定运行 ≥1 周**(避免推回半成品)
- [ ] **不含项目业务字段**(项目名、业务术语、具体产品功能名)
- [ ] **至少能列出 2 个其他项目场景**能复用(写在 commit message 里)
- [ ] **没有引入新硬依赖**(npm 包 / 系统命令 / 外部 API);如有,在 PR 描述里单列
- [ ] **通过冲突测试**:在干净的模板 clone 里跑一次 `init-project.ps1` 没有破坏其他功能
- [ ] **不踩 GitHub readiness 边界**:不是 `.gitignore` / `.gitattributes` / `setup-skill-links.ps1` / `init-project.ps1` / `TEMPLATE-README.md` 的并发改动(这些由专门的 readiness worker 负责)
- [ ] **commit message 写清来源项目**:`backflow(<project>): <what & why>`

---

## 8. 主 Agent 的回流操作指南

主 agent 在用户提出"这个改进应该沉淀到模板"或"这个套路应该做成 skill"时,**不要**直接动手,先做以下三步:

1. **确认归类**:这是"框架改动"(走 §3 diff 脚本)还是"新 skill"(走 §5 提案流程)?
2. **跑自检**:对照 §7 清单逐项打勾,把结果摘要给用户。
3. **引导执行**:给出具体命令(diff 脚本路径 / 提案目录路径),**不要**自己 push。

详见 `.cursor/rules/ORCHESTRATOR.md` §8。

---

## 9. 与 GitHub Readiness Worker 的边界

并发任务:GitHub readiness worker 在改

```
.gitignore
.gitattributes
.cursor/setup-skill-links.ps1
init-project.ps1
TEMPLATE-README.md
```

**本任务对这些文件只读不写**。如果回流流程里需要更新它们,留 TODO 给用户人工合并到 readiness worker 的 PR,不要在 backflow 分支里改。

`diff-back-to-template.ps1` 在检测到这五个文件出现在 diff 列表时,会显眼地提示:

```
⚠️ <文件> 由 GitHub readiness 流程维护,本脚本不会推它。
   如确有改动,请在 readiness PR 上合并。
```

---

## 10. 第一次跑回流流程(3 步上手)

> 给项目负责人 / 主 agent 看的最小操作指南。

1. **预览(无副作用)**:
   ```powershell
   cd F:\workspace-template
   .\diff-back-to-template.ps1 -ProjectPath F:\minicreata-v3 -DryRun
   ```
   看一眼哪些文件确实有框架级差异。

2. **逐项选推**:
   ```powershell
   .\diff-back-to-template.ps1 -ProjectPath F:\minicreata-v3
   ```
   每出现一个 diff,按 `P`(推) / `S`(跳过) / `A`(中止)。

3. **去模板仓 push 并提 PR**:
   脚本结束时会告诉你分支名 `backflow/<project>-<ts>`。手工执行:
   ```powershell
   cd F:\workspace-template
   git push origin backflow/<project>-<ts>
   # 然后到 GitHub 提 PR,等模板维护人 review
   ```

完成。后续每次项目演化出值得回流的改动,重复这 3 步即可。
