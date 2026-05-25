---
date: 2026-05-25
author: Angus He
---

> ⚠️ 本文档包含撰写时尚未提交的工作区变动。

# 修复点击通知列表项后 Preview Overlay 未消失的问题

## Why

Fizzy 的通知列表支持 hover 预览：鼠标悬停在某条通知上时，系统会切换到对应的 tmux pane，并在屏幕上绘制一个全屏半透明遮罩（dim overlay）+ 青色边框（cyan border）高亮目标 pane 的位置。当鼠标离开时，`exitPreview()` 负责恢复先前的 pane 并隐藏遮罩。

问题出现在**点击**场景：用户点击列表项后，期望直接跳转到目标 pane 并关闭遮罩。但实际表现是 pane 切换成功，遮罩却留在屏幕上不消失。

根因是 `handleOpen()` 的调用链存在一个状态竞争：

```
handleOpen()
  ├─ clearPreviewState()   →  queue.async { _inPreview = false }
  ├─ onOpen?(item)         →  queue.async { selectTmuxPane... }
  └─ reload()
       └─ exitPreview()    →  queue.async { guard _inPreview → false → return }
```

三个操作都通过同一个串行队列（serial queue）异步派发。由于队列保证 FIFO 顺序，`exitPreview()` 的 block 执行时 `_inPreview` 已被 `clearPreviewState()` 置为 `false`，`guard` 直接返回，`PreviewOverlay.hide()` 永远不会被调用。

这不是 timing 问题——串行队列保证了顺序，问题在于 `clearPreviewState()` 的职责定义不完整：它清除了内部状态但遗漏了视觉状态。

## What

在 `clearPreviewState()` 中补充 `PreviewOverlay.hide()` 调用，使"丢弃预览状态"的语义完整覆盖内部状态和视觉状态。

设计上维持 `clearPreviewState()` 和 `exitPreview()` 的职责分离：

| 方法 | 恢复先前 pane/app | 隐藏遮罩 | 使用场景 |
|------|:-:|:-:|------|
| `exitPreview()` | ✓ | ✓ | hover 离开，取消预览 |
| `clearPreviewState()` | ✗ | ✓ | 点击跳转，有意导航到目标 |

同时为 `PreviewOverlay` 添加 `isVisible` 只读属性，暴露遮罩窗口的可见状态，使该行为可测试。

## How

修改集中在三个文件，共 23 行新增：

**核心修复**（`TerminalActivator.clearPreviewState()`）：在串行队列的 async block 内，设置 `_inPreview = false` 之后，通过 `DispatchQueue.main.async` 调用 `PreviewOverlay.hide()`。这与 `exitPreview()` 中的派发模式一致——UI 操作始终回到主线程。`hide()` 内部是 `overlayWindow?.orderOut(nil)`，optional chaining 保证幂等安全。

**可测试性**（`PreviewOverlay.isVisible`）：一个计算属性，委托给 `NSWindow.isVisible` 并对 nil 窗口返回 `false`。这是唯一新增的 API 表面。

**回归测试**（`testClearPreviewStateHidesOverlay`）：创建真实的 overlay 窗口，调用 `clearPreviewState()`，通过 `XCTNSPredicateExpectation` 断言遮罩在 2 秒内不可见。选择 predicate expectation 而非手动 RunLoop spin 的原因是：在无完整 AppKit 事件循环的测试进程中，`RunLoop.current.run(until:)` 不能可靠地排空 GCD main queue 的 dispatch，而 XCTest 的 `wait(for:timeout:)` 内部有专门的机制处理这一点。测试通过 `addTeardownBlock` 保证清理，通过 `guard NSScreen.main != nil` 在无头环境中优雅跳过。
