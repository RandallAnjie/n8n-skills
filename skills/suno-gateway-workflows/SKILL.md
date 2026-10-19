---
name: suno-gateway-workflows
description: >-
  Use when building n8n workflows with Suno Gateway v3: generate a song,
  persona+cover, async submit+poll, download audio, or n8n binary as source.
  用 Suno Gateway 搭生成歌曲、persona 翻唱、异步轮询、下载音频、n8n 二进制当来源时使用。
  触发词：Generation Create、Cover、Wait Until Complete、coverPersonaId、
  studio/arrangements、Job Get、Clip Download、download_url、sourceMode binary、翻唱、变调。
  不要用它来第一次装节点（见 suno-gateway-setup）或解读报错（见 suno-gateway-troubleshooting）。
---

# Suno Gateway 常用配方

节点：`Suno Gateway`，包 0.4.0，**API Version = v3**。凭证 **Suno Gateway API**。参数名以节点表单为准，body 字段是括号里的官方名。

依据：0.4.0 源码（`SunoGateway.node.js` / `operations.js` / `client.js`）和内部示例工作流「Suno 音色翻唱 persona+cover（v3）」。装节点见 `suno-gateway-setup`。

## 非协商

1. **只写节点上真实存在的 resource / operation / 参数。** 表单没有的官方字段走 **Additional Body (JSON)**（`additionalJson`，官方名如 `duration`、`audio_refs`）或 **Raw Request**。
2. **创作类默认 Wait Until Complete**（`wait`，默认 true，`timeoutMs` 900000，`pollIntervalMs` 2000，最小 250）。关掉 wait 只返回 202 信封 `{ id, job_id, status: "queued", poll }`，后面必须自己轮询。
3. **v3 job 不要用 Job → Wait。** 用 Job → Get + Wait 节点循环，或在创作节点上开 Wait Until Complete。原因见 `suno-gateway-troubleshooting`（0.4.0 源码：Job Wait 固定 `/v2`）。
4. **Raw Request 不轮询、不附 account_id。** 要固定账号就写在 `rawPath`：`/v3/...?account_id=`。
5. **v3 Clip Download 永远返回 JSON**（含 `download_url`），不返回二进制。要文件再 HTTP Request 拉这个 URL。

## 决策

| 要做的事 | 配方 |
| --- | --- |
| 一句描述 / 自定义歌词出歌 | 1 |
| persona 翻唱，可能先变调 | 2 |
| 提交后自己轮询（Cover 往往 2-14 分钟） | 3（配方 2 的后半也是这条） |
| 把 clip 变成 n8n 文件，再给飞书 | 4 |
| 上游已经是 n8n 二进制 | 5 |
| 第一次装节点 / 凭证 | `suno-gateway-setup` |
| 报错 | `suno-gateway-troubleshooting` |

## 配方 1：生成歌曲（Generation Create）

1. `Suno Gateway`，Resource **Generation**，Operation **Create**（默认）
2. API Version **v3**
3. **Mode：** Custom Lyrics（`custom`，发 `lyrics`）或 Simple Description（`simple`，**不发** `lyrics`）
4. 填 `lyrics` / `description` / `style` / `negativeStyle`（`negative_style`）/ `title` / `instrumental`
5. **Wait Until Complete** 开着。Cover 级耗时少见，仍把超时留够
6. 常用默认：`isMaxMode` true（`is_max_mode`）、`augCreativity` 0（Variety 0-4）、`usePersonalization` false、`vocalGender` 空/`f`/`m`

v3 下 Generation / Sounds **不要求**音频。Source 选择器对 Generation 不出现。

`styleWeight` / `weirdness` 默认 `-1` 表示不发。要发就写 0-1（Styles Influence 65% = `0.65`）。

## 配方 2：persona + cover 翻唱

示例工作流：飞书认领 → 组装 persona/账号/三滑块/源类型 → 按需 `upload` → `arrange` → `cover` → 配方 3 轮询 → 配方 4 下载。未自动化：persona 提取/存 Voice（要人工试听截取）、成品试听。

源类型三种（从链接正则抽出 id）：

| 源 | 何时 upload | 何时 arrange |
| --- | --- | --- |
| 音频直链 | 需要变调时 | 变调或还原降速时 |
| Suno clip_id（`song/<uuid>`） | 否 | 同上 |
| Suno 工程版本 ID（`project_version_id=`） | 否 | 总是（用 `project_version_id`） |

变调半音 `transpose` -24..24。素材已降速：`0.5x` → transpose +12 且 `speed: 2`；`0.25x` → +24 且 `speed: 4`。总变调不能超出 ±24。

