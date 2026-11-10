"""Declarative Debian developer tools, executed locally by pyinfra."""

from pathlib import Path

from pyinfra.operations import brew, files

brew.packages(
    name="Remove the migrated Debian Dagger CLI",
    packages=["dagger"],
    present=False,
)

files.file(
    name="Remove the obsolete standalone Debian Dagger CLI",
    path=str(Path.home() / ".local/bin/dagger"),
    present=False,
)

files.line(
    name="Expose Homebrew packages in interactive Bash",
    path=str(Path.home() / ".bashrc"),
    line=r"^eval .*linuxbrew/.linuxbrew/bin/brew shellenv bash.*$",
    replace='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"',
    present=True,
    ensure_newline=True,
)
