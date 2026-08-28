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

# PowerShell's default directory style uses a blue background, which is hard to read on the
# managed Blue terminal theme. Keep semantic styling in PowerShell and leave terminal palettes
# unchanged; native ls retains its own color configuration.
if ($PSVersionTable.PSEdition -eq 'Core') {
    $PSStyle.FileInfo.Directory = $PSStyle.Foreground.BrightCyan
}

# Prefer managed native commands over same-named PowerShell aliases and convenience functions.
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
    if (Test-NativeApplicationAvailable -Name $commandName) {
        foreach ($commandProvider in 'Alias', 'Function') {
            $shadowPath = "${commandProvider}:$commandName"
            if (Test-Path $shadowPath) { Remove-Item $shadowPath -Force }
        }
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
    pathDirectories, commandProvider, shadowPath -ErrorAction Ignore

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

function ConvertTo-GrmlPromptSafeText {
    param([AllowEmptyString()][string] $Text)

    if ($null -eq $Text) { return '' }
    [regex]::Replace($Text, '[\x00-\x1f\x7f]', '?')
}

function ConvertTo-GrmlPromptPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [AllowEmptyString()][string] $HomePath = $HOME,
        [ValidateRange(8, 260)][int] $MaximumLength = 40
    )

    $pathText = ConvertTo-GrmlPromptSafeText -Text $Path
    if (-not [string]::IsNullOrWhiteSpace($HomePath)) {
        $normalizedHome = (ConvertTo-GrmlPromptSafeText -Text $HomePath).TrimEnd([char[]] @('\', '/'))
        if ($pathText.Equals($normalizedHome, [StringComparison]::OrdinalIgnoreCase)) {
            $pathText = '~'
        } elseif ($pathText.StartsWith("$normalizedHome\", [StringComparison]::OrdinalIgnoreCase) -or
            $pathText.StartsWith("$normalizedHome/", [StringComparison]::OrdinalIgnoreCase)) {
            $pathText = '~' + $pathText.Substring($normalizedHome.Length)
        }
    }

    if ($pathText.Length -gt $MaximumLength) {
        $pathText = '..' + $pathText.Substring($pathText.Length - ($MaximumLength - 2))
    }
    $pathText
}

function Test-GrmlPromptColorSupport {
    if ([Console]::IsOutputRedirected) { return $false }
    if (Test-ContourTerminalSession) { return $true }
    $supportsVirtualTerminal = $Host.UI.PSObject.Properties['SupportsVirtualTerminal']
    if ($supportsVirtualTerminal) { return [bool] $supportsVirtualTerminal.Value }
    [bool] $env:WT_SESSION
}

function Test-GrmlPromptAdministrator {
    $identity = $null
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        $false
    } finally {
        if ($identity) { $identity.Dispose() }
    }
}

function Get-GrmlPromptVcsInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string] $Path)

    $git = Get-Command git.exe -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $git) { return }

    $savedExitCode = $global:LASTEXITCODE
    try {
        $reference = @(& $git.Source -C $Path symbolic-ref --quiet --short HEAD 2>$null)
        if ($LASTEXITCODE -ne 0) {
            $reference = @(& $git.Source -C $Path rev-parse --short HEAD 2>$null)
        }
        if ($LASTEXITCODE -eq 0 -and $reference.Count -gt 0) {
            [pscustomobject]@{
                Kind = 'git'
                Reference = ([string] ($reference -join '')).Trim()
            }
        }
    } finally {
        $global:LASTEXITCODE = $savedExitCode
    }
}

function Format-GrmlPromptText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $UserName,
        [Parameter(Mandatory = $true)][string] $ComputerName,
        [Parameter(Mandatory = $true)][string] $PathText,
        [AllowEmptyString()][string] $VcsKind = '',
        [AllowEmptyString()][string] $VcsReference = '',
        [bool] $LastCommandSucceeded = $true,
        [int] $ExitCode = 0,
        [bool] $IsAdministrator = $false,
        [bool] $UseColor = $true,
        [uri] $PathUri
    )

    $safeUser = ConvertTo-GrmlPromptSafeText -Text $UserName
    $safeComputer = ConvertTo-GrmlPromptSafeText -Text $ComputerName
    $safePath = ConvertTo-GrmlPromptSafeText -Text $PathText
    $safeVcsKind = ConvertTo-GrmlPromptSafeText -Text $VcsKind
    $safeVcsReference = ConvertTo-GrmlPromptSafeText -Text $VcsReference
    if ($PathUri) { $safePath = Format-TerminalHyperlink -Text $safePath -Uri $PathUri }

    $failureCode = if ($ExitCode -ne 0) { $ExitCode } else { 1 }
    $promptCharacter = if ($IsAdministrator) { '#' } else { '%' }
    $vcsPresent = $safeVcsKind -and $safeVcsReference

    if (-not $UseColor) {
        $status = if ($LastCommandSucceeded) { '' } else { "$failureCode " }
        $vcs = if ($vcsPresent) { " ($safeVcsKind)-[$safeVcsReference]" } else { '' }
        return "$status$safeUser@$safeComputer $safePath$vcs $promptCharacter "
    }

    $escape = [char] 27
    $reset = "$($escape)[0m"
    $bold = "$($escape)[1m"
    $red = "$($escape)[31m"
    $green = "$($escape)[32m"
    $yellow = "$($escape)[33m"
    $blue = "$($escape)[34m"
    $magenta = "$($escape)[35m"

    $status = if ($LastCommandSucceeded) { '' } else { "$bold$red$failureCode $reset" }
    $user = "$bold$blue$safeUser$reset"
    $path = "$bold$safePath$reset"
    $vcs = if ($vcsPresent) {
        " $magenta($reset$safeVcsKind$magenta)$yellow-$magenta[$green$safeVcsReference$magenta]$reset"
    } else { '' }
    "$status$user@$safeComputer $path$vcs $promptCharacter "
}

function global:prompt {
    $lastCommandSucceeded = $?
    $savedExitCode = $global:LASTEXITCODE
    $location = $executionContext.SessionState.Path.CurrentLocation
    $providerPath = if ($location.Provider.Name -eq 'FileSystem') { $location.ProviderPath } else { [string] $location }
    $locationText = ConvertTo-GrmlPromptPath -Path $providerPath
    $pathUri = $null
    if (Test-ContourTerminalSession) {
        $escape = [char] 27
        Write-Host -NoNewline "$escape[>M"
        if ($location.Provider.Name -eq 'FileSystem') {
            $pathUri = [uri] $location.ProviderPath
        }
    }

    $vcs = if ($location.Provider.Name -eq 'FileSystem') {
        Get-GrmlPromptVcsInfo -Path $location.ProviderPath
    }
    $exitCode = if ($lastCommandSucceeded) { 0 } elseif ($savedExitCode -and $savedExitCode -ne 0) {
        [int] $savedExitCode
    } else { 1 }
    $parameters = @{
        UserName = if ($env:USERNAME) { $env:USERNAME } else { [Environment]::UserName }
        ComputerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [Environment]::MachineName }
        PathText = $locationText
        VcsKind = if ($vcs) { $vcs.Kind } else { '' }
        VcsReference = if ($vcs) { $vcs.Reference } else { '' }
        LastCommandSucceeded = $lastCommandSucceeded
        ExitCode = $exitCode
        IsAdministrator = Test-GrmlPromptAdministrator
        UseColor = Test-GrmlPromptColorSupport
        PathUri = $pathUri
    }
    $promptText = Format-GrmlPromptText @parameters
    $global:LASTEXITCODE = $savedExitCode
    $promptText
}
