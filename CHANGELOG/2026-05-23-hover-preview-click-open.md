---
date: 2026-05-23
author: Angus He
---

# 通知交互模型重构：从"点击打开"到"悬停预览"

## Why

Fizzy 原有的通知交互模型是传统的「列表 + 按钮」：用户点击气泡打开通知列表，每条通知有一个 Open 按钮切换到对应终端。这个模型有两个问题：

1. **无法预览**：用户必须完整切换到终端才能看到通知对应的 session 内容，切过去之后如果不是想要的 session，还得切回来。在多 tmux pane 的工作流中尤其不便。
2. **切换成本高**：点击 Open → 终端全屏切换 → 失去当前上下文。对于"只是想看一眼"的场景，代价过重。

理想的交互是 hover-to-peek：悬停即可预览终端状态，移开即恢复，确认是目标 session 后再点击切换。这类似于 macOS Dock 的窗口预览——轻量、可逆、无承诺。

## What

### 交互模型变更

| 交互 | 变更前 | 变更后 |
|------|--------|--------|
| 打开通知列表 | 点击气泡 | 悬停气泡（hover-to-show） |
| 预览终端 | 无 | 悬停列表项 → 切换 tmux pane |
| 切换项目 | — | 在不同列表项间移动，直接切换 pane |
| 恢复原状 | — | 鼠标离开所有列表项，恢复原 pane + 原 app |
| 打开终端 | 点击 Open 按钮 | 点击列表项任意位置 |
| 关闭通知 | 点击 × 按钮 | 点击 × 按钮（移到右上角） |
| Toast 预览 | 无 | 悬停 toast → 预览 pane，暂停淡出 |

### 删除的内容

- Open 按钮：整行可点击替代
- "esc to close" 页脚：面板改为非 key window，不再接收键盘事件
- `makeKeyAndOrderFront`：改为 `orderFront`，不激活 Fizzy 应用

### 新增组件

- `TerminalActivator` 预览状态机：`enterPreview` / `switchPreview` / `exitPreview` / `clearPreviewState`
- `currentTmuxPane()`：通过 `tmux display-message -p #{pane_id}` 捕获当前 pane
- `FizzyWindow` hover tracking：气泡窗口的鼠标进出检测
- `HoverContainerView`：列表面板级别的鼠标追踪
- 可取消的淡出计时器（Timer 替代 DispatchQueue.asyncAfter）

## How

### 预览状态机

TerminalActivator 维护一个 preview session，生命周期由三个操作驱动：

```
enterPreview(item)          switchPreview(item)         exitPreview()
     │                           │                          │
     ▼                           ▼                          ▼
┌─────────────┐            ┌───────────┐             ┌─────────────┐
│ save app    │            │ select    │             │ restore     │
│ save pane   │──active──▶ │ tmux pane │──active──▶  │ saved pane  │
│ select pane │            │ (no save) │             │ restore app │
│ activate    │            └───────────┘             └─────────────┘
└─────────────┘
```

关键设计决策：

- **状态保存一次**：`enterPreview` 在首次进入时保存 frontmost app 和当前 tmux pane。之后 `switchPreview` 只切换 pane，不重新保存。`exitPreview` 恢复最初保存的状态。这避免了多次保存导致的 frontmost app 漂移问题。
- **Serial queue 保护状态**：所有可变状态（`_inPreview`, `_savedApp`, `_savedPaneId`, `_savedPaneSocket`）仅通过 `com.fizzy.terminal-activator` serial queue 访问。Main thread 通过 `queue.sync` 读取 `inPreview`，通过 `queue.sync` 原子地 check-and-set 进入预览。
- **clearPreviewState vs exitPreview**：点击列表项时调用 `clearPreviewState`（清除但不恢复），因为紧接着 `activate(for:)` 会切换到目标 pane，恢复旧 pane 会被立即覆盖。

### Hover-to-show 的 Timer 桥接

气泡、列表面板、列表项是三个独立的 NSTrackingArea。鼠标在它们之间移动时会触发 exit → enter 序列，需要 timer 桥接防止闪烁：

```
Pet bubble ──200ms──▶ List panel ──150ms──▶ Row items
  hover                 hover                 hover
  enter ◀─── cancel ─── enter ◀─── cancel ─── enter
  exit  ─── schedule ── exit  ─── schedule ── exit
```

- Pet → List 间隙：200ms `scheduleHideList` timer
- List → Row 间隙：不需要（Row 在 List 内部）
- Row → Row 切换：`handleHoverEnter` 的 `hoveredItemId == itemId` guard 避免同一行重复触发
- Row exit（preview active）：`schedulePreviewExit` 150ms timer
- Row exit（detail fallback）：`scheduleDismiss` 150ms timer

### 点击穿透

列表项包含多个 NSTextField 子视图（标题、消息、项目信息），它们会拦截 `mouseDown` 事件。通过 `HoverRow.hitTest` 将所有非按钮区域的点击路由到行本身：

```swift
override func hitTest(_ point: NSPoint) -> NSView? {
    let hit = super.hitTest(point)
    if hit is NSButton { return hit }  // × 按钮保留独立响应
    return self                         // 其余一律由行处理
}
```

配合 `acceptsFirstMouse(for:) -> true`，确保非 key window 的首次点击也能响应。

### Toast 预览

Toast 的 hover 预览独立于列表预览。使用 `TerminalActivator.enterPreview` / `exitPreview`，并与 `Timer`-based 淡出计时器联动：

- Hover enter：`enterPreview` 成功时取消淡出、恢复 alpha
- Hover exit：`exitPreview` 恢复终端、重启 4 秒淡出
- Click：`clearPreviewState`（不恢复）→ dismiss toast → `activate(for:)` 全量切换

`enterPreview` 的 re-entry guard 确保列表预览期间 toast hover 不会覆盖已保存的状态。
