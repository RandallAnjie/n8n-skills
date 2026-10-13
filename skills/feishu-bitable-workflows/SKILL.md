---
name: feishu-bitable-workflows
description: >-
  Use when building Feishu Bitable / 多维表格 workflows in n8n: app_token/table_id,
  webhook create, scheduled query+notify, upsert, batch >500, field write formats.
  在 n8n 里搭飞书多维表格工作流时使用：从链接拿 app_token/table_id、
  webhook 新增记录、定时查询通知、按业务键 upsert、批量超过 500、
  各字段写入格式（日期毫秒 Asia/Shanghai、人员、关联、附件、地理位置、超链接）。
  不要用它来配 Trigger 或 AI Agent（见 feishu-bitable-trigger / feishu-bitable-ai-agent）。
---

# 多维表格工作流

节点：`Feishu Suite` 资源选 **Base**，或 `Feishu Suite Base`。依据：[BITABLE_RECIPES.md](../../docs/BITABLE_RECIPES.md)、[E2E_REPORT.md](../../docs/E2E_REPORT.md)。0.1.5 主路径 e2e **PASS**。

官方：[字段概述](https://open.feishu.cn/document/server-docs/docs/bitable-v1/app-table-field/guide)、[新增记录](https://open.feishu.cn/document/server-docs/docs/bitable-v1/app-table-record/create)、[查询记录](https://open.feishu.cn/document/docs/bitable-v1/app-table-record/search)、[批量新增](https://open.feishu.cn/document/server-docs/docs/bitable-v1/app-table-record/batch_create)。

## 拿 app_token / table_id

不要手猜。任选：

1. 节点上的**多维表格 / 数据表列表选择器**
2. 操作 **解析多维表格链接**（e2e：App parse URL PASS）
3. AI / 人工先 **列出字段** 再写记录

选择器：`searchTableFields` 返回 **field_id**（删除/更新字段）；`searchTableFieldNames` 返回 **字段名称**（search / filter / upsert / 记录 JSON）。列表显示「名称 · 类型 (field_id)」。

**记录 JSON 的键必须是字段名称，不是 field_id。**

## 配方 1：Webhook → 新增记录

1. n8n `Webhook` 接表单 / 上游事件（e2e：`parseWebhook` 需要父级 n8n Webhook；`Feishu Suite Webhook Trigger` 的 `url_verification` 在本环境 `/webhook/{id}` 404，**未跑通**，PoC 用自带 Webhook）
2. `Feishu Suite Base` → **新增记录**，表用选择器
3. 请求体示例：

```json
{"fields":{"Name":"{{$json.name}}","Amount":{{$json.amount}},"Due":"{{$json.dueDate}}","Website":"{{$json.url}}"}}
```

- `Due`：Unix 毫秒，或 `2026-10-12`（节点按 **Asia/Shanghai** 转毫秒）
- `Website`：可写裸 `https://…`（自动转 `{text,link}`）
- 可选：把返回的 `record_id` 发到**机器人自己建的群**。不要对真实业务群群发（e2e 将此类标为 SKIPPED-unsafe）

## 配方 2：定时 → 查询 → 通知

1. `Schedule Trigger`
2. **查询记录**：`whether_paging=false` 让节点自动翻页；`true` 时自己拿 `page_token`
3. `body.filter` / `sort` 用**字段名**：

```json
{
  "automatic_fields": false,
  "field_names": ["Name", "Status", "Due"],
  "sort": [{"field_name": "Due", "desc": false}],
  "filter": {
    "conjunction": "and",
    "conditions": [
      {"field_name": "Status", "operator": "is", "value": ["Doing"]}
    ]
  }
}
```

4. 有结果再发消息 / 建任务；空结果用 IF 停掉

## 配方 3：Upsert（按业务键更新或新建）

操作 **更新或新建记录**（e2e PASS）：

- 匹配字段名称 = **字段名称**选择器（不要填 field_id）
- 匹配字段值 = 业务主键
- Fields JSON = 要写入的整行

内部：search（`is`）再 PUT 或 POST。同一工单不要插两条时用这个。

## 配方 4：批量 > 500

- 官方单次最多 **500** 条（超了飞书 `1254104 RecordAddOnceExceedLimit`）
- 节点对批量新增 / 更新 / 删除会**自动拆批**（e2e：batch create **501** PASS）
- 请求：`{"records":[{"fields":{...}}, ...]}`
- 也可自己 100～200 一批，靠重试扛 `1254290` / `1254291` / HTTP 429
- 写同一张表不要并行多个写接口（会 `1254291` 写冲突）
- 官方新增记录大约 50 次/秒

## 字段怎么写

| UI | type | 写入值 | 节点会自动转 |
| --- | --- | --- | --- |
| 文本 | 1 | 字符串 | |
| 数字 | 2 | number | |
| 单选 | 3 | 选项名字符串 | |
| 多选 | 4 | 选项名数组 | |
| 日期 | 5 | Unix 毫秒 | `2026-10-12` / `2026-10-12 18:00:00` / ISO → **Asia/Shanghai** 毫秒 |
| 复选框 | 7 | boolean | `"true"` / `"false"` |
| 人员 | 11 | `[{ "id": "<open_id>" }]` | 裸 `ou_` / `on_` |
| 电话 | 13 | 字符串 | |
| 超链接 | 15 | `{ "text": "...", "link": "https://..." }` | 裸 URL |
| 附件 | 17 | `[{ "file_token": "boxcn..." }]` | 先上传，见下 |
| 单向关联 | 18 | `["recXXX"]` | 裸 `rec…` |
| 查找引用 | 19 | **只读** | 不要写 |
| 公式 | 20 | **只读** | 创建字段时用 `property.formula_expression`；e2e 在改 Amount 后回读公式 PASS |
| 双向关联 | 21 | `["recXXX"]` | 创建字段要 `property.table_id` + `back_field_name` |
| 地理位置 | 22 | `"116.397755,39.903179"`（经度,纬度） | 带空格的坐标串 |

e2e 还写过：URL `{text,link}`、日期毫秒、单向关联 + 关联表行、地理位置、附件上传后写入记录。

创建单向/双向关联字段必须带对端 `table_id`。查找引用（type 19）本租户创建字段报 `99992402 field validation failed`；表里已有该列时用「获取记录 / 查询记录」只读。

人员单元格写入需要通讯录**数据范围**，缺了是 `40004`，不是缺 `bitable:app`。人员**字段**创建 e2e PASS。

创建多维表格时可在 Options 设 `time_zone`（e2e 用 `Asia/Shanghai`）。高级权限角色接口前须 `updateApp` 打开 `is_advanced`，否则 `1254301`。

## 附件上传 / 下载（e2e PASS）

1. 上游产出二进制（HTTP Request、表单、Code）
2. `Feishu Suite Base` → **上传附件到多维表格**（走 `parent_type=bitable_file`）
   - 多维表格 / 数据表用选择器
   - 二进制字段默认 `data`
   - Options：勾选「写入记录」，填 `record_id` + 附件字段名称（如 `Files`）
3. **下载多维表格附件**：`file_token` 来自上传结果或记录里的附件字段

不要把外部 URL 直接塞进附件字段。文件必须属于当前 Base，否则 `1254303` / `1254069`。
