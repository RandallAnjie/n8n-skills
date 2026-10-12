---
name: feishu-bitable-ai-agent
description: >-
  Use when attaching Feishu Bitable / 多维表格 to an n8n AI Agent as a tool.
  要把飞书多维表格接到 n8n AI Agent 当工具时使用。
  Feishu Suite / Feishu Suite Base 已 usableAsTool。不要用它来配 Trigger 或首次凭据。
---

# 多维表格当 AI Agent 工具

依据：[BITABLE_RECIPES.md](../../docs/BITABLE_RECIPES.md) 配方 4、[E2E_REPORT.md](../../docs/E2E_REPORT.md)。e2e：`usableAsTool` 在 **Feishu Suite** 和 **Feishu Suite Base** 上断言通过；中文操作名存在。

## 步骤

1. 凭据已按 [feishu-n8n-setup](../feishu-n8n-setup/SKILL.md) Test 通过
2. 工作流加 **AI Agent**
3. Tools 里加 **`Feishu Suite Base`**（只暴露多维表格，推荐）或统一节点 **`Feishu Suite`**
4. Agent 能看到中文操作名：新增记录、查询记录、列出字段、上传附件、解析多维表格链接等
5. 在 Agent **System** 里写死下面几条（与 e2e / 配方一致，防止模型乱猜）

## System 必写

- 先 **列出字段** 或 **解析多维表格链接**，再写记录
- 记录 JSON 的键用**字段名称**，不是 `field_id`
- 日期可用 `YYYY-MM-DD`（按上海时区转毫秒）或 Unix 毫秒
- **不要猜** `app_token` / `table_id`：让用户给多维表格链接，或用节点选择器
- 公式（type 20）、查找引用（type 19）**只读**，不要写
- 人员单元格需要真实 `open_id`，且应用通讯录数据范围够；不够会 `40004`，不是缺 `bitable:app`
- 附件必须先 **上传附件到多维表格** 再写入 `file_token`，不要塞外部 URL
- 超链接可写裸 URL；地理位置写 `"经度,纬度"`
- 批量超过 500 条交给节点拆批，不要自己发明分页协议
- 不要对真实业务群群发、不要提交审批、不要对外发邮件

## 不要做的事

- 配方只写了把 **Feishu Suite Base**（或统一节点）挂到 Tools；PoC 不要让模型猜该调哪个模块
- 不要让模型编造 `field_id` 当 JSON 键
- 不要让模型创建查找引用字段（本租户 `99992402 field validation failed`）
