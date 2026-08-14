# Contour 0.6.3.8249 crashes during initial window rendering on Windows 11

## Summary

Contour 0.6.3.8249 reliably exits within approximately four seconds of launch on this Windows 11 system. Every normal launch produces an initial `0xc0000005` access violation followed by `0xc000041d`, both at offset `0x342f6` in `Qt6OpenGL.dll` 6.9.3.

The failure reproduces with both the Scoop Extras ZIP distribution and the official `contour-0.6.3.8249-win64.msi` from the [v0.6.3.8249 release](https://github.com/contour-terminal/contour/releases/tag/v0.6.3.8249). Replacing the Scoop installation with the official MSI did not change the faulting module, exception offsets, or observable startup behavior.

## Environment

- Contour: `0.6.3.8249`
- Distribution currently installed: official x64 MSI
- MSI product code: `{0E736497-2B72-4117-95E9-54EC6D000603}`
- MSI SHA-256: `5c8b55c5580a3e263c971c6a9a3ced35014d94b210305a8cb5099177fb89e6a0`
- Installed `contour.exe` SHA-256: `399ad8fc7b13cafebbd0c77d499ea465fde397c10aae803a5fef52edd30b51b9`
- `Qt6OpenGL.dll`: version `6.9.3.0`, SHA-256 `2dbcc6b28480c186fd0c9f47b1987e85da3487861e1e0e76326b2cb68e183e81`
- OS: Windows 11 Pro 25H2, x64, build `26200.9168`
- CPU: AMD Ryzen AI 9 HX 370
- GPU: AMD Radeon 890M
- GPU driver: `32.0.13031.3015`, dated 2025-02-25

The AMD display-driver modules were loaded in the dumped process but do not appear on the captured failing stack. The current evidence therefore does not establish the display driver as the cause.

## Reproduction

1. Install `contour-0.6.3.8249-win64.msi` from the official release.
2. Save the configuration included below as `%LOCALAPPDATA%\contour\contour.yml`.
3. Run:

   ```powershell
   & 'C:\Program Files\Contour Terminal Emulator 0.6\bin\contour.exe'
   ```

4. Observe that the window starts and the process exits within approximately four seconds.

The non-GUI version command succeeds and prints `Contour Terminal Emulator 0.6.3.8249`.

## Expected behavior

The initial terminal window should finish rendering and remain usable.

## Actual behavior

The process exits during initial window rendering. Windows records two consecutive Application Error events for a single launch:

| Stage | Exception | Module | Module offset |
|---|---|---|---|
| Initial fault | `0xc0000005` | `Qt6OpenGL.dll` | `0x342f6` |
| Unhandled callback exception | `0xc000041d` | `Qt6OpenGL.dll` | `0x342f6` |

The final process exit status is `0xC000041D` (`STATUS_FATAL_USER_CALLBACK_EXCEPTION`). The same event pair and offsets were observed repeatedly from both installation paths:

- Scoop: `%USERPROFILE%\scoop\apps\contour\current\contour.exe`
- MSI: `%ProgramFiles%\Contour Terminal Emulator 0.6\bin\contour.exe`

## Dump analysis

A full process dump was captured from the Scoop-distributed executable during the first-chance `0xc0000005`. The official MSI reproduction was verified separately through Windows Application Error events; no claim is made that the two package layouts are byte-for-byte identical.

WinDbg identifies a null-pointer read in `QOpenGLShaderProgram::uniformLocation`:

```text
rax=00003885244149bd rbx=000001c7d5e84430 rcx=0000000000000000
rip=00007fff615442f6 rsp=0000002a595f83b0

Qt6OpenGL!QOpenGLShaderProgram::uniformLocation+0x6:
00007fff`615442f6 488b4908 mov rcx,qword ptr [rcx+8]

ExceptionCode: c0000005 (Access violation)
Attempt to read from address 0000000000000008
```

The relevant stack is:

```text
Qt6OpenGL!QOpenGLShaderProgram::uniformLocation+0x6
contour+0x4f2c3b
contour+0x4fb9d5
contour+0x4dbb16
Qt6Core!QObject::qt_static_metacall+0x1591
Qt6Core!QMetaObject::activate+0x84
Qt6Quick!QQuickWindowPrivate::renderSceneGraph+0x30f
Qt6Quick!QSGRenderLoop::qt_metacast+0xc66
Qt6Quick!QSGRenderLoop::cleanup+0xf66
Qt6Gui!QWindow::event+0x2f6
Qt6Quick!QQuickWindow::event+0x1633
```

WinDbg's failure bucket is:

```text
INVALID_POINTER_READ_c0000005_Qt6OpenGL.dll!QOpenGLShaderProgram::uniformLocation
```

The captured state shows `rcx == 0` at the failing instruction, which then attempts to read address `0x8`. The stack places three Contour frames immediately above `QOpenGLShaderProgram::uniformLocation` and below Qt's scene-graph rendering path. This suggests that a Contour render callback is using a null or no-longer-valid shader-program object, but private symbols are required to identify the exact Contour method.

Microsoft public symbols were loaded where available. `Qt6OpenGL.dll` was resolved from export symbols, but matching private PDBs for Contour and Qt were not available from the Microsoft symbol server. The three Contour frames can therefore only be reported as module-relative offsets.

## Troubleshooting already performed

- Replaced the Scoop Extras package with the official MSI. The crash remained at `Qt6OpenGL.dll+0x342f6`.
- Adding a `renderer.backend: software` configuration override did not change the `Qt6OpenGL.dll` fault. The release may have ignored that setting.
- Launching with `QT_QUICK_BACKEND=software` still crashed, but moved the observed event fault to `Qt6Gui.dll+0x359cf0`. That test was reverted.
- The managed color configuration was restored after each rendering-backend test.
- No application compatibility modes, DLL injection tools, or persistent debugger registrations were enabled.

## Configuration

The crash was captured with this configuration. Whether the same failure occurs with the user configuration completely removed has not yet been isolated, so the configuration should be considered a possible trigger.

```yaml
default_profile: main

profiles:
  main:
    shell: "pwsh.exe"
    initial_working_directory: "~"
    terminal_size:
      columns: 80
      lines: 25
    history:
      limit: -1
      auto_scroll_on_update: true
      scroll_multiplier: 3
    font:
      size: 17
    draw_bold_text_with_bright_colors: true
    cursor:
      shape: "bar"
      blinking: false
    bell:
      sound: "off"
      alert: true
    environment:
      TERM: "xterm-256color"
    colors: default
  blue-dark:
    colors: "Blue Dark"

color_schemes:
  default:
    default:
      background: '#00347F'
      foreground: '#FFDF99'
    cursor:
      default: '#FFFFFF'
      text: CellBackground
    selection:
      foreground: CellForeground
      foreground_alpha: 1.0
      background: '#B3D7FF'
      background_alpha: 1.0
    normal:
      black: '#14191E'
      red: '#B43C2A'
      green: '#00C200'
      yellow: '#C7C400'
      blue: '#E0C3E7'
      magenta: '#C040BE'
      cyan: '#00C5C7'
      white: '#C7C7C7'
    bright:
      black: '#686868'
      red: '#DD7975'
      green: '#58E790'
      yellow: '#ECE100'
      blue: '#A7ABF2'
      magenta: '#E17EE1'
      cyan: '#60FDFF'
      white: '#FFFFFF'
  Blue Dark:
    default:
      background: '#15191F'
      foreground: '#DCDCDC'
    cursor:
      default: '#FFFFFF'
      text: CellBackground
    selection:
      foreground: CellForeground
      foreground_alpha: 1.0
      background: '#B3D7FF'
      background_alpha: 1.0
    normal:
      black: '#14191E'
      red: '#B43C2A'
      green: '#00C200'
      yellow: '#C7C400'
      blue: '#2744C7'
      magenta: '#C040BE'
      cyan: '#00C5C7'
      white: '#C7C7C7'
    bright:
      black: '#686868'
      red: '#DD7975'
      green: '#58E790'
      yellow: '#ECE100'
      blue: '#A7ABF2'
      magenta: '#E17EE1'
      cyan: '#60FDFF'
      white: '#FFFFFF'
```

## Request to maintainers

Could you please:

1. map `contour+0x4f2c3b`, `contour+0x4fb9d5`, and `contour+0x4dbb16` to the corresponding functions in v0.6.3.8249;
2. check the shader-program lifetime/null handling in the render callback leading into `QQuickWindowPrivate::renderSceneGraph`;
3. confirm the supported method for forcing a non-OpenGL Qt Quick backend on Windows for this release; and
4. advise whether private PDBs or a symbol package for the Windows release can be provided.

A 421 MB full dump and complete WinDbg analysis log are available privately if needed. The dump is not attached publicly because it can contain process memory and user-specific data.
