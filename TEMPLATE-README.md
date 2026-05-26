# workspace-template

> 5 角色 subagent 协作工作区模板。基于 `minicreata-v3` 抽取通用框架。

## 这是什么

一套**可复用的 AI 多角色协作工作区骨架**:

- 5 个角色 subagent(figma-to-prd / prd-planner / code-impl / data-analyst / visual-design)
- 主 agent 编排手册(串行评审制 + 多 topic 看板)
- 共享原料/产物/风险/决策目录
- 需求看板可视化(`board.html` 本地查看,零配置)

## 怎么开新项目

```powershell
cd F:\workspace-template
.\init-project.ps1 -Name "my-new-project" -Path "F:\my-new-project"
```

脚本会:
1. 复制模板到目标路径
2. 把 `*.template` 文件重命名去掉后缀
3. 初始化 `board.json` 时间戳
4. 跑 `setup-skill-links.ps1` 建 skill 软链

之后手工做:
1. 填写 `.cursor\rules\PROJECT.md`(替换 `<PROJECT_NAME>` 等占位符)
2. 填写 `shared\PROJECT.md` / `GLOSSARY.md`
3. 把项目原料放到 `shared\inputs\`
4. 用 Cursor 打开新项目目录开干

## 目录结构

```
workspace-template\
  .cursor\
    rules\
      ORCHESTRATOR.md             ← 主 agent 编排手册(项目无关)
      PROJECT.md.template         ← 项目背景骨架,需替换占位符
    agents\                       ← 5 个角色 yaml(可能含 minicreata 残留,按需通用化)
    setup-skill-links.ps1         ← skill 软链脚本
    mcp.json                      ← 项目级 MCP(默认空)
  shared\
    PROJECT.md.template
    GLOSSARY.md.template
    DECISIONS.md.template
    BOARD.md                      ← 看板字段说明
    board.html                    ← 可视化看板(双击打开)
    board.json.template           ← 看板数据源
    inputs\designs\
    outputs\{prd,design-specs,code-plans,data-reports,visual-assets}\
    handoffs\
    risks\cross-team-alignment.md
  roles\{figma-to-prd,prd-planner,code-impl,data-analyst,visual-design}\
    workspace\                    ← 角色私有草稿区
  init-project.ps1                ← 一键初始化脚本
  TEMPLATE-README.md              ← 本文件(不复制到新项目)
```

## 当前框架的核心约定

详细规则见 `.cursor\rules\ORCHESTRATOR.md`,关键点:

1. **全流程编排走串行评审制**
   `Step 1 prd-planner → 用户审 → Step 2 visual-design → 用户审 → 人工 Figma → Step 3 figma-to-prd → 用户审 → Step 4 data-analyst → 用户审 → Step 5 汇总`
2. **PRD 三版迭代**:`<topic>-v1.md`(纯需求) / `<topic>-v2.md`(含线框) / `<topic>-v3.md`(含终稿)
3. **`code-impl` 已剔除出全流程**,需要时单独派发
4. **Figma 终稿必须人工出**,agent 只做线框(visual-design)和回灌(figma-to-prd)
5. **多 topic 并行靠看板隔离**(`shared/board.json` 是 SSOT,`board.html` 是可视化)
6. **不要并发派发同一 topic 的多个步骤**
7. 用户指令不带 topic 名,看板里有多个 await topic 时,agent 必须先问

## 注意事项

- `.cursor\agents\*.yaml` 从 minicreata-v3 直接复制,可能含项目耦合表述,初始化新项目后建议通读一遍按需通用化
- `setup-skill-links.ps1` 里的路径(C:\Users\wangjiawei\...)依赖当前机器的 skill 安装位置,迁移到新机器需调整
- 模板本身不进 git;新项目作为独立 repo 各自管理
