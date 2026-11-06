# Yogosha build of helm-diff

This branch only holds the tooling that rebuilds [databus23/helm-diff](https://github.com/databus23/helm-diff)
releases with every Go dependency bumped, to keep the plugin free of known CVEs.

- `.github/workflows/yogosha-release.yml`: every Monday (or on demand), takes the latest upstream
  release, bumps all dependencies (`yogosha/bump.sh`), runs vet/tests, fails if trivy still finds a
  fixable HIGH/CRITICAL vulnerability, then publishes `<upstream tag>-yogosha.<n>` here. Nothing is
  released when neither upstream, the Go toolchain nor the dependencies changed.
- `yogosha/overrides.txt`: minimum versions for modules whose CVE fix is not tagged yet.
- `yogosha/bump.sh`: `HOLD` lists modules kept at the upstream version (they must move with `k8s.io/*`).

Each release tag is a standalone commit (upstream snapshot + bump), so `master` stays an untouched
mirror of upstream and there is never anything to merge.

## Install

```sh
helm plugin install https://github.com/Yogosha/helm-diff --version v3.15.15-yogosha.1
```

The install/update hooks of these releases download binaries from this repository.

## Run manually

```sh
gh workflow run yogosha-release.yml -R Yogosha/helm-diff                      # latest upstream release
gh workflow run yogosha-release.yml -R Yogosha/helm-diff -f upstream_ref=v3.15.15 -f force=true
```
