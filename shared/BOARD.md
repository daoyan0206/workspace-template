# 需求看板说明(Topic Board)

> 本文件是**说明文档**,不是数据源。
> - 数据源(机器读写):[`board.json`](./board.json)
> - 可视化(浏览器查看):[`board.html`](./board.html) — 双击本地打开
> - agent 读写规则见 [`.cursor/rules/ORCHESTRATOR.md`](../.cursor/rules/ORCHESTRATOR.md) §3

## 字段含义

| 字段 | 类型 | 含义 |
|---|---|---|
| `name` | string | topic 名称,与文件命名 `<topic>-vN.md` 对应 |
| `stage` | string | 当前阶段,取值见下表 |
| `status` | enum | `doing` / `await` / `done` / `blocked` |
| `latestArtifact` | string | 最新产物的相对路径(基于工作区根) |
| `waitingFor` | string | 等待动作的描述,例如"用户审 v1" |
| `owner` | string\|null | 正在跑的 subagent 角色名,无则 null |
| `notes` | string | 备注/风险/特殊说明 |

## stage 取值

| stage | 含义 |
|---|---|
| `Step 1` | prd-planner 出 `prd/<topic>-v1.md`(纯需求) |
| `Step 2` | visual-design 出线框 + 合并为 `prd/<topic>-v2.md` |
| `Human(Figma)` | 设计师据 v2 在 Figma 出终稿(人工,agent 等 URL) |
| `Step 3` | figma-to-prd 回灌终稿为 `prd/<topic>-v3.md` |
| `Step 4` | data-analyst 出 `data-reports/<topic>-events.md` |
| `Step 5` | 主 agent 汇总 |
| `Done` | 全流程完成,归档 |

## status 取值

| status | 含义 | 谁来推进 |
|---|---|---|
| `doing` | subagent 正在跑 | 等 subagent 返回 |
| `await` | 等用户审 / 等用户输入(如 Figma URL) | 用户 |
| `done` | 该 topic 全流程完成 | — |
| `blocked` | 被跨团队依赖卡住(如 RISK-002) | 用户协调外部 |

## 双写规则(MUST,给主 agent)

每次 subagent 返回后,主 agent **同一回合**内必须:

1. **改 `board.json`**:更新对应 topic 的字段 + 顶部 `updatedAt`(ISO 8601 时区+08:00)
2. **同步嵌入 `board.html`**:替换 HTML 中 `<!-- BOARD_DATA_START -->` 与 `<!-- BOARD_DATA_END -->` 之间的 `<script id="board-data">` 块,内容与 `board.json` 完全一致

新增 topic 时,在 `board.json` 的 `topics` 数组追加一项,然后同步 HTML。

## 历史已生成但未纳入新流程的产物(参考用,不计入看板)

(本节由项目按需填写,新初始化项目可删除)
