---
name: n8n-poc-quickstart
description: Use when the user wants a quick n8n proof-of-concept, prototype, demo, spike, or vibe workflow from a short natural-language idea. Triggers on "PoC", "POC", "prototype", "demo", "vibe", "hackathon", "spike", "just make it work", "throw something together", "scaffold a workflow", "quick and dirty", "one-liner", "proof of concept", or any request to get a runnable workflow on the canvas fast without production hardening. Prefer this over the official production skills when speed-to-demo matters more than error handling, reuse, or polish.
---

# n8n PoC Quickstart

Official skills optimize for production. This skill is the exception: one happy path, pinned data when creds aren't ready, assumptions stated instead of an interview. Harden later with those skills, don't load them first.

## Non-negotiables

1. **Secrets never in text fields or SDK code.** Same rule as production: credentials, or pin/mock the node. A pasted key "just for the demo" lands in exports and chat history. See `n8n-credentials-and-security-official`.
2. **`get_node_types` before configuring any node.** Guessed params still fail silently on a 4-node PoC. Live types beat memory. See `n8n-node-configuration-official`.
3. **Don't fire real side effects you didn't mean.** `test_workflow` pins triggers, credentialed nodes, and HTTP Request. Code, Data Tables, Execute Command, file ops, and sub-workflow calls run for real. Ask, or pin/disable those nodes. See `n8n-workflow-lifecycle-official` `references/TESTING.md`.
4. **State assumptions. Don't interview.** One blocking question max: would this send, pay, or write to a production account they care about? Everything else, pick a default and say it.

## Relax vs never-skip

| Production rule | PoC |
|---|---|
| Error workflow, error output on every fallible node, 4xx/5xx matrix | Skip. One happy path. Webhook can use `responseMode: 'lastNode'` |
| Search existing sub-workflows / extract reuse | Skip. One canvas |
| Folder / project questions before build | Skip unless they named a folder |
| Sticky notes, node groups, full handoff | Skip. Keep `description` (one sentence + "PoC, not production") |
| Human review on agent tools | Skip unless the demo would email/pay/message real customers |
| Schema validator IIFE, `retryOnFail`, pagination matrix | Skip |
| `outputParserStructured` + `autoFix` | Keep if the demo needs JSON out. Flaky parse kills the demo |
| Agent tool names/descriptions | Keep. Vague tools don't get called |
| Chat-surface anti-loop filter (Slack/Discord/Teams) | Keep. A loop is not a demo |
| `$('Node').item.json.x` over `$json.x` | Keep. `$json` breaks on the first extra node |
| `validate_workflow` + `get_workflow_details` connections | Keep. Silent dropped wires waste the iterate loop |
| `publish_workflow` | Only if they need a live webhook/form URL. Canvas chat and `test_workflow` don't |

When they say ship, harden, or production: stop using this skill as the primary path. Load `n8n-workflow-lifecycle-official` and `n8n-error-handling-official`, plus the domain skill.

## Decision tree

```
One-line idea
├── Someone types / chats / "talk to it"
│   └── Chat Trigger (`availableInChat: true`) + Agent. Pattern 3
├── Someone fills a page / "a form"
│   └── Form Trigger. Pattern 1. Form owns the response; no Respond to Webhook
├── External POST / curl / "an API"
│   └── Webhook. Pattern 1. PoC default: `responseMode: 'lastNode'`
├── Runs by itself / "every morning" / "on a timer"
│   └── Schedule Trigger, simple interval (not cron). Pattern 2
└── Unclear
    └── Webhook. Easiest demo: test URL or curl
```

Need an external call?

```
├── Native built-in node exists → use it
├── HTTP API, no native node → HTTP Request
└── No creds and no public API they named → pin sample JSON, skip the live call
```

Built-in only: `n8n-nodes-base.*` and `@n8n/n8n-nodes-langchain.*`. No community nodes (install wall). No sub-workflow extract. No Merge. No Loop Over Items. Code node only if an expression or Edit Fields arrow function can't do the transform; the perf/readability why in `n8n-code-nodes-official` still applies.

## PoC loop

