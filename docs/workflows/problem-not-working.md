# Something is not working

Create a case when the symptom crosses tool boundaries or may need to be handed to an AI:

```powershell
tricky new import-failure -Problem 'The import worker exits without output' -Target 'worker.exe'
tricky add import-failure -Path ./eventlog-import-failure
tricky inspect import-failure
tricky report import-failure -Open
```

The routing rule is simple:

1. Inventory existing evidence.
2. Check whether its time window contains the failure.
3. Extract observations without assuming a cause.
4. State gaps explicitly.
5. Recommend one minimal capture, with the exact command and stop condition.

If no capability-specific trigger matches, start with `problems` and `crashes`. A generic failure is not a reason to start every tracer.
