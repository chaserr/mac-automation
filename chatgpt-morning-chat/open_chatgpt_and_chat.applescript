-- Open the ChatGPT desktop client, start a NEW conversation, and send one
-- short message. The point is only to fire the account's rolling 5-hour usage
-- window at ~06:02, so the day splits into three 5h windows (06/11/16).
--
-- ChatGPT.app exposes no scripting API, so we drive it with System Events
-- keystrokes. That requires Accessibility permission — grant it ONCE to the
-- COMPILED .app (System Settings > Privacy & Security > Accessibility), not to
-- osascript. See README.
--
-- launchStartupDelay: seconds to wait for ChatGPT to be up and focused before
-- typing. Cold start is slower; bump it if the message lands in the wrong place.
property launchStartupDelay : 6
property message : "hi"

on run
	tell application "ChatGPT" to activate
	delay launchStartupDelay

	tell application "System Events"
		tell process "ChatGPT"
			set frontmost to true
			delay 0.5
			-- New conversation
			keystroke "n" using {command down}
			delay 1.0
			-- Type the message and send it
			keystroke message
			delay 0.3
			key code 36 -- Return
		end tell
	end tell
end run
