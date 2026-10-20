# PoC starter patterns

Lift the shape. Don't copy the official examples wholesale: `n8n-agents-official` `references/examples/agent-core.json` and `slack-router.json` are the production split (shell + core + specialists). `n8n-error-handling-official` `references/examples/validation-subworkflow.ts` is the production schema validator. Both are the graduation path, not the scaffold.

Param names are version-dependent. `get_node_types` is canonical before you configure anything.

## 1. Inbound → AI → reply

**When:** "summarize this form", "an API that classifies a payload", "webhook that replies with AI".

```
Form Trigger  →  Agent or Basic LLM Chain  →  Form Ending
Webhook       →  Agent or Basic LLM Chain  →  last node is the HTTP body
```

| Node | PoC default |
|---|---|
| Form Trigger (`n8n-nodes-base.formTrigger`) | One page. `Respond When`: Workflow Finishes so the model output can show. **Do not add Respond to Webhook.** Form owns the response. |
| Form Ending (`n8n-nodes-base.form`) | Completion text or HTML from `$('Agent').item.json.output` (or the chain's text field). Confirm the output key via `get_node_types`. |
| Webhook (`n8n-nodes-base.webhook`) | POST. Path: descriptive + short unique suffix (paths are instance-global). `responseMode: 'lastNode'`. Switch to `responseNode` + Respond to Webhook only if they need a non-200 or a specific JSON envelope. |
| Model step | Basic LLM Chain (`@n8n/n8n-nodes-langchain.chainLlm`) + a chat-model sub-node if one-shot text. Agent (`@n8n/n8n-nodes-langchain.agent`) if they said tools, chat, or "agent". |
| Structured JSON out | `outputParserStructured` + `autoFix: true`. Without autoFix the demo flakes on one bad parse. See `n8n-agents-official` `references/STRUCTURED_OUTPUT.md`. |

**Read:** `n8n-agents-official` (agent vs chain vs Text Classifier), `n8n-node-configuration-official` `references/AI_NODES.md` (streaming, iteration cap), `references/WEBHOOK_NODES.md` (`responseMode`, unique paths), `n8n-workflow-lifecycle-official` `references/TESTING.md` (pin shapes: webhook `{headers, params, query, body}`; chat `{chatInput, sessionId, files}`).

**Pin:** the model/agent if no LLM cred. The webhook/form trigger always. Demo: Form test URL, webhook test URL + curl, or `test_workflow`.

**Don't:** the validation IIFE in `n8n-error-handling-official` `references/examples/validation-subworkflow.ts`. That's a graduate add.

## 2. Schedule → fetch → transform → notify

**When:** "every morning email me the headlines", "poll an API and Slack it".

```
Schedule Trigger  →  HTTP Request or native node  →  (expression on the notify node)  →  Slack / Gmail / Discord
```

| Node | PoC default |
|---|---|
| Schedule (`n8n-nodes-base.scheduleTrigger`) | Simple interval (`field: 'minutes'`/`'hours'`/`'days'`), not cron. Timezone is the **workflow** setting, not a field on the rule. See `n8n-node-configuration-official` `references/TRIGGER_NODES.md`. |
| Fetch | Native node if one exists. Else HTTP Request. Auth via credential, never header text. See `references/HTTP_NODES.md` and `n8n-credentials-and-security-official` `references/HTTP_REQUEST_WITH_AUTH.md`. |
| Transform | Expression in the notify node's text/body slot. Edit Fields only if 2+ consumers need the same derived value. See `n8n-expressions-official`. |
| Notify | Slack `operation: 'post'` (display name is "Send a message"). Strip n8n attribution. See `n8n-node-configuration-official` `references/COMMS_NODES.md`. |

**Pin:** HTTP Request and the notify node when creds are missing. Show the shaped payload as the demo. `test_workflow` already pins both if they have credentials, so a watched demo does not send.

**Don't:** publish a noisy schedule without asking. Don't add pagination (`n8n-loops-official` `references/HTTP_PAGINATION.md`) until the first page isn't enough for the demo. Don't add an error workflow.

## 3. Chat → agent + one tool

**When:** "a chat assistant that can look X up", "canvas chat that calls an API".

```
Chat Trigger (`availableInChat: true`)  →  Agent
                                           ├ model
                                           ├ memory (optional)
                                           └ one tool (native tool node or HTTP Request Tool)
```

| Piece | PoC default |
|---|---|
| Chat Trigger (`@n8n/n8n-nodes-langchain.chatTrigger`) | `availableInChat: true`. Demo in the canvas chat tester. Input is `{ chatInput, sessionId, files[] }`. Not a production surface. |
| Agent | `promptType: 'define'`, `text: '={{ $json.chatInput }}'`. Short system message: role + what the tool is for. Tool-specific instructions go in the **tool description**, not the system prompt. |
| Tool | Native tool if one operation covers it (`httpRequestTool`, `calculatorTool`, Slack/Gmail/Sheets tools). Else HTTP Request Tool with a predefined credential type. Don't extract a `toolWorkflow` sub-workflow. See `n8n-agents-official` `references/TOOLS.md`. |
| `fromAi()` | Every param the model should fill. Name and description are part of the prompt; vague tools get skipped. |
| Memory | Off unless they asked for multi-turn. Then `memoryBufferWindow` keyed on `sessionId`. See `n8n-agents-official` `references/MEMORY.md`. |

**Read:** `n8n-agents-official` SKILL.md (sub-node slots), `references/TOOLS.md`, `references/CHAT_AGENT_PATTERNS.md` ("keep it in one workflow"). Use `references/examples/agent-core.json` only as a wiring shape for Agent + model + tools, not as a prompt or Slack Block Kit template.

**Pin:** the tool node if it is credentialed or HTTP. The chat trigger. Demo in canvas chat, or `test_workflow` with `{ chatInput, sessionId, files: [] }`.

**Anti-loop is not optional on Slack/Discord/Teams.** Any chat-triggered workflow that posts a reply must filter the bot's own user ID or it loops. Prefer trigger-level exclusion (Slack `options.userIds` is an exclusion list). See `CHAT_AGENT_PATTERNS.md`. Canvas Chat Trigger does not need this.

## If none of the three fit

Still 3-6 nodes, one trigger from the parent decision tree, built-in nodes, pin what you can't call live. Don't invent a fourth architecture for a demo.
