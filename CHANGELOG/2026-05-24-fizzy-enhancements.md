---
date: 2026-05-24
author: Angus He
---

# Fizzy 桌面宠物四项增强：位置记忆、右键菜单、会话去重、窗格高亮

## Why

Fizzy 作为 AI 编码代理的通知伴侣，核心交互循环是：收到通知 → 查看列表 → 预览/跳转终端。在日常使用中暴露出四个摩擦点：

1. **位置不持久**：每次启动都回到右上角默认位置，用户拖到习惯位置后重启丢失。这在多显示器场景下尤其恼人。
2. **没有退出入口**：唯一的退出方式是 Cmd+Q 或 kill 进程。菜单栏图标有退出项但不够直觉——用户期望右键宠物窗口就能退出。
3. **通知列表冗余**：同一个 Claude Code 会话会触发多次通知（stop、idle_prompt 等），列表里堆积同一会话的旧条目，信息密度低。
4. **预览缺少视觉锚点**：hover 通知时 TerminalActivator 切换到目标 tmux 窗格，但用户视线仍在通知列表上，无法确认"我正在看的是哪个窗格"。需要一个全屏级的视觉提示。

## What

四个独立特性，各自触及不同文件，互不耦合：

### 窗口位置持久化

在 `FizzyWindow` 上新增 `savedOrigin()` / `saveOrigin()`，通过 UserDefaults 序列化窗口原点。启动时读取并校验——用 `NSRect.intersects` 检查保存的窗口矩形是否与任意屏幕的 `visibleFrame` 相交，处理显示器拔插后坐标失效的问题。

放弃了 `NSWindow.setFrameAutosaveName`，因为它保存完整 frame（含 size），而 FizzyWindow 尺寸固定，只需持久化 origin。

### 右键退出菜单

`FizzyWindow` 重写 `rightMouseDown`，弹出一个只含 "Quit" 的 `NSMenu`。borderless 窗口 + `.accessory` 激活策略下，`NSMenu.popUp` 正常工作，不需要额外处理。

### 会话去重

在 `AgentPayload` 协议上扩展 `sessionId: String?`（默认 `nil`），`ClaudeCodePayload` 的已有 `sessionId` 自然满足。`NotificationStore.add()` 在插入前按 sessionId 去重——同会话新通知替换旧的，始终 unread。

`GenericPayload` 无 sessionId，永不去重。

### 预览窗格高亮

这是本次最复杂的特性，经历了三次架构迭代：

```
方案 1: CAShapeLayer mask          → 失败（layer-backed view 的 mask 不可靠）
方案 2: NSView.draw + AppleScript → 失败（需要 Accessibility 权限）
方案 3: NSView.draw + CGWindowList → 成功（无需特殊权限）
```

最终方案的组件：

```
┌─────────────────────────────────────────────┐
│                DimView                       │
│  draw(_:) {                                  │
│    NSBezierPath(bounds) + pane → even-odd    │
│    fill 40% black (everywhere except pane)   │
│    stroke cyan border around pane            │
│  }                                           │
└─────────────────────────────────────────────┘
          ↑ paneRect
┌─────────────────────────────────────────────┐
│            PreviewOverlay                    │
│  resolvePaneRect(item, pid)                  │
│    ├─ queryTerminalFrame(pid)  ← CGWindowList│
│    ├─ queryTmuxGeometry(pane)  ← tmux CLI    │
│    └─ calculatePaneRect(geo, frame)          │
│  show(paneRect) / update(paneRect) / hide()  │
└─────────────────────────────────────────────┘
          ↑ 调用时机
┌─────────────────────────────────────────────┐
│          TerminalActivator                   │
│  enterPreview  → resolve + show              │
│  switchPreview → resolve + update            │
│  exitPreview   → hide                        │
└─────────────────────────────────────────────┘
```

## How

### 窗格定位管线

将 tmux 的字符单元坐标转换为屏幕像素坐标，分三步：

1. **终端窗口帧**：通过 `CGWindowListCopyWindowInfo` 按 PID 过滤，取第一个大于 100×100 的窗口。CG 坐标系原点在左上角，需转换为 AppKit 的左下角原点。
2. **tmux 窗格几何**：运行 `tmux display-message -t %N -p '#{pane_top} #{pane_left} ...'`，得到窗格在字符单元中的位置和尺寸，以及所在 tmux window 的总尺寸。
3. **单元到像素**：`cellWidth = terminalWidth / windowWidthInCells`，然后 `panePixelRect = origin + cellOffset * cellSize`，Y 轴翻转（tmux 从上往下，AppKit 从下往上）。

### 覆盖层渲染

`DimView` 继承 `NSView`，重写 `draw(_:)` 使用 `NSBezierPath` 的 even-odd 填充规则——外矩形（整个 bounds）和内矩形（窗格区域）组成路径，even-odd 规则使重叠区域（窗格）透明，其余区域填充 40% 黑色。窗格边缘描一圈 3pt cyan 边框作为正向视觉指示。

覆盖层窗口设为 `level = .floating - 1`（在正常窗口之上、Fizzy 宠物窗口之下），`ignoresMouseEvents = true`（点击穿透），窗口和 DimView 实例缓存复用。

### 线程模型

```
Background queue (TerminalActivator.queue)
  ├─ selectTmuxPane         ← 阻塞 I/O
  ├─ queryTerminalFrame     ← CGWindowList（快）
  ├─ queryTmuxGeometry      ← Process.waitUntilExit（阻塞 I/O）
  └─ calculatePaneRect      ← 纯计算
       ↓ paneRect
Main thread
  ├─ activate terminal
  ├─ PreviewOverlay.show()  ← NSView/NSWindow 操作
  └─ PreviewOverlay.hide()
```

所有阻塞 I/O 在后台队列完成，只有 UI 操作在主线程。`resolvePaneRect` 整体在后台运行，结果通过 `DispatchQueue.main.async` 传递给 `show`/`update`。

### 优雅降级

`resolvePaneRect` 的每一步都是可选的——无 tmux 上下文、终端窗口不在屏幕上、tmux 命令失败、窗格 ID 格式非法（`^%\d+$` 校验）——任何一步失败都静默返回 nil，预览照常工作，只是没有覆盖层高亮。
