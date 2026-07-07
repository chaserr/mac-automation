-- Seconds to wait after starting "proxy_on && claude" before sending "hi".
-- proxy_on + Claude TUI init can take 10-20 s on a cold start.
property startupDelaySeconds : 18

on run
	-- Open a new iTerm2 window and keep references so we can reuse the
	-- same session after the startup delay.
	tell application "iTerm"
		activate
		set newWindow to (create window with default profile)
	end tell

	-- Grab the session reference *outside* the tell-application block so the
	-- AppleEvent round-trip is short and won't time out (-1712).
	tell application "iTerm" to set claudeSession to current session of newWindow

	-- Step 1: launch proxy_on && claude in the new session.
	tell application "iTerm"
		tell claudeSession
			write text "proxy_on && /Users/tongxing/.local/bin/claude"
		end tell
	end tell

	-- Wait for Claude's interactive prompt to be ready.
	delay startupDelaySeconds

	-- Step 2: send "hi" + Return.
	-- Using iTerm2's `write text` API writes directly to the PTY, so it works
	-- inside the Claude TUI and does NOT require Accessibility permission for
	-- osascript (which is why the old System Events keystroke approach failed
	-- with "osascript is not allowed to send keystrokes" / error 1002).
	-- `write text` appends a newline by default, which submits the message.
	tell application "iTerm"
		tell claudeSession
			write text "hi"
		end tell
	end tell
end run
