# Memory pressure

Start with Windows commit and kernel memory, then decide whether the pressure belongs to an application, WSL, containers, or a kernel pool.

```powershell
mem
memapps
memproc
wslmem
```

- `memapps` aggregates processes by application name and sorts by private bytes.
- `memproc` shows individual processes.
- `memtop` opens the interactive system view.
- `poolmon` is appropriate when paged or nonpaged pool is unexpectedly large; `pooltag TAG` resolves known pool tags.
- `memmap` opens RAMMap when file cache, standby lists, or driver allocations need a graphical breakdown.

Do not kill the first process with a large working set automatically. Private bytes, commit pressure, mapped files, WSL VM memory, and kernel pools describe different ownership.

For a case:

```powershell
tricky new memory-growth -Problem 'Commit grows until applications fail' -Target 'worker.exe'
tricky report memory-growth -Open
```
