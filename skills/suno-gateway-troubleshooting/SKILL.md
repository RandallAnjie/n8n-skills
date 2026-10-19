---
name: suno-gateway-troubleshooting
description: >-
  Use when a Suno Gateway n8n node errors: ECONNRESET, node not installed,
  401/403, timeout, job error/rejected, 409 download, Audio URL required,
  Voice generate persona_id, Public URLs, missing binary, invalid Additional Body JSON,
  Job Wait polling /v2, Arrange Tempo ignored. n8n Suno Gateway 报错时使用。
  触发词：节点未安装、/healthz、timeoutMs、download_url 409、0.4.0 源码行为、baseUrl。
  先对照本文再改工作流，不要编造新的错误含义。
---

# Suno Gateway 排错

只收录 0.4.0 源码会抛的文案、节点/凭证行为、以及示例工作流里见过的 HTTP 状态。包 0.4.0，节点 version 3。文档：http://20.127.149.181:3000/docs 、`/docs/v2` 、`/docs/v3`。

装错/凭证见 `suno-gateway-setup`。配方见 `suno-gateway-workflows`。

先把 **HTTP 状态 / 节点 Error.message / job.status / job.error** 原样抄下来。

## 对照表

| 现象 | 含义 | 做法 |
| --- | --- | --- |
| `ECONNRESET` / 连不上 | 多半是 **baseUrl 错** | 必须 `http://20.127.149.181:3000`。不要 `https`，不要带 `/v3`、`/docs`、尾斜杠路径。节点去掉末尾 `/` 再拼 `/v3/...` |
| 「节点未安装」/ Install this node | 旧 **typeVersion 1**。0.4.0 只有 version 3 | 删除节点重新拖，变成 v3，重填参数和凭证。v2 存档仍可运行 |
| Test 绿、执行 401/403 | Test 只打公开 **`GET /healthz`，不校验 key** | 核对 `apiKey`（头 `X-API-Key` = 网关 `GATEWAY_API_KEY`）。Test 通过不代表 key 对 |
| Cover / 创作一直转到超时 | Cover 常要 **2-14 分钟**。`timeoutMs` 默认 900000 | 把 Wait Timeout 留够；或 `wait=false` 走 Job Get 循环（示例 >40 分钟才算超时） |
| `Gateway job {id} error: …` / `rejected` | job 完成态是 `complete` / `error` / `rejected`。后两个节点在 wait=true 时抛错 | 读 `job.error`。wait=false 时自己判 status，不要当成功 |
| `Gateway job {id} did not complete within {ms}ms` | 轮询用尽 `timeoutMs` | 加超时，或改异步轮询 |
| 下载 409 | clip 音频 **还没就绪** | 示例：每 30s 重试；wav 约 10 分钟，再降级 mp3/m4a/aac |
| `Audio URL is required when Source is Public URL` | v3 `sourceMode=url` 且没填 `audioUrl`。Generation / Sounds 除外 | 填公网直链，或改 Source 为 Clip ID / Binary |
| `Voice generate uses a persona_id. Save the Voice from a generated song first.` | v3 Voice **Generate** 不能用 url/binary/urls | 先人工出歌、存 Voice，用 `personaId` 再 Generate |
| `Public URLs is for Inspiration, Mashup, and Sample. Use Public URL for one file.` | `sourceMode=urls` 用在了别的 resource | 多条 URL 只给 Inspo/Mashup/Sample；单文件用 Public URL |
| `Audio URLs are required when Source is Public URLs` | `urls` 模式但 `audioUrls` 空 | 换行或逗号填多条 http(s) |
| `No binary data on property "…"` | `sourceMode=binary`（或 v1/v2 Upload）却没有该二进制字段 | `binaryPropertyName` 默认 `data`，对上上游字段名 |
| `Additional Body (JSON) is not valid JSON` | `additionalJson` 解析失败 | 必须是 JSON 对象。表达式用 `{{ JSON.stringify(...) }}`，不要当普通字符串 |
| `{resource}.{operation} is not available on this API version` | 如 Mashup/Sounds 在 v1；Arrange 等在非 v3 | 把 API Version 换成代码支持的版本 |
| `Arrange needs a Project ID, Project Version ID, or Library Clip ID` | 三个源都空 | 三选一，不要混用 |
| `Binary upload finished without a clip id` | `/v2/uploads` 结束但没解析到 clip | 看 upload job 的 `clips[]` / `clip_id` |
| HTTP 请求 120s 就断，job 还在跑 | `client.js` 单次 HTTP **timeout 120s**，不是 `timeoutMs` | 创作用节点内轮询；下载用 HTTP Request 自己把 timeout 拉到 300s |

## 0.4.0 源码行为（不是网关文档写错那么简单）

1. **Job → Wait 永远轮询 `/v2/jobs/{id}`。** `runJob` 调 `pollJob` 时没传 `version`，`pollJob` 默认 version=2。v3 job 请用 **Job → Get** + Wait 循环（示例工作流就是这样），或在创作节点开 Wait Until Complete（那条路径会把 version 传进去，v3 轮询 `/v3/jobs/{id}`）。
2. **Studio Arrange 的 Tempo 下拉可能不生效。** `collectCreateParams` 里 `tempo` 写了两次：先取 `arrangementTempo`（`''`/`original`/`on_beat`），后取 Sounds 的数字 `tempo`（默认 **0**）。后者覆盖前者，`buildArrangementBody` 里 `if (p.tempo)` 把 0 当成假值，**body 不带 tempo**。示例用 Raw Request `POST /v3/studio/arrangements` 发 `{tempo:'original',transpose,speed,export:true,…}`。
3. **Raw Request 不自动轮询，也不附加 `account_id`。** 账号写进 `rawPath` 的 `?account_id=`，完成态用 Job → Get。
4. **凭证 Test 只打 `/healthz`。** key 错也会绿。真错在执行 401/403。
5. **README 写默认 v2、文档链到 `/docs/v3`。** 代码里新节点 `apiVersion` default 是 **`'3'`**。以代码为准。

## 下载未就绪（409）

v3 下载接口在文件没准备好时给 409。示例：HTTP Request fullResponse + neverError，200 且 `download_url` 才拉文件。节点 Clip Download 没有 409 重试逻辑，要重试就自己循环，或先 Clip Get/Wait 再 Download。

节点 `downloadFormat` 只有 `mp3`/`wav`/`m4a`。示例额外试 `aac` 是 HTTP Request 写的 query，不是节点选项。

v3 即使选 Download 也只拿到 JSON，不会出现 `binary.data`。

## wait=false 时的形状

创作类返回 202 信封。`id` 或 `job_id` 拿去 Job Get。`poll.complete` 为真也算完。Code 不要只看 HTTP 200。

三个提交节点若 `onError=continueRegularOutput`，失败时下游可能仍是输入项（带 `req`、没有新 `id`）。示例用「有 `id` 且没有 `req`」区分成功。

## 不要做

- 给 baseUrl 加 `https` 或路径来「更安全」
- 看见凭证 Test 通过就去改工作流别的地方
- 用 Job → Wait 等 v3 任务，失败了还怀疑网关路径
- 把 Arrange Tempo 下拉再试一遍当修复（源码会盖掉）
- 对 `error`/`rejected` 的 job 无脑重试同一参数
- 把 409 当永久失败（先按未就绪重试）
- 手改 typeVersion 1 → 3 而不重填参数
