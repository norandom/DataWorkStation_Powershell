[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[^\s@]+@[^\s@]+$')]
    [string] $Destination,
    [Alias('i')][string] $IdentityFile,
    [Alias('p')][ValidateRange(1,65535)][int] $Port = 22,
    [string[]] $Option
)

$ErrorActionPreference = 'Stop'
if (-not $IdentityFile) {
    $IdentityFile = @('id_ed25519.pub','id_ecdsa.pub','id_rsa.pub') |
        ForEach-Object { Join-Path (Join-Path $env:USERPROFILE '.ssh') $_ } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
}
if (-not $IdentityFile -or -not (Test-Path -LiteralPath $IdentityFile -PathType Leaf)) {
    throw 'No public key found. Use -IdentityFile or create one with ssh-keygen.'
}
if ($IdentityFile -notlike '*.pub' -and (Test-Path -LiteralPath "$IdentityFile.pub")) { $IdentityFile = "$IdentityFile.pub" }
$publicKey = (Get-Content -LiteralPath $IdentityFile -Raw).Trim()
if ($publicKey -notmatch '^(ssh-|ecdsa-|sk-)[A-Za-z0-9@._+-]+\s+[A-Za-z0-9+/=]+(?:\s+.*)?$') {
    throw "The selected file does not contain a supported OpenSSH public key: $IdentityFile"
}

$arguments = @('-p', "$Port")
foreach ($value in $Option) { $arguments += @('-o', $value) }
$arguments += @($Destination, 'sh -s')

# Send the complete remote shell program over standard input. This prevents
# Windows OpenSSH from reparsing quotes around the public-key variable.
$delimiter = 'SSH_COPY_ID_' + [Guid]::NewGuid().ToString('N')
$remoteScript = @'
set -eu
stage="initialization"
umask 077
ssh_dir="$HOME/.ssh"
auth_file="$ssh_dir/authorized_keys"
key_file="$ssh_dir/.ssh-copy-id-key.$$"
new_file="$ssh_dir/.ssh-copy-id-auth.$$"
cleanup() {
    status=$?
    trap - 0 1 2 15
    rm -f "$key_file" "$new_file"
    if [ "$status" -ne 0 ]; then
        printf 'ssh-copy-id: remote failure during %s (exit %s)\n' "$stage" "$status" >&2
    fi
    exit "$status"
}
trap cleanup 0 1 2 15

stage="creating $ssh_dir"
mkdir -p "$ssh_dir"
chmod 700 "$ssh_dir"
touch "$auth_file"
chmod 600 "$auth_file"

stage="receiving the public key"
cat > "$key_file" <<'__KEY_DELIMITER__'
__PUBLIC_KEY__
__KEY_DELIMITER__
key=$(cat "$key_file")

contains_key() {
    while IFS= read -r existing || [ -n "$existing" ]; do
        if [ "$existing" = "$key" ]; then
            return 0
        fi
    done < "$auth_file"
    return 1
}

if ! contains_key; then
    stage="normalizing authorized_keys"
    : > "$new_file"
    while IFS= read -r existing || [ -n "$existing" ]; do
        printf '%s\n' "$existing" >> "$new_file"
    done < "$auth_file"

    stage="installing the public key"
    printf '%s\n' "$key" >> "$new_file"
    cat "$new_file" > "$auth_file"
    chmod 600 "$auth_file"
fi

stage="verifying the public key"
contains_key
'@
$remoteScript = $remoteScript.Replace('__KEY_DELIMITER__', $delimiter).Replace('__PUBLIC_KEY__', $publicKey)
$remoteScript = $remoteScript.Replace("`r`n", "`n")
$sshPath = (Get-Command ssh.exe -CommandType Application -ErrorAction Stop).Source
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $sshPath
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardInput = $true
if ($null -ne $startInfo.PSObject.Properties['ArgumentList']) {
    foreach ($argument in $arguments) { [void]$startInfo.ArgumentList.Add($argument) }
} else {
    # Windows PowerShell 5.1 uses .NET Framework and exposes only one command-line
    # string property. Escape it according to CommandLineToArgvW rules.
    function ConvertTo-WindowsProcessArgument {
        param([AllowEmptyString()][string] $Value)
        if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }

        $builder = [Text.StringBuilder]::new()
        [void]$builder.Append('"')
        $backslashes = 0
        foreach ($character in $Value.ToCharArray()) {
            if ($character -eq [char]92) {
                $backslashes++
            } elseif ($character -eq [char]34) {
                [void]$builder.Append([char]92, (2 * $backslashes + 1))
                [void]$builder.Append([char]34)
                $backslashes = 0
            } else {
                if ($backslashes) { [void]$builder.Append([char]92, $backslashes) }
                [void]$builder.Append($character)
                $backslashes = 0
            }
        }
        if ($backslashes) { [void]$builder.Append([char]92, (2 * $backslashes)) }
        [void]$builder.Append('"')
        return $builder.ToString()
    }
    $startInfo.Arguments = (($arguments | ForEach-Object { ConvertTo-WindowsProcessArgument $_ }) -join ' ')
}
$process = [Diagnostics.Process]::Start($startInfo)
try {
    $process.StandardInput.NewLine = "`n"
    $process.StandardInput.Write($remoteScript)
    $process.StandardInput.Write("`n")
    $process.StandardInput.Close()
    $process.WaitForExit()
    $exitCode = $process.ExitCode
} finally {
    $process.Dispose()
}
if ($exitCode -ne 0) { throw "ssh-copy-id failed with exit code $exitCode." }
Write-Host "Public key installed for $Destination from $IdentityFile"
