@{
    Package = 'skillopt'
    Version = '0.2.0'
    Python = '3.12'
    UserConfig = @{
        transcript_source = 'codex'
        projects = 'invoked'
        lookback_hours = 72
        max_tasks_per_night = 3
        backend = 'mock'
        gate_mode = 'on'
        gate_metric = 'mixed'
        gate_no_regression = $true
        edit_budget = 4
        dream_rollouts = 1
        dream_factor = 0
        recall_k = 0
        evolve_memory = $false
        evolve_skill = $true
        target_task_filter = $true
        evidence_log = $false
        multi_skill_report = $false
        auto_adopt = $false
        redact_secrets = $true
        seed = 42
    }
}
