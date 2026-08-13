# Releases and Pages

Documentation is built reproducibly from `pyproject.toml` and `uv.lock`.

## GitHub Pages

The Pages workflow builds in strict mode on pull requests and relevant pushes. A push to `main` additionally deploys the generated static artifact to the `github-pages` environment.

GitHub requires one repository-level bootstrap when Pages is not already enabled: open **Settings → Pages → Build and deployment** and select **GitHub Actions** as the source. The normal `GITHUB_TOKEN` deliberately cannot enable Pages administration by itself; all later deployments are handled by the workflow.

## Tagged releases

Tags matching `v*.*.*` run the release workflow. It builds the same strict site and publishes two assets to a GitHub Release:

- a standalone static-site archive;
- a documentation-source archive containing MkDocs configuration and the lock files.

Prepare a release only after the main branch is green:

```powershell
git tag -a v0.1.0 -m 'DataWorkStation PowerShell v0.1.0'
git push origin v0.1.0
```

The workflow uses the tag as the release version and generates release notes from Git history.
