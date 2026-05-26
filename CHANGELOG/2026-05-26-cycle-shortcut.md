---
date: 2026-05-26
author: Angus He
---

# 为 Fizzy 添加 Cmd+Shift+Arrow 全局快捷键循环切换通知项

## Why

Fizzy 作为 Claude Code 的桌面通知伴侣，原本只能通过鼠标操作（hover 弹出列表、点击打开终端）来处理通知。当开发者同时运行多个 Claude Code 会话时，需要频繁在鼠标和键盘之间切换，打断工作流。

macOS 的 Cmd+Tab 应用切换是一个被验证过的交互范式——按住修饰键、用方向键/Tab 键循环、松开修饰键确认选择。将这个范式引入 Fizzy 可以让开发者不离开键盘就能快速切换到需要关注的 Claude Code 会话。

在实现过程中，最初采用 Cmd+Shift+Space 作为触发键，但 Space 会与 macOS emoji picker 冲突。最终改为 Cmd+Shift+Arrow，箭头键本身就是导航操作，语义更自然，且 Left Arrow 可以反向进入循环。

## What

新增 5 个核心组件，修改 2 个现有文件，总计 ~2000 行新代码和 155 个测试用例。

### 新增组件

```
┌─────────────────────────────────────────────────────┐
│                    FizzyApp                          │
│  (orchestrator: 回调 wiring, 生命周期管理)            │
├─────────────┬───────────────────┬───────────────────┤
│ HotkeyManager│CycleSession      │ SettingsPanel     │
│ (CGEvent tap │Controller        │ (配置 UI)          │
│  + 状态机)   │(会话编排)         │                    │
├─────────────┤                   │                    │
│ CycleConfig │←── 读取配置 ──────│                    │
│ FizzyConfig │←── 读取/保存 ─────│                    │
├─────────────┴───────────────────┴───────────────────┤
│           SwitcherPanel (Cmd+Tab 风格 UI)            │
│           TerminalActivator (终端预览/切换)           │
└─────────────────────────────────────────────────────┘
```

- **HotkeyManager** — CGEvent tap 捕获全局键盘事件，内部状态机为纯函数（idle/cycling 两个状态），17 个测试覆盖所有状态转移。需要 Accessibility 权限。
- **SwitcherPanel** — 水平浮动面板，展示通知项为卡片，选中项 cyan 高亮，底部显示消息预览。
- **CycleSessionController** — 编排层，连接 HotkeyManager 事件、SwitcherPanel 视觉、TerminalActivator 终端切换。
- **CycleConfig** — 快捷键配置（修饰键、显示模式），UserDefaults 持久化。
- **FizzyConfig** — 应用级配置，包装 CycleConfig 作为子对象，新增 listTrigger（click/hover）。

### 设计决策

| 决策 | 选择 | 放弃的方案 |
|------|------|-----------|
| 状态机测试策略 | 纯函数 `mapEvent`，参数传入 state | 测试 CGEvent tap（需要 Accessibility 权限） |
| 触发键 | Cmd+Shift+Arrow（固定） | Cmd+Shift+Space（emoji 冲突），可配 keyCode（过度设计） |
| 修饰键配置 | checkbox 自由组合 | 快捷键录制器（与固定 arrow 矛盾） |
| 列表触发模式 | 运行时配置 click/hover | 编译时固定一种 |
| TerminalActivator 测试 | `isEnabled` 静态 flag | 协议注入（过度抽象） |
| 版本号 | git describe → sed 注入 Info.plist | 硬编码 / Swift 编译参数 |

### SettingsPanel 重写

从零开始重写为原生 macOS 控件风格：

- **Cycle Shortcut** — 修饰键 checkbox + NSGridView key bindings 表（固定左列宽度对齐）
- **Display Mode** — 卡片式 radio 选择，内嵌 NSBezierPath 绘制的终端窗口缩略图
- **Notification List** — click/hover 触发模式 radio
- **Permissions** — NSGridView 对齐的权限状态行（彩色圆点 + 状态文字）
- **底栏** — "⌘, to reopen" + 版本号 + Done 按钮

## How

### 键盘事件流

```
CGEvent tap (main run loop)
    │
    ▼
HotkeyManager.handleTapEvent
    │  读取 keyCode, flags, eventType
    ▼
mapEvent(keyCode, eventType, flags, state, config) → EventResult?
    │
    ├─ nil → passUnretained(event)  // 不匹配，放行
    │
    └─ EventResult(action, newState)
           │  state = newState (同步)
           │  调用对应回调 (同步，不用 DispatchQueue.main.async)
           ▼
       CycleSessionController.startSession / cycleForward / ...
           │
           ├─ SwitcherPanel.show / updateSelection / hide
           └─ TerminalActivator.enterPreview / switchPreview / ...
```

tap 回调通过 `CFRunLoopAddSource(CFRunLoopGetMain(), ...)` 安装在主 run loop 上，所以回调本身就在主线程执行，无需额外 dispatch。状态更新和回调同步执行，避免了快速按键下的 state/callback desync。

### 状态机

```
                    Cmd+Shift+→
            idle ─────────────────► cycling
             ▲   Cmd+Shift+←        │
             │   (startBackward)     │
             │                       │
             │   ←── →: cycleForward │
             │   ←── ←: cycleBackward│
             │                       │
             ├── ↓ or modifier ──────┘  (activate → idle)
             └── ↑ ──────────────────┘  (cancel → idle)
```

Left Arrow 从 idle 进入时发出 `startSessionBackward`，controller 将 selectedIndex 设为最后一项。

### 配置架构

```
FizzyConfig
├── cycle: CycleConfig
│   ├── modifierFlags: CGEventFlags  (UserDefaults: cycleModifierFlags)
│   └── displayMode: DisplayMode     (UserDefaults: cycleDisplayMode)
└── listTrigger: ListTrigger         (UserDefaults: listTrigger)
```

FizzyConfig.load() 委托 CycleConfig.load() 加载子配置，自身只加载 app 级字段。SettingsPanel 持有 FizzyConfig 实例，修改后调用 save()（级联保存子配置）。HotkeyManager.updateConfig() 仍接受 CycleConfig——不需要感知 app 级配置。

### 版本注入

```
git describe --tags --always --dirty
        │
        ▼
    Makefile VERSION 变量
        │
        ├── make install: sed 替换 Info.plist 中的 "1.0"
        ├── make pkg: 同上 + 用于 .pkg 文件名
        └── codesign --force --sign - (保持 Accessibility 权限稳定)
              │
              ▼
    Bundle.main["CFBundleShortVersionString"]
        │
        ▼
    SettingsPanel 底栏: "Fizzy v0.3.0-20-g73ed942"
```

`swift run` 调试模式下无 Info.plist，fallback 显示 "Fizzy dev"。

### 安全边界

- **activate() 越界保护** — selectedIndex 可能因 store 中途变化而越界，guard 后 fallback 到 cancel
- **修饰键最少一个** — `isValidRemoval(current:removing:)` 纯函数校验，阻止取消最后一个 modifier
- **箭头键禁止录入** — 即使保留了录制器（后来去掉），也通过 reservedKeyCodes 过滤避免冲突
- **TerminalActivator.isEnabled** — 测试时禁用，避免 AppleScript 超时（120s → 0.006s）
