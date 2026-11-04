@echo off
rem Status-line git branch of the active pane. psmux 3.4.0 does not expand
rem #{pane_current_path} inside #(), so ask the server for it here instead.
for /f "delims=" %%d in ('psmux display-message -p "#{pane_current_path}" 2^>nul') do git -C "%%d" branch --show-current 2>nul
