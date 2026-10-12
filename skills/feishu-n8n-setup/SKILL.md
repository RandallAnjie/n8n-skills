---
name: feishu-n8n-setup
description: >-
  Use when first connecting Feishu / Lark / 飞书 credentials in n8n (app, scopes,
  version publish, Feishu Suite API Test). 在 n8n 里第一次接飞书 / 本包凭据时使用。覆盖：创建飞书应用、申请应用身份权限、
  发布版本 + 租户管理员审批坑、n8n 添加 Feishu Suite API 凭据并点 Test、
  通讯录/云文档数据范围。不要用它来搭多维表格工作流（见 feishu-bitable-workflows）。
---

# 飞书应用 + n8n 凭据

对象：PoC / 生产同事。包 `n8n-nodes-feishu-suite` **0.1.5**，节点类型 `n8n-nodes-feishu-suite.feishuSuite`。e2e 只用 App ID / App Secret（`tenant_access_token`），中国区 `https://open.feishu.cn`。

依据：[REQUIRED_SCOPES.md](../../docs/REQUIRED_SCOPES.md)、[E2E_REPORT.md](../../docs/E2E_REPORT.md)。官方：[申请 API 权限](https://open.feishu.cn/document/ukTMukTMukTM/uQjN3QjL0YzN04CN2cDN)。

## 1. 创建飞书应用

1. 打开 [飞书开放平台](https://open.feishu.cn/) → 创建**企业自建应用**
2. 「凭证与基础信息」抄下 **App ID**、**App Secret**（不要写进聊天、不要提交仓库）
3. 本包凭据走 **应用身份** `tenant_access_token`，不是用户身份

## 2. 申请权限（应用身份页签）

PoC 主路径是多维表格，官方文档要求（满足其一即可）：

| 用途 | scope |
| --- | --- |
| 多维表格读写 | `bitable:app` |
| 多维表格只读 | `bitable:app:readonly` |
| 获取多维表格信息（较新） | `base:app:read` |
| 高级权限 / 自定义角色 | `bitable:app`（表格还要先打开高级权限） |

后台「权限管理 → 批量导入/导出」可追加（不会覆盖已开通项）。导入后若状态是「待发布」，**必须走版本发布**。粘贴后以后台实时校验为准。

主路径 JSON（`tenant` = 应用身份，`user` 留空）：

```json
{
  "scopes": {
    "tenant": [
      "bitable:app",
      "bitable:app:readonly",
      "base:app:read"
    ],
    "user": []
  }
}
```

日历 / 邮箱 / 考勤 / 会议室 / 审批列表 / 解散群另有 scope，见 [REQUIRED_SCOPES.md](../../docs/REQUIRED_SCOPES.md)。本租户即使用「全部权限」勾选，这些接口仍可能 `99991672`。

## 3. 发布版本 + 管理员审批（最常见坑）

控制台勾了「全部权限」，Open API 仍可能返回：

```
code=99991672
msg=Access denied. ...应用尚未开通所需的应用身份权限：[…]
token_type=tenant
```

飞书认的是 **已发布版本 + 租户管理员授权 + 数据范围**，不是草稿勾选。

1. **版本管理与发布** → 创建并发布新版本（权限加在未发布版本上：测试企业可能生效，正式租户不生效）
2. 租户管理员在管理后台审通过；可用性范围要包含当前企业
3. 通讯录、云文档等还要单独配 **数据范围 / 数据权限**
4. `token_type=tenant` = 必须开通 **应用身份** 页签，不是用户身份

节点报错会写成 `Missing Feishu permission scope (code 99991672): <names>`，并提示开发者后台 / 发布新版本 / 数据范围。把飞书返回的 **code / msg / scope** 原样记下来。

## 4. 在 n8n 加凭据并 Test

1. 确认已安装社区包 `n8n-nodes-feishu-suite`（本环境 0.1.5 已验证）
2. Credentials → 新建 **Feishu Suite API**（`feishuSuiteApi`）
3. Base URL：中国区 `https://open.feishu.cn`
4. 填 App ID / App Secret
5. 点 **Test**。e2e 在 n8n 2.42.6 上 Test **通过**

不要用用户 OAuth2 跑本技能描述的主路径；e2e 没有用 OAuth2 凭据。

## 5. 数据范围 / 通讯录可见性

| 现象 | 含义 | 做法 |
| --- | --- | --- |
| `40004 no dept authority` | **不是**缺 API scope | 应用身份对部门/人员的**数据范围**不够 |
| 人员**字段**能建，人员**单元格**写失败 | 同上 | 开放平台把通讯录数据范围扩到目标部门/人员 |
| 缺 `bitable:app` 的 `99991672` | 应用身份权限或未发布 | 见第 3 步 |

本租户：人员字段创建 PASS；人员单元格写入被 `40004` 拦住。多维表格主路径（建表/写普通字段/查记录）在 `bitable:app` 已生效时能跑通。
