"""Declarative Debian developer tools, executed locally by pyinfra."""

from pathlib import Path

from pyinfra.operations import brew, files


brew.tap(
    name="Add the official Dagger Homebrew tap",
    src="dagger/tap",
)

brew.packages(
    name="Install the Dagger CLI",
    packages=["dagger"],
    present=True,
)

files.line(
    name="Expose Homebrew packages in interactive Bash",
    path=str(Path.home() / ".bashrc"),
    line=r"^eval .*linuxbrew/.linuxbrew/bin/brew shellenv bash.*$",
    replace='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"',
    present=True,
    ensure_newline=True,
)
