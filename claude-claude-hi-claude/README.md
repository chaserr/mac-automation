# Claude Morning Wake Automation

每天早上 6:50 自动唤醒 Mac、打开 Terminal、运行 `claude`，并输入 `hi` 激活对话。

## 工作原理

| 组件 | 作用 |
|------|------|
| `pmset repeat wakeorpoweron` | 让 macOS 固件在每天 6:50 将电脑从休眠/关机状态唤醒/开机 |
| LaunchAgent (`com.local.claude-hi`) | 用户登录后在 6:50 触发脚本（`RunAtLoad=true` 确保唤醒后登录也能补跑） |
| `run_claude_hi.sh` | 时间窗口守卫（06:45–07:20），防止非早晨触发 |
| `claude_hi.applescript` | 打开 Terminal → 运行 `claude` → 等待 TUI 就绪 → 用 System Events 输入 `hi` + 回车 |

## 安装

### 第 0 步（可选）：让电脑跳过登录/锁屏自动进入桌面

> **仅当你希望电脑在无人值守时也能完成登录时才需要此步骤。**
> 要求：FileVault 必须关闭。

```sh
chmod +x setup_autologin.sh
./setup_autologin.sh
```

脚本会做两件事：
1. **自动登录**：写入 `/etc/kcpassword`，让 macOS 开机/pmset poweron 后跳过登录界面直接进桌面
2. **禁用锁屏**：设置睡眠/屏保唤醒后不要求输入密码

如果不想执行脚本，也可以在图形界面手动设置：
- **登录界面**：System Settings → General → Login Options → Automatically log in as → 选择你的用户
- **锁屏**：System Settings → Lock Screen → "Require password after screen saver begins..." → Never

### 第 1 步：安装主自动化脚本

```sh
cd /Users/tongxing/HMProject/automation/claude-claude-hi-claude
chmod +x install_claude_hi_wakeup.sh uninstall_claude_hi_wakeup.sh run_claude_hi.sh
./install_claude_hi_wakeup.sh
```

安装时会执行 `sudo pmset repeat wakeorpoweron MTWRFSU 06:50:00`，macOS 会提示输入密码。

仅安装 LaunchAgent（跳过唤醒调度）：

```sh
SKIP_PMSET=1 ./install_claude_hi_wakeup.sh
```

## 首次权限授权（必做）

首次运行 AppleScript 控制 Terminal 时，macOS 会弹出权限请求。如果没有弹出或被拒绝，手动开启：

**System Settings → Privacy & Security → Automation**
→ 勾选允许 `osascript` 或 `Terminal` 控制 `Terminal`

**System Settings → Privacy & Security → Accessibility**
→ 如果 System Events 无法发送按键，在此添加 Terminal

## 测试

```sh
./run_claude_hi.sh --force
```

如果 `claude` 启动超过 10 秒才显示输入框，编辑 `claude_hi.applescript` 中的 `startupDelaySeconds`。

## 卸载

```sh
./uninstall_claude_hi_wakeup.sh
```

仅移除 LaunchAgent，不影响 pmset 唤醒计划。

同时取消唤醒计划：

```sh
./uninstall_claude_hi_wakeup.sh --cancel-wake-schedule
```

## 重要限制

- **FileVault 加密**：FileVault 开启时无法使用自动登录（`setup_autologin.sh` 会报错退出）。启用 FileVault 后唤醒必然停在解锁界面，需要人工干预。
- **`pmset repeat` 覆盖**：只能设置一条重复唤醒规则，安装前用 `pmset -g sched` 检查是否已有计划。
- **完全关机**：`pmset repeat wakeorpoweron` 支持定时开机（需固件/SMC支持），但成功率不如睡眠唤醒，建议用睡眠而非关机。
- **锁屏 vs 登录界面**：`setup_autologin.sh` 同时处理两者；若只设置了自动登录但没有禁用锁屏，睡眠唤醒仍会停在锁屏。
