---
name: feishu-bitable-trigger
description: >-
  Use when a Feishu Bitable / 多维表格 record or field change should start an n8n workflow.
  需要「多维表格记录变更 / 字段变更时启动 n8n 工作流」时使用。
  说明：没有单独的 Bitable Trigger，要用 Feishu Suite Trigger + 订阅云文档事件。
  不要用它来写记录或配凭据（见 feishu-bitable-workflows / feishu-n8n-setup）。
---

# 多维表格事件 Trigger

依据：[BITABLE_RECIPES.md](../../docs/BITABLE_RECIPES.md) 配方 8、[E2E_REPORT.md](../../docs/E2E_REPORT.md)。e2e：`subscribeFile`（`file_type=bitable`）PASS；长连接 Trigger 激活 PASS。

## 没有单独的 Bitable Trigger

用通用 **`Feishu Suite Trigger`**（长连接 WebSocket）。

## 步骤

1. 工作流加 `Feishu Suite Trigger`，凭据用已 Test 通过的 **Feishu Suite API**
2. Options → **订阅云文档事件**
   - 类型：**多维表格（Bitable）**
   - File Token = 多维表格的 `app_token`（用选择器或「解析多维表格链接」，不要手猜）
3. Events 勾选需要的：
   - `drive.file.bitable_record_changed_v1` — 记录变更
   - `drive.file.bitable_field_changed_v1` — 字段变更
4. 也可以先在 `Feishu Suite` / `Feishu Suite Base` 跑 **订阅云文档事件**（`subscribeFile`，`file_type=bitable`），再激活 Trigger
5. 开发者后台「事件订阅」必须挂在**已发布版本**上（和权限一样：草稿勾选不算）
6. 激活工作流

## 已验证的注意点

- **一个应用同时只能有一条长连接。** 不要对同一 App ID 开第二条 `Feishu Suite Trigger`。
- 事件订阅未随已发布版本开通时，行为与缺权限类似：后台看起来开了，线上不生效。先发布再激活。
- e2e 在表格被拆掉之后 `unsubscribeFile` 会 404；订阅本身 PASS。日常不要对已删除的 Base 做退订。
- `Feishu Suite Webhook Trigger` 的 `url_verification` 在本环境 `/webhook/{id}` 404，**未跑通**。记录变更请用长连接 Trigger，不要改走 Webhook Trigger。
- 下游写回多维表格：见 [feishu-bitable-workflows](../feishu-bitable-workflows/SKILL.md)。不要对真实业务群群发。
