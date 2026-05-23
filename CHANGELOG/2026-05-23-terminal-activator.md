---
date: 2026-05-23
author: Angus He
---

# Fizzy 引入通知信封协议和智能终端定位

## Why

Fizzy 最初通过 HTTP 直连接收 Claude Code 的通知 payload，点击 "Open" 时只能激活终端 app，无法定位到具体的窗口或 tmux pane。而之前的 shell hook 脚本（`notify-on-idle.sh`）具备这些能力——它运行在 Claude Code 的 shell 环境中，天然能拿到 `$TMUX_PANE`、进程树信息和 git 分支。迁移到 Fizzy 后这些上下文丢失了。

核心矛盾：**环境上下文只存在于 agent 的 shell 进程中，而 Fizzy 是一个独立的桌面 app，无法直接获取这些信息。**

同时，原始设计将 `ClaudeCodeNotification` 硬编码为唯一的通知格式，无法扩展到 Codex 等其他 agent。

考虑过的替代方案：
- 在 `ClaudeCodeNotification` 上直接添加 tmux 字段 → 污染了 agent 原生 payload 的语义
- 让 Fizzy 自行检测终端进程 → Fizzy 不在终端进程树中，无法获取
- 用 bundle ID 识别终端 → 多实例场景下无法区分

## What

引入三层通知架构，将 agent payload 和环境上下文解耦：

```
┌─────────────────────────────────────────┐
│         FizzyNotification (信封)         │
├──────────┬──────────────┬───────────────┤
│  agent   │   payload    │     env       │
│"claude_  │ AgentPayload │ EnvironmentCo │
│  code"   │  (协议)       │ ntext        │
│          │              │               │
│          │ ┌──────────┐ │ terminal_pid  │
│          │ │ClaudeCode│ │ tmux_pane     │
│          │ │ Payload  │ │ tmux_socket   │
│          │ └──────────┘ │ git_branch    │
└──────────┴──────────────┴───────────────┘
```

**设计决策：**

- **`AgentPayload` 协议**定义 4 个公共字段（message、cwd、notificationType、title），UI 层只依赖协议，不感知具体 agent 类型。加新 agent = 定义一个 struct + decoder 加一行 case。
- **`EnvironmentContext`** 全部字段可选，缺失时优雅降级到原有行为（仅激活终端 app）。
- **Hook 脚本是适配层**——Claude Code 的 payload 字段名与 `ClaudeCodePayload` 一致，hook 零转换直接嵌入；未来 Codex 的 hook 负责映射。
- **终端定位用 PID 而非 bundle ID**——PID 精确指向进程，解决 `open -n` 多实例问题。
- **保留旧端点** `/claudecode/notification` 向后兼容，自动包装为空 env 的信封。
- **Toast 可点击**——点击立即关闭 toast 并激活终端，与列表面板的 "Open" 行为一致。

**放弃的东西：**
- 没有在 Fizzy 端运行 git 命令——git branch 由 hook 在正确的 cwd 中解析
- 没有支持任意终端——hook 的进程树检测只匹配 Ghostty、iTerm2、Terminal 三个
- 没有为 `activate(for:)` 添加依赖注入测试——需要 mock NSRunningApplication/Process/NSAppleScript，复杂度不值得

## How

### 通知流

```
Claude Code                  Hook 脚本                    Fizzy
    │                            │                          │
    │─── stdin JSON ────────────▶│                          │
    │                            │ 1. 读取 payload           │
    │                            │ 2. 遍历进程树找终端 PID     │
    │                            │ 3. 读取 $TMUX_PANE/$TMUX  │
    │                            │ 4. git symbolic-ref       │
    │                            │ 5. 组装 envelope           │
    │                            │                          │
    │                            │── POST /notification ───▶│
    │                            │                          │ decode FizzyNotification
    │                            │◀── {"continue":true} ───│ (先响应，再回调)
    │                            │                          │
    │                            │                          │ → store.add()
    │                            │                          │ → 更新气泡状态
    │                            │                          │ → 显示 toast
```

### 终端激活（TerminalActivator）

三阶段执行，跨两个线程：

```
Main Thread                          Background Thread
    │                                      │
    │ 1. 查找终端 app                        │
    │    PID → NSRunningApplication         │
    │    或 fallback → bundle ID 扫描        │
    │ 2. 读取 app.localizedName              │
    │                                      │
    │──── dispatch ────────────────────────▶│
    │                                      │ 3. 窗口定位
    │                                      │    有 tmux_pane:
    │                                      │      tmux select-window -t %N
    │                                      │      tmux select-pane -t %N
    │                                      │    无 tmux:
    │                                      │      AppleScript AXRaise
    │                                      │      (匹配窗口名含目录名)
    │◀─── dispatch back ──────────────────│
    │                                      │
    │ 4. app.activate(options: [])          │
```

AppKit API（`NSWorkspace.shared.runningApplications`、`NSRunningApplication`、`localizedName`）在主线程执行。阻塞操作（`Process.waitUntilExit()` 和 `NSAppleScript.executeAndReturnError`）在后台线程执行。

### 安全措施

- **AppleScript 注入防护**：先剥离换行符和控制字符，再转义反斜杠和双引号（顺序重要）
- **tmux pane 格式校验**：正则 `^%\d+$` 拒绝非法输入
- **HTTP 响应时序**：先写 `{"continue":true}` 再触发回调，防止回调阻塞导致 hook 超时
- **tmux 命令用 Process 参数数组**传递，不经过 shell 解释器
