---
name: suno-gateway-setup
description: >-
  Use when installing n8n-nodes-suno-gateway 0.4.0, adding Suno Gateway API
  credentials, or fixing typeVersion 1 nodes that show as not installed.
  安装 Suno Gateway 社区节点、配凭证、旧节点显示「节点未安装」时使用。
  覆盖：内部集群共享目录、自建 tgz/GitHub/Docker/N8N_CUSTOM_EXTENSIONS、
  Suno Gateway API（baseUrl + X-API-Key）、Test 只打 /healthz、v1 → v3 迁移。
  不要用它来写生成/翻唱配方（见 suno-gateway-workflows）或排错（见 suno-gateway-troubleshooting）。
---

# Suno Gateway 安装与凭证

对象：期音 PoC / 生产同事。包 `n8n-nodes-suno-gateway` **0.4.0**，节点 **version 3**（只有 3，不是 `[1,2,3]`）。类型 `n8n-nodes-suno-gateway.sunoGateway`，显示名 **Suno Gateway**。`usableAsTool: true`。

GitHub `RandallAnjie/n8n-nodes-suno-gateway` 的 main 可能仍是 0.3.0。以 **0.4.0 / 节点 v3** 为准。

## 非协商

1. **内部集群同事不要自己装。** 共享包在 `/app/n8n/n8n-data/nodes`，由服务器管理员安装。不要从 **Settings → Community nodes** 装：包不在公开 npm。
2. **凭证走 n8n 凭证系统。** 类型 **Suno Gateway API**（`sunoGatewayApi`）。apiKey 不要写进 HTTP 头文本或工作流 JSON。认证头是 `X-API-Key`。
3. **baseUrl 只能是 origin。** 默认 `http://20.127.149.181:3000`。节点去掉末尾 `/` 再拼 `/v3/...`。不要 `https`，不要带 `/v3`、`/docs` 等路径。
4. **「节点未安装」= 旧 typeVersion 1。** 删除节点，重新拖一个（变成 v3），重填参数和凭证。不要手改导出 JSON 里的 version。

## 决策

| 场景 | 去做 |
| --- | --- |
| 内部 n8n 集群 | 问管理员是否已装 0.4.0；自己不装 |
| 自建机器 | 下面「自建安装」 |
| 第一次凭证 | 「凭证」 |
| 画布显示节点未安装 / Install this node | 「v1 → v3」 |
| 写生成、翻唱、下载 | `suno-gateway-workflows` |
| ECONNRESET / 401 / 超时 | `suno-gateway-troubleshooting` |

## 内部集群

`N8N_USER_FOLDER` 等价于 `/app/n8n/n8n-data`，社区节点目录是 `$N8N_USER_FOLDER/nodes`。管理员在该目录 `npm install` 0.4.0 包后重启 n8n。画布搜索 **Suno Gateway**。

## 自建安装

不要用 Settings → Community nodes。

**tgz 离线包**（Release 附件 `n8n-nodes-suno-gateway-0.4.0.tgz`）：

```bash
mkdir -p ~/.n8n/nodes
cd ~/.n8n/nodes
npm install /path/to/n8n-nodes-suno-gateway-0.4.0.tgz
```

改过 `N8N_USER_FOLDER` 时，目录是 `$N8N_USER_FOLDER/nodes`。

**私有 GitHub**（机器要能 clone `RandallAnjie/n8n-nodes-suno-gateway`）：

```bash
mkdir -p ~/.n8n/nodes
cd ~/.n8n/nodes
npm install git+https://github.com/RandallAnjie/n8n-nodes-suno-gateway.git
```

确认装到的是 **0.4.0**，不是仍停在 0.3.0 的 main。

**Docker：** 把 tgz 挂进容器后：

```bash
docker exec -u node -it <n8n容器> sh -c 'mkdir -p ~/.n8n/nodes && cd ~/.n8n/nodes && npm install /data/n8n-nodes-suno-gateway-0.4.0.tgz'
```

**`N8N_CUSTOM_EXTENSIONS`：** 目录里要有包的 `package.json`、`nodes/`、`credentials/`，然后重启。

n8n 装在你的机器上。网关继续跑在 `http://20.127.149.181:3000`，这台机器能访问即可。不要把 n8n 装到网关那台 Windows 上。`Account → Login` 仍在**网关那台 Windows** 开 Chrome。

## 凭证

Credentials → 新建 **Suno Gateway API**：

| 字段 | name | 值 |
| --- | --- | --- |
| Base URL | `baseUrl` | `http://20.127.149.181:3000` |
| API Key | `apiKey`（password，必填） | 网关 `GATEWAY_API_KEY` |

**Test** 发 `GET {baseUrl}/healthz`。这是公开探活，**不校验 key**。Test 通过只说明网关活着。key 错会在执行时 401/403。

HTTP 请求默认超时 **120s**（`client.js`）。创作等待用节点的 `timeoutMs`（默认 15 分钟），两套不是一回事。

## 版本

- 新拖的节点：**API Version = v3**（属性 default `'3'`）。包 README 写「默认 v2」，与代码不符，以代码为准。
- v3：JSON body，不发 `async` / `wait` / `count`；有 `priority` 就发。轮询 `GET /v3/jobs/{id}`。
- v2 存档仍可运行：`/v2` + `async: true`，轮询 `/v2/jobs/{id}`。
- v1 的 `wait=true` 可能 HTTP 102；节点把 102 + `X-Request-Id` 转成 job 再轮询 `/v2/jobs`。
- 文档：http://20.127.149.181:3000/docs 、`/docs/v2` 、`/docs/v3`

## v1 → v3

0.4.0 的 `description.version = 3`（标量，不是数组）。旧工作流里 **typeVersion 1** 的节点显示「节点未安装」/ Install this node。

1. 删掉该节点（记下 resource / operation / 表达式）
2. 再拖一个 **Suno Gateway**，此时是 v3
3. 重填参数，重新绑 **Suno Gateway API** 凭证
4. v2 节点不用迁，存档继续跑

## 不要做

- 普通同事在内部集群从 Community nodes 或自己 `npm install`
- baseUrl 写成 `https://20.127.149.181:3000` 或 `http://20.127.149.181:3000/v3`
- 把 apiKey 写进 HTTP Request 头或 Sticky Note
- 看见 Test 绿勾就认定 key 正确
- 把 GitHub main 的 0.3.0 README 当 0.4.0 行为
