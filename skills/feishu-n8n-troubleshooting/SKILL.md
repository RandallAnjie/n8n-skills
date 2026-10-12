---
name: feishu-n8n-troubleshooting
description: >-
  Use when an n8n Feishu / 飞书 node errors (99991672, 40004, 99992402, rate limits, timezone).
  n8n 飞书节点报错时使用。覆盖已实测错误码：99991672 缺 scope、40004 无部门权限、
  99992402 字段校验失败、1254290/1254291/1254607 限流与写冲突、重试行为、
  日期时区 Asia/Shanghai。先对照本文再改工作流，不要编造新的错误含义。
---

# 飞书 n8n 排错

只收录本租户 e2e / 配方里出现或写明的码。[E2E_REPORT.md](../../docs/E2E_REPORT.md)、[REQUIRED_SCOPES.md](../../docs/REQUIRED_SCOPES.md)、[BITABLE_RECIPES.md](../../docs/BITABLE_RECIPES.md)。

先把飞书返回的 **code / msg / scope** 原样抄下来。

## `99991672` 缺权限

原文示例（解散群）：

```
code=99991672
msg=Access denied. One of the following scopes is required: [im:chat, im:chat:delete].应用尚未开通所需的应用身份权限：[im:chat, im:chat:delete]
token_type=tenant
```

节点文案：`Missing Feishu permission scope (code 99991672): <names>` + 开发者后台 / 发布新版本 / 数据范围。

**后台勾了「全部权限」仍会出这个。** 飞书认已发布版本 + 管理员授权 + 数据范围，不是草稿勾选。`token_type=tenant` = 应用身份。

本租户实测（满足飞书列出的其一即可）：

| 操作 | scope |
| --- | --- |
| `chat.delete` | `im:chat`, `im:chat:delete` |
| `calendar.getPrimaryInfo` | `calendar:calendar:readonly`, `calendar:calendar.calendar:readonly`, `calendar:calendar:read` |
| `calendar.getList` | `calendar:calendar:readonly`, `calendar:calendar`, `calendar:calendar.calendar:readonly`, `calendar:calendar:read` |
| `mail.listMailGroups` | `mail:mailgroup`, `mail:mailgroup:readonly` |
| `attendance.listAttendanceGroups` / `listAttendanceShifts` | `attendance:rule:readonly`, `attendance:rule` |
| `vc.listRooms` | `vc:room`, `vc:room:readonly`, `vc:rooms.room.basicinfo:read` |
| `approval.queryApprovalInstances` | `approval:approval.list:readonly` |
| `approval.searchApprovalTasks` | `approval:approval.list:readonly`, `approval:approval:readonly` |

多维表格主路径缺的是官方 `bitable:app`（或只读 `bitable:app:readonly` / `base:app:read`）。处理步骤见 [feishu-n8n-setup](../feishu-n8n-setup/SKILL.md)。

## `40004 no dept authority`

**不是**缺 API scope。应用身份对部门/人员的**数据范围**不够。

本租户：人员**字段**创建 PASS；人员**单元格**写入被 `40004` 拦住。去开放平台扩通讯录数据范围，不要再勾一遍 `bitable:app`。

## `99992402`

本租户：创建**查找引用**字段（type 19）→ `field validation failed`。官方 create-field 对 type 19 很严。

做法：在飞书 UI 建好查找列，工作流只用「获取记录 / 查询记录」只读。不要让 Agent 创建 type 19。以飞书返回的 `msg` 为准。

## 限流 / 写冲突 / 未就绪（会重试）

| code | 含义 | 做法 |
| --- | --- | --- |
| `1254290` | 限流 TooManyRequest | 节点会重试；自己拉开间隔，避免并行狂写 |
| `1254291` | 写冲突 | 同一张表不要并行多个写接口 |
| `1254607` | 数据未就绪 | 与上面走同一套退避 |
| `99991400` | 飞书限流 | 会重试 |
| HTTP 429 | 限流 | 会重试 |
| HTTP 5xx | 服务端瞬时错误 | e2e mock（503 两次再 200）PASS |

配方写明：`1254290` / `1254291` / `99991400` / HTTP 429 会重试。0.1.5 把 `1254607` 也列入同类退避。官方新增记录大约 50 次/秒。批量也可自己 100～200 一条，靠重试扛。

不要对 `99991672` / `40004` / `99992402` 做自动重试——重试没用。

## 日期和时区

- 飞书日期字段要 **Unix 毫秒**，不是 `2026-10-12` 字符串
- 本包会把 `2026-10-12`、`2026-10-12 18:00:00`、ISO 按 **Asia/Shanghai** 转毫秒（e2e 创建/更新表格 Options 用了 `time_zone=Asia/Shanghai`）
- 把 n8n 工作流 / 实例的 `settings.timezone` 设为 **`Asia/Shanghai`**，让 Schedule 和表达式拼出的日期与节点默认时区一致，避免差一天
- 需要别的时区时，只改创建多维表格 Options 的 `time_zone`，并在记录里改用毫秒，不要混用未转换的本地字符串

## 其它已见到、但不是缺 scope

| 现象 | 含义 |
| --- | --- |
| 批量一次超过 500 | 官方上限；走本包批量操作会自动拆批（e2e 501 PASS） |
| `1254301` | 未 `updateApp` 打开 `is_advanced` 就调角色/协作者 |
| `1254069` / `1254303` | 附件不属于当前 Base，或把外部 URL 塞进附件字段 |
| `232097` | 新群公告已是 Docx，旧 IM 公告接口不能改 |
| `99991663` | token 过期；n8n 可能以 HTTP 400 抛出。e2e 将其归为 BLOCKED-needs-resource |

## 工作流 / Trigger

- `parseWebhook` 必须挂在 n8n **Webhook** 后面
- `Feishu Suite Webhook Trigger` `url_verification`：本环境 `/webhook/{id}` 404，未验证
- 一个应用只能有一条长连接 Trigger
- `continueOnFail` e2e PASS：允许单节点失败后继续
- 必填项校验 e2e PASS：缺「数据表」等会在运行前拦住