三个提交节点都 `wait=false`，`onError=continueRegularOutput`，`retryOnFail` 3 次 / 5s。Code 统一取 `id` / `job_id`，没有 id 就报「网关拒绝或请求失败，见执行 N」。

### 2a. Upload（仅直链且要变调）

| 参数 | 值 |
| --- | --- |
| resource | `upload` |
| accountId | 固定池账号；空=网关自选 |
| audioUrl | 直链 |
| wait | `false` |
| title | 可选 |

v3 + Public URL：`POST /v3/uploads`，JSON `{url,filename,title,priority,bypass_copyright}`。`bypassCopyright` 默认 true。

### 2b. Arrange：必须 Raw Request

Studio Arrange 的 Tempo 下拉在 0.4.0 **可能不生效**（`collectCreateParams` 里 `tempo` 键写了两次，Sounds 的数字 `tempo` 默认 0 覆盖了 `arrangementTempo`）。示例因此走 Raw：

| 参数 | 值 |
| --- | --- |
| resource | `raw` |
| rawMethod | `POST` |
| rawPath | `/v3/studio/arrangements?account_id={{ $json.account }}`（无账号就不要 query） |
| additionalJson | `{{ JSON.stringify($json.req.body) }}` |

body 形状（官方字段名）：

```json
{
  "tempo": "original",
  "transpose": 12,
  "speed": 2,
  "export": true,
  "title": "曲名 变调+12",
  "source_clip_id": "<clip 或上一步 upload 的 clip>"
}
```

工程版本源改用 `project_version_id`，不要和 `source_clip_id` / `project_id` 混用。`export: true` 才会出可轮询的导出 job。`tempo` 取值 `original` / `on_beat`（On Beat 才需要 bpm 15-720）。

上一步 clip：状态机在 `url` / `source_clip_id` / `project_version_id` 都空时，把上一 job 的 clip 填进 `source_clip_id`。

### 2c. Cover

| 参数 | 值 |
| --- | --- |
| resource | `cover` |
| accountId | 池账号 |
| coverPersonaId | persona_id。翻唱在 persona 所在账号跑，并导入源 clip |
| lyrics / style / title | 歌词、风格、标题。style 空就不传 |
| vocalGender | `''` / `f` / `m` |
| styleWeight | Style Influence，0-1 |
| audioWeight | Audio Influence，0-1（仅 cover 等有源音频的操作） |
| weirdness | Weirdness，0-1 |
| augCreativity | `0`（示例关掉 Variety） |
| sourceMode | 有直链用 `url`，否则 `clip` |
| audioUrl | 直链；clip 模式留空 |
| sourceClipId | **clip 模式必填**。构建脚本有这一项；一份缓存导出里没看到，漏填会没有源 |
| wait | `false` |

`sourceMode` 表达式示例：`={{ $json.req.body.url ? 'url' : 'clip' }}`。clip 模式同时写 `sourceClipId`：`={{ $json.req.body.source_clip_id || '' }}`。v3 下 sourceMode 为 url/binary/urls 时 Source Clip ID 表单是隐藏的，改成 clip 才会出现。

三滑块必须在 0-1。15% 写 `0.15`，不要写 `15`。

## 配方 3：异步提交 + 轮询

1. 创作节点 `wait=false` → 202 信封
2. **Wait** 20s（示例；Cover 总时长仍可能 2-14 分钟）
3. `Suno Gateway` Resource **Job**，Operation **Get**，`jobId` = 提交结果的 `id`（不要用 Job → Wait）
4. Code：`status` 为 `complete` / `error` / `rejected`，或 `poll.complete`。error/rejected 当失败（节点在 wait=true 时会抛 `Gateway job … error: …`；wait=false 时要自己判）
5. 未完成 → 回到步骤 2。示例把 >40 分钟当超时
6. complete 时：cover 取 `clips[].id` 和 `account_id`；upload/arrange 取 clip id

Job Get 就是 `GET /v3/jobs/{id}`，它自己的 `wait` 开关对 Get **无效**（源码 Get 分支不读 wait）。

## 配方 4：下载音频

v3 **Clip → Download**（`downloadFormat`：`mp3` / `wav` / `m4a`，默认 mp3）只返回 JSON。`downloadAs=Audio File` 仅 v1/v2，v3 没有这个选项。

示例不用 Clip Download，改 HTTP Request + 预定义凭证 `sunoGatewayApi`：

