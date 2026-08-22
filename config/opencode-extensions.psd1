@{
    SchemaVersion = 1
    ConfigRoot = '%USERPROFILE%\.config\opencode'
    CacheRoot = 'state\opencode-extensions'
    Themes = @{
        Repository = 'norandom/opencode-cream-blue'
        Commit = '7cef8d00dccd2c459df6bc1fe867a80bef668790'
        Default = 'cream-blue-cobalt'
        Files = @(
            @{
                Name = 'cream-blue-cobalt'
                File = 'cream-blue-cobalt.json'
                Uri = 'https://raw.githubusercontent.com/norandom/opencode-cream-blue/7cef8d00dccd2c459df6bc1fe867a80bef668790/.opencode/themes/cream-blue-cobalt.json'
                Sha256 = '36a0d1a6c11d43bfcd74d68ccaa6eef75085e317bffe9afe84a27a361f699687'
            }
            @{
                Name = 'cream-blue-dark'
                File = 'cream-blue-dark.json'
                Uri = 'https://raw.githubusercontent.com/norandom/opencode-cream-blue/7cef8d00dccd2c459df6bc1fe867a80bef668790/.opencode/themes/cream-blue-dark.json'
                Sha256 = '4ab299427713c06a9ed6f0774a90c3faa104375d6650d8a8cecfa7c199705c28'
            }
            @{
                Name = 'cream-blue-light'
                File = 'cream-blue-light.json'
                Uri = 'https://raw.githubusercontent.com/norandom/opencode-cream-blue/7cef8d00dccd2c459df6bc1fe867a80bef668790/.opencode/themes/cream-blue-light.json'
                Sha256 = '2202eb94eae1933a9a7305a446c6aefb0f05a1aa188296be2b7dd7e1aabbf0d7'
            }
        )
    }
    OpenUltraCode = @{
        Repository = 'norandom/OpenUltraCode'
        Version = '0.1.3'
        Uri = 'https://github.com/norandom/OpenUltraCode/releases/download/v0.1.3/open-ultracode-release.tar.gz'
        Asset = 'open-ultracode-release.tar.gz'
        Sha256 = 'e0d70ac08f42af77cb8ce0999f7397efbd1a9c0a95cf7fe3dd4553f7ad2dcb30'
        InstallRoot = '%USERPROFILE%\.local\share\open-ultracode'
        InventorySha256 = '2a20c9a8db6496fca46890b5265386f8d39613442e0b38927ac6f89f99eee41e'
        FileCount = 46
        PluginRelativePath = '.opencode\plugins\open-ultracode.ts'
        Commands = @(
            'ultracode-debug.md', 'ultracode-fusion.md', 'ultracode-research.md',
            'ultracode-spec-audit.md', 'ultracode-verify.md', 'ultracode.md',
            'ultrathink-fusion.md', 'ultrathink.md'
        )
        Agents = @(
            'open-ultracode-adversary.md', 'open-ultracode-implementer.md',
            'open-ultracode-planner.md', 'open-ultracode-reconciler.md',
            'open-ultracode-researcher.md', 'open-ultracode-verifier.md',
            'open-ultracode.md', 'ultracode-fusion-arbiter.md',
            'ultracode-fusion-panel-a.md', 'ultracode-fusion-panel-b.md'
        )
        FusionModels = @{
            'ultracode-fusion-panel-a.md' = 'openai/gpt-5'
            'ultracode-fusion-panel-b.md' = 'openai/gpt-5'
            'ultracode-fusion-arbiter.md' = 'openai/gpt-5'
        }
        SkillRelativePath = 'open-ultracode\SKILL.md'
    }
}
