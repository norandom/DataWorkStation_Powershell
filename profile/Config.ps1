# Shell behavior: readline editing, completion, prompt, and native command precedence.

# Tool-specific user and WPT directories are deterministic profile dependencies.
# Add only directories that exist and avoid duplicating an existing PATH entry.
$managedToolPaths = @(
    (Join-Path $env:USERPROFILE '.local\bin'),
    (Join-Path $env:USERPROFILE '.dotnet\tools'),
    (Join-Path $env:APPDATA 'npm'),
    'C:\Program Files\nodejs',
    'C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit'
)
foreach ($managedToolPath in $managedToolPaths) {
    if ((Test-Path -LiteralPath $managedToolPath -PathType Container) -and
        -not (($env:PATH -split ';') -contains $managedToolPath)) {
        $env:PATH = "$managedToolPath;$env:PATH"
    }
}
Remove-Variable managedToolPaths, managedToolPath -ErrorAction Ignore

# PSReadLine: Emacs/readline editing, searchable history and menu completion.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Emacs -BellStyle None -HistorySearchCursorMovesToEnd

    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Shift+Tab -Function TabCompletePrevious
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord Ctrl+r -Function ReverseSearchHistory

    # PSReadLine 2.1+ can show fish/Kali-like history suggestions. Windows
    # PowerShell 5.1 ships an older version, so enable this only when supported.
    $psReadLineOptions = (Get-Command Set-PSReadLineOption).Parameters
    if ($psReadLineOptions.ContainsKey('PredictionSource') -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
    }
    if ($psReadLineOptions.ContainsKey('PredictionViewStyle') -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
}

# Prefer native Unix-style commands over Windows PowerShell's built-in aliases.
# An alias is removed only when the corresponding executable actually exists.
$nativeCommands = @(
    'cat', 'cp', 'cut', 'date', 'dir', 'echo', 'env', 'expand', 'factor',
    'false', 'head', 'hostname', 'join', 'link', 'ln', 'ls', 'md5sum',
    'mkdir', 'mktemp', 'mv', 'nl', 'nproc', 'od', 'paste', 'pathchk',
    'printenv', 'printf', 'pwd', 'readlink', 'realpath', 'rm', 'rmdir',
    'sha1sum', 'sha256sum', 'sha512sum', 'sleep', 'sort', 'split', 'stat',
    'sum', 'tac', 'tail', 'tee', 'test', 'touch', 'tr', 'true', 'truncate',
    'uname', 'uniq', 'wc', 'whoami'
)

foreach ($commandName in $nativeCommands) {
    if ((Get-Command "$commandName.exe" -CommandType Application -ErrorAction Ignore) -and
        (Test-Path "Alias:$commandName")) {
        Remove-Item "Alias:$commandName" -Force
    }
}

# Windows includes curl.exe, while Windows PowerShell 5.1 masks it with curl/wget aliases.
if (Get-Command curl.exe -CommandType Application -ErrorAction Ignore) {
    foreach ($commandName in 'curl', 'wget') {
        if (Test-Path "Alias:$commandName") {
            Remove-Item "Alias:$commandName" -Force
        }
    }

    function global:wget { & curl.exe @args }
}

function global:prompt {
    "$env:USERNAME@$env:COMPUTERNAME $($executionContext.SessionState.Path.CurrentLocation)> "
}
