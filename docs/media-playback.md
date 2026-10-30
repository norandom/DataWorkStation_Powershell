# GPU-accelerated media playback

The detected GPD Pocket 4 has an AMD Ryzen AI 9 HX 370 and Radeon 890M. AMD declares hardware
decode support for H.264, H.265/HEVC, VP9, and AV1 on this processor, including 8K-class decode
profiles. The focused `Mpv` module installs the official mpv Windows CI/MSVC build from WinGet and
manages only a marked block in the user configuration. Settings outside that block are preserved.
Because the portable WinGet manifest does not publish an executable alias, the module also creates
a small `mpv.cmd` forwarder in the existing `%USERPROFILE%\.local\bin` command directory. The
executable and companion libraries remain owned by WinGet.

Inspect first, then install or repair without elevation:

```powershell
pwsh -NoProfile -File .\scripts\Set-MpvState.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Test -Module Mpv -Plan
.\Apply-Workstation.ps1 -Mode Ensure -Module Mpv
```

The managed block selects:

```ini
vo=gpu-next
gpu-api=d3d11
gpu-context=d3d11
hwdec=auto-safe
```

`gpu-next` is mpv's recommended renderer. Direct3D 11 keeps rendering on the native Windows GPU
path, and `auto-safe` selects a whitelisted hardware decoder such as D3D11VA when the codec, driver,
and file are compatible. If initialization fails, mpv falls back to software decoding rather than
making the file unplayable. The module verifies that the installed build advertises `d3d11va`; it
does not start playback during desired-state testing. See the
[mpv hardware-decoding and GPU renderer reference](https://mpv.io/manual/master/).

Play a file normally after installation:

```powershell
mpv.exe D:\Media\video.mkv
mpv.exe --msg-level=vd=debug D:\Media\video.mkv
```

The second form prints decoder selection for troubleshooting. Press `i` during playback for mpv's
statistics overlay. Hardware decode is intentionally codec-aware; forcing `auto-unsafe` or
`hwdec-codecs=all` is not part of desired state.

## Explorer video associations

The `VideoAssociations` declaration in `config/mpv.psd1` registers mpv for MP4, AVI, MKV,
MOV, WebM, MPEG, WMV and the other listed video extensions. Apply and inspect it through the
same non-privileged module:

```powershell
pwsh -NoProfile -File .\scripts\Set-MpvState.ps1 -Mode Ensure
pwsh -NoProfile -File .\scripts\Set-MpvState.ps1 -Mode Test -Json
```

Ensure writes current-user ProgID, quoted open command, icon, Open With entries and Default Apps
capabilities. It also declares the per-user extension fallback. Previous managed registry values
are saved under `state/mpv-config-backups/associations-*.xml` before changes. Test only reads state;
it asks the Windows shell which executable each extension actually resolves to, so registration
alone cannot produce a compliant result. Repeated Ensure calls preserve unrelated registry values.

Windows protects existing `UserChoice` selections. The module does not delete those keys or forge
their hashes. If another app still wins, Test and Ensure return exit code 1 and report the pending
extensions and the Default Apps URI. Choose mpv there once, then repeat Test. An existing choice
of mpv through its own registration is accepted when it resolves to the installed executable.
See [Windows Default Apps](https://support.microsoft.com/en-us/windows/apps/change-default-apps-in-windows)
and the [shell association query API](https://learn.microsoft.com/windows/win32/api/shlwapi/nf-shlwapi-assocquerystringw).

Audio, image and playlist defaults are outside this declaration. `.ts` is deliberately excluded
because it is also a TypeScript source extension; add it to the declaration only if desired.

## FFmpeg command-line processing

mpv uses FFmpeg libraries internally but does not provide the separate `ffmpeg.exe` transcoding
command. If batch conversion is needed, FFmpeg itself is the corresponding command-line tool. On
Windows it can use D3D11VA for decoding, while builds compiled with AMD Advanced Media Framework
support expose `_amf` encoders. Check the installed build instead of assuming those encoders exist:

```powershell
ffmpeg.exe -hwaccels
ffmpeg.exe -encoders | Select-String '_amf'
ffmpeg.exe -hwaccel d3d11va -i .\input.mkv -f null NUL
```

FFmpeg documents Direct3D 11 hardware devices and AMD AMF acceleration in its
[command reference](https://ffmpeg.org/ffmpeg.html) and
[platform support notes](https://ffmpeg.org/general.html). FFmpeg CLI installation is not currently
part of the workstation baseline; adding it should use a build whose reported encoder inventory
matches the intended decode or transcode job.
