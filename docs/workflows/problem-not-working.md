# Something is not working

Create a case when the symptom crosses tool boundaries or needs review by another operator or an AI:

```powershell
tricky new import-failure -Problem 'The import worker exits without output' -Target 'worker.exe'
tricky add import-failure -Path ./eventlog-import-failure
tricky inspect import-failure
tricky note import-failure -NoteType Observation -Message 'The process remains responsive; the operation returns an error.'
tricky report import-failure -Open
```

The routing rule is simple:

1. Inventory existing evidence.
2. Check whether its time window contains the failure.
3. Extract observations without assuming a cause.
4. State gaps explicitly.
5. Recommend one minimal capture, with the exact command and stop condition.

Record the executable/build, effective user/SID, failure time and comparison with a working machine
before changing state. For HTTP/TLS/authentication failures, use the [HTTP workflow](http-authentication.md).
An error dialog does not imply a crash. Check provider/target event coverage before requesting repeated
reproductions; an empty ETL is failed evidence collection, not proof that no error occurred.

`tricky note` accepts `-NoteType Observation`, `Hypothesis`, `Contradiction`, `Change`, `Result` or
`NextStep`, a required `-Message`, and optional `-Path` linking existing evidence. These notes appear
in human, JSON and HTML reports. A Change should state the original value, backup location, predicted
effect and rollback plan; follow it with a Result and rollback decision. Do not store credentials in notes.

If no capability-specific trigger matches, start with `problems` and `crashes`. A generic failure is not a reason to start every tracer.