1. **Scaffold.** Pick a pattern from `references/STARTER_PATTERNS.md`. 3-6 nodes. Name `PoC: <verb-first>`. `description`: what it does + "PoC, not production".
2. **Create.** `get_workflow_sdk_reference` once per session. `search_nodes` + `get_node_types` per node. `create_workflow_from_code`. Then `update_workflow` `addTags: ['poc']` (and a domain tag if obvious). `create_workflow_from_code` can't set tags.
3. **Verify.** `get_workflow_details`: `connections` match intent. `validate_workflow` so the iterate loop isn't spent on schema errors.
4. **Test.** `prepare_workflow_pin_data` (schemas only, you generate values). `test_workflow`. Announce which nodes were pinned. Same pin data every iteration.
5. **Demo.** How to trigger (canvas chat, test URL, `test_workflow`). What they should see. Assumptions. Which nodes are mocked. Credential *types* still missing. Don't publish unless they need a live URL.
6. **Stop.** Happy path returns the expected shape. That is done. Iterate only if the demo is wrong.

`list_credentials` when auth is involved. One match: bind by ID. Several: ask which. None: `newCredential('Label')` placeholder + pin that node. Tell them the credential type to create in the UI. Prefer n8n credits when they have no preference (`list_n8n_connect_services`). If they paste a secret, don't put it in a node; treat it as leaked. See `n8n-credentials-and-security-official`.

Pass `skillsUsed: ['n8n-poc-quickstart']` (plus any other skill you actually invoked) on create/update. No `-official` suffix on this name.

## Defaults to state, not ask

| Choice | Default |
|---|---|
| Folder | Current project root |
| Model | Existing cred of the right type, else n8n credits, else pin the model/agent |
| Schedule | Simple interval (every 5 minutes for a watched demo). Timezone is workflow-level, not per-rule |
| Webhook path | Descriptive + short unique suffix. Paths are instance-global |
| Notify | Slack/Gmail/Discord if a cred exists; else pin and show the shaped payload. Strip n8n attribution |
| Memory | Off unless they asked for multi-turn |
| Publish | Off |

## Graduate

| They say | Load |
|---|---|
| Ship / publish / harden / production | `n8n-workflow-lifecycle-official`, `n8n-error-handling-official` |
| Auth / tokens / "put the real key in" | `n8n-credentials-and-security-official` |
| Agent tools / memory / HITL / Slack bot | `n8n-agents-official` |
| It's broken | `n8n-debugging-official` |
| Reuse / extract / "we'll call this from other flows" | `n8n-subworkflows-official` |

Don't harden inside this skill. Hand them the official skill and switch.

## Reference files

| File | Read when |
|---|---|
| `references/STARTER_PATTERNS.md` | Scaffolding. Three patterns, node lists, which official refs to open |
| `n8n-workflow-lifecycle-official` `references/TESTING.md` | Pin shapes, what `test_workflow` actually runs |
| `n8n-node-configuration-official` `references/WEBHOOK_NODES.md` | Webhook `responseMode`, unique paths |
| `n8n-node-configuration-official` `references/TRIGGER_NODES.md` | Schedule timezone, cron vs simple interval |
| `n8n-agents-official` | Agent vs Basic LLM Chain vs Text Classifier, sub-node slots |
| `n8n-agents-official` `references/TOOLS.md` | Tool types. PoC default: native tool or HTTP Request Tool |
| `n8n-agents-official` `references/CHAT_AGENT_PATTERNS.md` | Keep one workflow. Anti-loop if posting to Slack/Discord/Teams |
| `n8n-credentials-and-security-official` | Any auth, pasted secret, missing cred |

## Anti-patterns

| Anti-pattern | What goes wrong | Fix |
|---|---|---|
| Interviewing for a 4-node demo | Loses the PoC | Pick defaults, list assumptions |
| Hardcoding a pasted API key "just for the demo" | Leaks in export and chat | Credential or pin |
| Building the production error matrix first | Never reaches a demo | One happy path |
| Community node or custom cred for a 10-minute spike | Install wall | Built-in + HTTP Request + pin |
| Publishing a schedule that emails a real inbox | Surprise sends | Pin notify, or ask |
| Extracting sub-workflows on a 5-node PoC | Extra workflows, slower demo | One canvas |
| Skipping `get_node_types` because "it's a PoC" | Invalid params, wasted iteration | Always fetch types |
| `execute_workflow` to "just see" | Real side effects, real cost | `test_workflow` + pins |
| Treating the PoC as done for production | Silent prod failures | Graduate table above |
| Lifting `slack-router` / `agent-core` as the PoC | Those are the production split | One-workflow shape in `CHAT_AGENT_PATTERNS.md` |
| Respond to Webhook on a Form Trigger flow | Wrong response surface | Form owns the response |
| Inventing Slack/Sheets IDs instead of pinning | Validates, points at nothing | Pin the comms/resource node |
