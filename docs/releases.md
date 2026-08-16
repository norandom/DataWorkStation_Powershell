# Releases and Pages

Documentation is built reproducibly from `pyproject.toml` and `uv.lock`.

## GitHub Pages

The Pages workflow builds in strict mode on pull requests and relevant pushes. A push to `main` also
deploys the generated static artifact to the `github-pages` environment.

If Pages is not enabled, open **Settings → Pages → Build and deployment** and select **GitHub
Actions** as the source. This is a one-time repository setting. The normal `GITHUB_TOKEN` cannot
enable Pages administration; the workflow handles later deployments.

## Tagged releases

Tags matching `v*.*.*` run the release workflow. It builds the same strict site and publishes two assets to a GitHub Release:

- a standalone static-site archive;
- a documentation-source archive containing MkDocs configuration and the lock files.

Prepare a release only after the main branch is green:

```powershell
$version = (Get-Content VERSION -Raw).Trim()
git tag -a "v$version" -m "DataWorkStation PowerShell v$version"
git push origin "v$version"
```

The workflow uses the tag as the release version and generates release notes from Git history.
