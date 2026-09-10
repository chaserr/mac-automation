# chatgpt-morning-chat

每天 06:02 打开 ChatGPT 客户端，新建会话并发一条 `hi`，用来触发账号当天的滚动 5 小时用量窗口（06→11→16，一天三段）。

- `open_chatgpt_and_chat.applescript` — 源脚本（打开 App → Cmd+N 新会话 → 输入并回车）
- 由 LaunchAgent `com.local.open-chatgpt` 调度（见 `../launch-agents/`）

## 部署

```bash
# 编译成 .app（Accessibility 权限授给这个 .app，而非 osascript）
osacompile -o ~/scripts/ChatGPTMorningChat.app open_chatgpt_and_chat.applescript
```

LaunchAgent 的 ProgramArguments 指向 `open ~/scripts/ChatGPTMorningChat.app`。

## 一次性手动步骤（必须）

ChatGPT 客户端无脚本 API，靠模拟键盘发消息，需要辅助功能权限：

**System Settings → Privacy & Security → Accessibility → 打开 `ChatGPTMorningChat` 开关。**

没授权时 App 会打开但消息发不出去。授权后手动测一次：

```bash
open ~/scripts/ChatGPTMorningChat.app
```

## 调参

发消息落在错误位置 → 调大 `open_chatgpt_and_chat.applescript` 里的 `launchStartupDelay`（冷启动更慢）。改完重新 `osacompile`。
