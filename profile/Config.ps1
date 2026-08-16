# Shell behavior: readline editing, completion, prompt, and native command precedence.

# These user-tool and WPT directories are managed profile dependencies.
# Add an entry only when the directory exists and PATH does not already contain it.
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

# Configure Emacs-style editing, searchable history, and menu completion.
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Emacs -BellStyle None -HistorySearchCursorMovesToEnd

    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Shift+Tab -Function TabCompletePrevious
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord Ctrl+r -Function ReverseSearchHistory

    # PSReadLine 2.1 and later can show history suggestions. Windows PowerShell
    # 5.1 may load an older version, so check support before enabling them.
    $psReadLineOptions = (Get-Command Set-PSReadLineOption).Parameters
    if ($psReadLineOptions.ContainsKey('PredictionSource') -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
    }
    if ($psReadLineOptions.ContainsKey('PredictionViewStyle') -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
}

# Prefer managed native commands over same-named Windows PowerShell aliases.
# Ensure generates the availability cache once. Startup validates cached paths and
# resolves only missing or stale entries, preserving the safe fallback behavior.
$nativeCommandCatalogPath = Join-Path $PSScriptRoot 'NativeCommands.psd1'
$nativeCommandCachePath = Join-Path $PSScriptRoot 'NativeCommands.cache.psd1'
$nativeCommandCatalog = Import-PowerShellDataFile -LiteralPath $nativeCommandCatalogPath
$nativeCommandNames = @($nativeCommandCatalog.Commands)
$nativeCommandCatalogKey = @(
    [string] $nativeCommandCatalog.SchemaVersion
    @($nativeCommandNames)
    [string] $nativeCommandCatalog.CurlCommand
) -join '|'
$nativeCommandCache = if (Test-Path -LiteralPath $nativeCommandCachePath -PathType Leaf) {
    Import-PowerShellDataFile -LiteralPath $nativeCommandCachePath
} else { $null }
$cachedNativeCommands = @{}
if ($nativeCommandCache -and
    $nativeCommandCache.SchemaVersion -eq 1 -and
    $nativeCommandCache.CatalogKey -eq $nativeCommandCatalogKey) {
    foreach ($entry in @($nativeCommandCache.Commands)) {
        $cachedNativeCommands[[string] $entry.Name] = [string] $entry.Path
    }
}
$pathDirectories = @($env:PATH -split ';' | ForEach-Object { $_.Trim().TrimEnd('\') } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

function Test-NativeApplicationAvailable {
    param([Parameter(Mandatory = $true)][string] $Name)

    $cachedPath = [string] $cachedNativeCommands[$Name]
    if (-not [string]::IsNullOrWhiteSpace($cachedPath) -and
        (Test-Path -LiteralPath $cachedPath -PathType Leaf) -and
        $pathDirectories -icontains (Split-Path -Parent $cachedPath).TrimEnd('\')) {
        return $true
    }
    [bool] (Get-Command "$Name.exe" -CommandType Application -ErrorAction Ignore)
}

foreach ($commandName in $nativeCommandNames) {
    if ((Test-NativeApplicationAvailable -Name $commandName) -and (Test-Path "Alias:$commandName")) {
        Remove-Item "Alias:$commandName" -Force
    }
}

# Windows supplies curl.exe, but Windows PowerShell 5.1 masks curl and wget with aliases.
# Aliases.ps1 assigns wget to the managed aria2c wrapper after removing those aliases.
if (Test-NativeApplicationAvailable -Name $nativeCommandCatalog.CurlCommand) {
    foreach ($commandName in 'curl', 'wget') {
        if (Test-Path "Alias:$commandName") {
            Remove-Item "Alias:$commandName" -Force
        }
    }
}
Remove-Item Function:Test-NativeApplicationAvailable -ErrorAction Ignore
Remove-Variable nativeCommandCatalogPath, nativeCommandCachePath, nativeCommandCatalog,
    nativeCommandNames, nativeCommandCatalogKey, nativeCommandCache, cachedNativeCommands,
    pathDirectories -ErrorAction Ignore

function Test-ContourTerminalSession {
    -not [Console]::IsOutputRedirected -and (
        $env:CONTOUR_PROFILE -or
        $env:TERMINAL_NAME -match '^Contour$'
    )
}

function Format-TerminalHyperlink {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][uri] $Uri
    )

    if (-not (Test-ContourTerminalSession)) { return $Text }
    $escape = [char] 27
    "$escape]8;;$($Uri.AbsoluteUri)$escape\$Text$escape]8;;$escape\"
}

function global:Show-TerminalLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][uri] $Uri,
        [Parameter(Position = 1)][string] $Text
    )

    if (-not $Text) { $Text = $Uri.OriginalString }
    Format-TerminalHyperlink -Text $Text -Uri $Uri
}
Set-Alias -Name terminal-link -Value Show-TerminalLink -Scope Global

function global:prompt {
    $location = $executionContext.SessionState.Path.CurrentLocation
    $locationText = [string] $location
    if (Test-ContourTerminalSession) {
        $escape = [char] 27
        Write-Host -NoNewline "$escape[>M"
        if ($location.Provider.Name -eq 'FileSystem') {
            $locationText = Format-TerminalHyperlink -Text $locationText -Uri ([uri] $location.ProviderPath)
        }
    }
    "$env:USERNAME@$env:COMPUTERNAME $locationText> "
}
