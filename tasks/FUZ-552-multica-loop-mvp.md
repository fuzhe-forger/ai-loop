# FUZ-552 Phase 1：Multica 到 ai-loop 的安全桥接 MVP

## 原始需求

实现 Multica Issue -> 本地 task.md -> ai-loop dry-run -> summary/comment 草稿 的最小闭环。

## 背景

这是 “Multica ↔ ai-loop” 的 Phase 1 MVP。目标是把 Multica issue 转成本地 ai-loop 任务，并先跑 dry-run，生成可复用的执行证据。

## 本阶段目标

- 从 Multica issue 生成本地 task.md
- 调用 ai-loop dry-run
- 产出 summary 和 comment 草稿
- 默认不写回 Multica

## 验收标准

- 能生成本地任务文件
- 能执行 ai-loop dry-run
- 能生成 summary.md
- 能生成 multica-comment.md
- 默认无远端写副作用

## 安全边界

- 不自动修改 issue 状态
- 不自动回写 comment
- 不自动 push / commit / MR
- 不访问生产系统

## 待补充信息

- 目标 repo
- 验证命令
- 是否允许未来写 comment
- 是否允许未来同步状态
