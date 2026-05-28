---
date: 2026-05-28
author: Angus He
---

# 通知列表按 (agent, session) 去重，session 结束自动清理

## Why

Fizzy 的通知列表用 `sessionId` 做去重：同一个 session 的新通知会替换旧的。这里有两个问题：

**去重键过宽。** `sessionId` 是全局匹配的——如果 claude_code 和 codex 碰巧使用了相同的 session ID（不同 agent 的 ID 空间是独立的，碰撞概率低但不为零），一个 agent 的通知会覆盖另一个的。这是一个静默数据丢失的 bug。

**没有 session 结束清理。** 用户关掉一个 Claude Code 会话后，对应的通知一直留在列表里，直到手动点掉。对于高频使用者来说，列表很快就会被过期项目填满。Claude Code 提供了 `SessionEnd` hook event，会在 session 正常退出时触发（`/clear`、登出、正常退出等），可以作为清理信号。

另外，原有的 `POST /claudecode/notification` 端点直接接收裸的 `ClaudeCodePayload`，丢失了 `EnvironmentContext`（terminal PID、tmux pane、git branch），导致通过该端点到达的通知无法使用终端预览和激活功能。这个端点已被 `POST /notification`（带完整 envelope）取代，属于死代码。

## What

三个变更方向：

**1. 去重键从 `sessionId` 改为 `(agent, sessionId)` 复合键。**

`GenericPayload`（非 claude_code agent 的 fallback payload）新增了可选的 `sessionId` 字段，使得任意 agent 都可以 opt-in 到基于 session 的去重。`NotificationStore.add()` 的去重谓词从 `$0.notification.sessionId == sid` 变为 `$0.agent == agent && $0.notification.sessionId == sid`。

**2. 新增 session 结束清理机制。**

```
Claude Code SessionEnd hook
    → session-end-fizzy.sh（提取 session_id，包装为 {agent, session_id}）
    → POST /session-end
    → NotificationStore.endSession(agent:sessionId:)
    → UI 刷新
```

`NotificationStore` 新增 `endSession(agent:sessionId:)` 方法，按复合键移除项目。`FizzyServer` 新增 `POST /session-end` 端点，接收 `SessionEndRequest`（agent + session_id），通过 `onSessionEnd` 回调通知 `FizzyApp`，后者调用 store 清理并刷新 UI。

可靠性边界：`SessionEnd` 在 `kill -9`、crash、断电等场景下不会触发。这对桌面宠物应用是可接受的——过期项目留在列表里，用户手动关掉即可。

**3. 移除 `POST /claudecode/notification` 端点。**

该端点被 `POST /notification` 完全取代。测试确认请求该路径返回 404。

## How

**回调类型设计。** `onSessionEnd` 回调最初设计为 `(String, String) -> Void`，但 Swift closure 不携带参数标签，调用方可以在编译期无感地交换 agent 和 sessionId。改为传递 `SessionEndRequest` struct，利用属性名 `.agent` / `.sessionId` 提供编译期安全。

**Hook 脚本。** `session-end-fizzy.sh` 遵循 `notify-fizzy.sh` 的模式：从 stdin 读取 Claude Code 的 hook JSON，用 jq 提取 `session_id`，构造目标 JSON，用 curl 异步 POST 到 Fizzy。通过 `& disown` 避免阻塞 Claude Code 退出流程。与 notification hook 相比，session-end 不需要收集环境上下文（terminal PID、tmux 等），因为它只用于移除项目，不需要终端定位信息。

**安装集成。** `session-end-fizzy` 加入 Makefile 的 `install`、`uninstall`、`pkg` 三个 target，与 `notify-fizzy` 对称安装到 `$(BINDIR)`。用户需在 `~/.claude/settings.json` 中配置 `SessionEnd` hook 指向该脚本。
