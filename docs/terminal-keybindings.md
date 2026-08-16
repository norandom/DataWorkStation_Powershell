# Terminal keyboard and scrolling

Terminal shortcuts and application bindings are separate. PowerShell, Codex, or another full-screen
application may consume plain arrow and page keys. Terminal scrollback shortcuts still work when the
application has produced scrollback history.

## Inspect the active bindings

Use human-readable commands before changing configuration:

```powershell
Get-PSReadLineKeyHandler | Sort-Object Key
Get-Content "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Get-Content "$env:LOCALAPPDATA\contour\contour.yml"
```

Test the managed Contour artifact without changing it:

```powershell
pwsh -NoProfile -File .\scripts\Set-ContourTerminalState.ps1 -Mode Test
```

## Scrolling in Windows Terminal and Contour

| Intent | Windows Terminal | Contour | Compact keyboard |
| --- | --- | --- | --- |
| Scroll one page up | `Ctrl+Shift+Page Up` | `Ctrl+Shift+Page Up` | `Ctrl+Shift+Fn+Up` |
| Scroll one page down | `Ctrl+Shift+Page Down` | `Ctrl+Shift+Page Down` | `Ctrl+Shift+Fn+Down` |
| Scroll with the pointer | wheel | wheel | wheel |
| Scroll a page with the pointer | not managed | `Shift+wheel` | `Shift+wheel` |
| Earliest/latest history | `Ctrl+Shift+Home` / `Ctrl+Shift+End` | `Shift+Home` / `Shift+End` | use the keyboard's `Fn` equivalent when required |

Plain `Page Up` or `Fn+Up` is application input and may be consumed by Codex or another TUI. Use the terminal chord above when the intent is terminal history. If a full-screen application uses an alternate screen without retained history, no terminal shortcut can expose output that was never added to scrollback.

### Touchscreen scrolling

Windows Terminal keeps its scrollbar visible; drag it with one finger to move through terminal history. Contour now keeps a right-side scrollbar visible on both the primary and alternate screens, which provides the same deterministic touch target. A one-finger vertical swipe may also work when Windows translates the gesture into pixel scrolling.

Contour handles unmodified wheel events only on the primary screen. In an alternate-screen
application such as Codex, it passes scroll events to the application. This provides two paths:

- At a PowerShell prompt, swipe or drag the scrollbar to move through terminal scrollback.
- In Codex or another mouse-aware TUI, swipe over the content first so the application can handle it; drag the visible scrollbar when terminal history is the intended target.

The managed `smooth_scrolling` and `momentum_scrolling` options improve pixel/gesture scrolling. Contour documents momentum specifically for touchpads, so the visible scrollbar remains the reliable touchscreen fallback.

## Managed Contour bindings

Contour 0.6.3.8249 treats the line along the bottom as a status-line tab indicator, not a clickable tab bar. The managed mouse alternative is `Alt+wheel`.

### Tabs and navigation

| Binding | Action |
| --- | --- |
| `Ctrl+Shift+T` | Create a tab. |
| `Alt+wheel up` / `Alt+wheel down` | Switch to the left/right tab. |
| `Shift+Left` / `Shift+Right` | Switch to the left/right tab. |
| `Alt+1` through `Alt+9`, `Alt+0` | Switch directly to tabs 1 through 10. |
| `Ctrl+Alt+K` / `Ctrl+Alt+J` | Jump to the previous/next PowerShell prompt mark outside the alternate screen. |

### Scrollback, selection, and search

| Binding | Action |
| --- | --- |
| wheel on the primary screen | Scroll by the configured three-line multiplier. In an alternate-screen TUI it is passed through. |
| `Shift+wheel` | Scroll one page. |
| `Shift+Up` / `Shift+Down` | Scroll one line. |
| `Shift+Page Up/Down` | Scroll one page using Contour's original binding. |
| `Ctrl+Shift+Page Up/Down` | Scroll one page using the shared Windows Terminal binding. |
| `Shift+Home` / `Shift+End` | Go to the start/end of history. |
| `Ctrl+Shift+F` | Search backwards. |
| `F3` / `Shift+F3` | Next/previous match while search is active. |
| `Ctrl+Shift+H` | Remove search highlighting. |
| `Escape` | Cancel an active selection. |
| `Ctrl+C` / `Ctrl+V` with a selection | Copy/paste and cancel the selection. |

### Links, display, and terminal operations

| Binding | Action |
| --- | --- |
| `Ctrl+click` | Follow an OSC 8 hyperlink. |
| mouse selection | Copy selected text immediately to the Windows system clipboard. |
| `Ctrl+Shift+U` | Open hint mode for detected URLs and paths. |
| middle click | Paste the selection clipboard. |
| `Ctrl+wheel` | Increase/decrease font size. |
| `Ctrl+0` | Reset font size. |
| `Alt+Enter` | Toggle fullscreen. |
| `Ctrl+Shift+,` | Open the Contour configuration. |
| `Ctrl+Alt+.` | Toggle the status line. |
| `Ctrl+Alt+O` | Open the file manager. |
| `Ctrl+Alt+S` | Capture a VT screenshot. |
| `Ctrl+Alt+,` | Toggle input-method handling. |
| `Ctrl+Shift+Space` | Enter Contour's vi normal mode. |
| `Ctrl+Shift+N` | Open a new terminal window. |
| `Ctrl+Shift+V` | Paste the clipboard. |
| `Ctrl+Alt+V` | Paste the clipboard with control characters stripped. |
| `Ctrl+Shift+Q` | Quit Contour. |

Contour's upstream default uses `Alt+wheel` to adjust opacity. The managed map assigns that pair to
tab switching and retains the rest of the pinned release's default map.

## Managed PowerShell and PSReadLine bindings

These apply at a PowerShell prompt. A terminal or full-screen application can handle the same chord before PSReadLine sees it.

### Repository overrides

| Binding | PSReadLine behavior |
| --- | --- |
| `Tab` | Show menu completion. |
| `Shift+Tab` | Select the previous completion. |
| `Up` / `Down` | Search history using the text already typed as a prefix. |
| `Ctrl+R` | Reverse-search command history. |

### Inherited Emacs editing bindings

The profile selects PSReadLine's Emacs editing mode. These useful bindings are inherited from that mode and were verified after loading the managed profile:

| Binding | PSReadLine behavior |
| --- | --- |
| `Ctrl+A` / `Home` | Move to the beginning of the line. |
| `Ctrl+E` / `End` | Move to the end of the line. |
| `Ctrl+B` / `Left` | Move back one character. |
| `Ctrl+F` / `Right` | Move forward one character. |
| `Alt+B` | Move to the beginning of the current or previous word. |
| `Backspace`, `Ctrl+H` | Delete the preceding character. |
| `Alt+Backspace` | Delete backwards to the beginning of the current or previous word. |
| `Ctrl+K` | Cut from the cursor to the end of the input line. |
| `Ctrl+L` | Clear the screen and redraw the current input. |

Use `Get-PSReadLineKeyHandler -Bound | Sort-Object Function` for the complete set provided by the installed PSReadLine version. The profile also disables the readline bell, moves the cursor to the end of a history match, and enables history prediction/list view when supported.