1. `GET {baseUrl}/v3/clips/{clip}/download?format=wav&account_id=…`，打开 fullResponse，neverError
2. 200 且 `body.download_url` 才继续
3. **409**（未就绪）：每 30s 重试。wav 大约 10 分钟预算，之后依次降级 **mp3 / m4a / aac**（各约 2 分钟）。节点下拉没有 `aac`，要试 aac 只能 HTTP Request
4. 第二个 HTTP Request 拉 `download_url` 为文件（`responseFormat=file`，timeout 300s）
5. 查文件头：`RIFF`+`WAVE` = wav；`ftyp` = m4a；`ID3` / 帧同步 = mp3 或 aac。`<20000` 字节当异常
6. 二进制可接飞书：≤20MB `Feishu Suite Space` `uploadFile`（`files/upload_all`），>20MB `chunkUploadFile`，再把 `[{file_token}]` 写入附件字段。见 `feishu-bitable-workflows`

也可以先 Clip Download 拿 JSON，再用 HTTP Request 拉 `download_url`。两条路 v3 都不会直接出音频二进制。

## 配方 5：n8n 二进制当来源（`sourceMode=binary`）

v3 选项 **Source**：Public URL（`url`，默认）/ n8n Binary File（`binary`）/ Clip ID（`clip`）/ Public URLs（`urls`，仅 Inspiration / Mashup / Sample）。

`binary`：节点用 `binaryPropertyName`（默认 `data`）读字节，**multipart POST `/v2/uploads`** 并等待完成，取 clip id，再当 `source_clip_id` 调 v3。v3 接口不收 multipart。

适用 Cover / Extension / Upload / Studio 等（Generation 无此选择器）。缺二进制会抛 `No binary data on property "…"`。

Public URL：`audioUrl` → `body.url`（可选 `filename`）。缺 URL 且不是 Generation/Sounds：`Audio URL is required when Source is Public URL`。

## 其它资源（一行一个）

| Resource | 做什么 |
| --- | --- |
| Voice | Create Persona（`personaName` 必填，`vocalStartS`/`vocalEndS` 干声秒）；Generate（`personaId` 必填。v3 不能用 url/binary/urls，会报 Voice generate uses a persona_id…） |
| Persona | Generate（`personaId` 必填） |
| Stem | Create：`stemTask` `two`/`extract`/`remove`，`stemName` |
| Edit | instrumental / vocal / section / concat / reverse / speed / fade / crop。section/crop 用 `startS`/`endS`；fade 用 `fadeInS`/`fadeOutS`；speed 用 `speed`→`speed_multiplier` |
| Studio | list / createProject / getProject / saveProject / exportMix；v3：getProjectVersion / cloneProjectVersion / arrange。Arrange 的 Tempo 用配方 2b，不要用节点下拉 |
| Lyrics | Generate / Get / listProjects（v3 或 v2 `/lyrics`） |
| Extension | Create，`continueAt`（秒） |
| Inspiration | Create，1-4 clips；可用 Public URLs |
| Mashup | Create，2-4 clips；**v1 不可用** |
| Sample | Create，`chop`/`blend`，`sampleStartS`/`sampleEndS` |
| Sounds | Create，`one-shot`/`loop`，`tempo`/`key`；**v1 不可用**；v3 不要求音频 |
| Remaster | Create。不带 `async`/`priority` |
| Upload | 见配方 2a / 5 |
| Clip | Get / Wait / Download / lyrics / sections / stems / similar / react / update / delete |
| Job | List / Get / Wait（Wait 见排错：不要用来等 v3 job） |
| Account | List / Get / listClips / Sync / Login / loginStatus / submitLoginCode / completeLogin / update / Delete。`accountId` 空时用 `default` |
| Me | Get `GET {p}/me` |
| Playlist | List / Create / Get / addTracks / removeTracks |
| Style | upsample / suggestions / listSaved / save / deleteSaved |
| Catalog | search / suggest / discover（home/explore）/ feed / voices / coverArt / hooks / billing |
| Custom Model | List / Create / Archive |
| Audit | Usage：`from`/`to`/`account_id` |
| Raw Request | 任意 GET/POST/PATCH/DELETE `{baseUrl}{rawPath}`，body = Additional Body。不轮询、不加 account_id |

不带 `async`/`priority` 的严格操作：`remaster.create`、`voice.createPersona`、`studio.createProject`、`edit.concat/reverse/speed/fade/crop`。

`priority`：`high`/`normal`/`low`，默认 `normal`。`accountId` 空=网关自选，发 query `account_id`。

## 不要做

- clip 模式只改 `sourceMode` 不填 Source Clip ID
- 用 Studio Arrange 节点设 Tempo（下拉会被 0 覆盖）；要用 Raw Request
- 用 Job → Wait 等 v3 job
- 以为 v3 Clip Download 会给出 `binary.data`
- 把 65 当成 Style Weight（应为 0.65）
- Raw Request 的 path 不写 `account_id` 却指望节点自动带上
- Public URLs 用在 Cover 上（只给 Inspiration / Mashup / Sample）
- Voice Generate 选 Public URL / Binary（必须已有 persona_id）
