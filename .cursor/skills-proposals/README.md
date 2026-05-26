# Skills 提案目录(skills-proposals)

> 本目录用于**沉淀从真实项目里捞出的 skill 候选**,在被纳入团队全局 skills 仓之前先在模板里"挂号待审"。
>
> ⚠️ **模板里不放真正的 skill 实现文件**(否则会污染所有 init 出来的新项目)。本目录只放"提案骨架 + 评审记录"。

---

## 1. 它和"全局 skills"的关系

```
项目仓(.cursor/skills/_proposals/<name>/)
        │
        │ ① diff-back-to-template.ps1 推回
        ▼
模板仓(.cursor/skills-proposals/<name>/)       ← 你正在这里
        │
        │ ② 模板维护人评审通过
        ▼
全局 skills 仓(~/.cursor/skills/ 或团队 skills repo)
        │
        │ ③ 各项目通过 setup-skill-links.ps1 软链回去用
        ▼
项目仓(.cursor/skills/<name>/  ← 软链)
```

模板**只承担"评审中转站"角色**,不是 skill 的实际宿主。

## 2. 提案目录结构

一个提案一个子目录:

```
skills-proposals/
├── README.md                              ← 本文件
├── <skill-name>/
│   ├── SKILL.md                           ← 必需,描述 + 触发 + 步骤
│   ├── PROPOSAL.md                        ← 必需,评审元数据(谁提的、何时、复用证据)
│   ├── examples/                          ← 可选,跑通的实例(input/output 片段)
│   │   ├── case-1.md
│   │   └── case-2.md
│   └── tests/                             ← 可选,验证脚本或 dry-run 命令
└── <another-skill>/
    └── ...
```

## 3. 提案最小模板

### 3.1 `SKILL.md`(沿用 Cursor Agent Skills 规范)

```markdown
---
name: <skill-name>
description: <一句话说清这个 skill 什么时候应该被触发(给主 agent 看的)>
---

# <Skill Title>

## 触发条件
- 用户说"…"
- 出现"…"模式
- (3-5 条具体触发短语,中文优先)

## 步骤
1. <动作 1,包含具体工具/命令>
2. <动作 2>
3. <验收信号:跑完后看到什么算成功>

## 用例(MUST ≥2)
### Case 1:<场景>
- 输入:…
- 跑法:…
- 期望产出:…

### Case 2:<另一个项目里的场景>
- 输入:…
- 跑法:…
- 期望产出:…

## 反例 / 不要在以下情况触发
- 当 X 时不要用,因为 …
- 与 <other-skill> 的边界:…
```

### 3.2 `PROPOSAL.md`(评审元数据)

```markdown
# 提案元数据

- **提案人**:<姓名 / GitHub handle>
- **来源项目**:<repo / 工作区名称>
- **沉淀日期**:YYYY-MM-DD
- **稳定运行时长**:在源项目里跑过多久(必须 ≥1 周)
- **复用证据**:至少列出 2 个**不同业务领域**的项目能用到的场景
  1. …
  2. …
- **依赖**:是否引入新的硬依赖(npm 包 / 系统命令 / 外部 API)?
- **冲突检测**:与现有全局 skills 是否命名/职责冲突?
- **评审结论**:`pending` / `accepted` / `rejected` / `needs-revision`
- **评审记录**:
  - YYYY-MM-DD <审核人>:<意见>
```

## 4. 通用性自检 5 维度(主 agent 在推回前必须自检)

| 维度 | 通过标准 |
|---|---|
| **业务无关性** | SKILL.md 里不含具体业务字段名 / 项目名 / 业务术语 |
| **复用广度** | 至少能列出 **2 个不同业务领域**的用例(不是同一项目的两个模块) |
| **触发清晰** | 触发短语具体且不会与现有 skills 大面积重叠 |
| **命令可执行** | 步骤里的命令/工具调用在干净环境里能跑通 |
| **稳定时长** | 在源项目里已稳定运行 ≥1 周,期间至少触发 ≥3 次且没回滚 |

任一维度不达标 → 留在项目内 `_proposals/` 继续观察,**不要**急着推回模板。

## 5. 评审流程

1. **提案进入**:diff-back-to-template.ps1 把项目侧 `_proposals/<name>/` 复制到本目录
2. **维护人评审**:在 `PROPOSAL.md` 评审记录段追加意见,改 `评审结论` 字段
3. **通过**:
   - 把整个目录搬到全局 skills 仓(`~/.cursor/skills/<name>/` 或团队 skills repo)
   - 从本目录**删除**(模板不留 skill 内容)
   - 各项目执行 `setup-skill-links.ps1` 即可拿到
4. **拒绝**:`PROPOSAL.md` 改为 `rejected` 并保留 30 天作为反例存档,之后清理

## 6. 现存提案

> 当前为空。等待第一个从项目里捞出的提案。

<!-- 添加提案时,在此追加一行:
- [<skill-name>](./<skill-name>/) — <一句话摘要> — `pending` since YYYY-MM-DD
-->
