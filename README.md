<p align="center">
  <img src="logo.png" alt="aux4" width="200">
</p>

<h1 align="center">aux4</h1>

<p align="center">GitHub Action to lint, test, publish, and cloud-deploy <a href="https://aux4.io">aux4</a> packages.</p>

## Usage

```yaml
- uses: aux4/action@v1
  with:
    command: lint

- uses: aux4/action@v1
  with:
    command: test

- uses: aux4/action@v1
  with:
    command: publish
    level: patch
    aux4_token: ${{ secrets.AUX4_ACCESS_TOKEN }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

## Commands

### lint

Validates `.aux4` configuration files for structural correctness, naming conventions, reference integrity, and best practices.

```yaml
- uses: aux4/action@v1
  with:
    command: lint
    strict: 'true'
    resolve: 'true'
```

| Input | Description | Default |
|-------|-------------|---------|
| `strict` | Treats `-local` versions as errors | `false` |
| `resolve` | Validates `aux4` command calls against installed packages | `false` |
| `format` | Output format (`text` or `json`) | `text` |

### test

Runs tests for an aux4 package using the `aux4/test` framework. Optionally enforces a coverage threshold.

```yaml
- uses: aux4/action@v1
  with:
    command: test
    build_command: 'npm run build'
    coverage_threshold: '80'
```

| Input | Description | Default |
|-------|-------------|---------|
| `test_directory` | Directory containing test files | `test` |
| `build_command` | Build command to run before testing | |
| `coverage_threshold` | Minimum step coverage % (0-100). Fails if below. `0` disables. | `0` |

When `coverage_threshold` is set to a value greater than `0`, the action runs a separate coverage step after the tests pass. If coverage is below the threshold, the step fails with:

```
Coverage 50% is below threshold 80%
```

### publish

Builds, publishes to hub.aux4.io, and creates a GitHub release.

```yaml
- uses: aux4/action@v1
  with:
    command: publish
    level: patch
    aux4_token: ${{ secrets.AUX4_ACCESS_TOKEN }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

| Input | Description | Default |
|-------|-------------|---------|
| `level` | Release level (`patch`, `minor`, `major`) | `patch` |
| `aux4_token` | aux4 access token for the target hub | *required* |
| `github_token` | GitHub token for creating releases | *required* |
| `aux4_image` | Docker image for aux4 | `aux4/aux4:latest` |
| `registry` | Full hub registry URL to publish to (e.g. `https://dev.api.hub.aux4.io/v1/packages`). Empty = default prod hub. | |

#### Publishing to the dev hub

By default the action publishes to the production hub (`hub.aux4.io`). Set `registry` to a full registry URL to publish elsewhere — for example, a branch-aware workflow can publish to the **dev hub** from the `dev` branch:

```yaml
- uses: aux4/action@v1
  with:
    command: publish
    level: patch
    registry: ${{ github.ref_name == 'dev' && 'https://dev.api.hub.aux4.io/v1/packages' || '' }}
    aux4_token: ${{ secrets.AUX4_ACCESS_TOKEN }}
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

`registry` only affects the publish container — the token you pass in `aux4_token` is sent to that registry as-is, so it must be a token valid for that hub. The action's own tooling (pkger, render) is always installed from the prod hub, regardless of `registry`. When `registry` is empty the behavior is identical to publishing to the prod hub.

#### Outputs

| Output | Description |
|--------|-------------|
| `version` | The new package version |
| `scope` | The package scope |
| `name` | The package name |

### cloud-deploy

Deploys one or more packages to [aux4.cloud](https://aux4.cloud) by wrapping `aux4 aux4 cloud deploy`. Works with any hub package — including third-party ones — with no publish required.

```yaml
- uses: aux4/action@v1
  with:
    command: cloud-deploy
    scope: myscope
    machine: mymachine
    deploy_packages: |
      private:myscope/api
      aux4/config
    env: |
      LOG_LEVEL=info
    aux4_token: ${{ secrets.AUX4_CLOUD_TOKEN }}
```

| Input | Description | Default |
|-------|-------------|---------|
| `scope` | Target scope for the deployment | *required* |
| `machine` | Machine (VM) name; defaults to the package name for a single package | |
| `deploy_packages` | Packages to deploy, one per line: `[<repository>:]<scope>/<name>[@<version>]` (default repo `public`; prefix `private:` / `system:`) | *required* |
| `version` | Default version for packages given without `@version` | `latest` |
| `size` | Machine size (`xs`, `sm`, `md`, `lg`, `xl`) | `sm` |
| `timeout` | Lambda timeout in seconds | `120` |
| `api` | Deploy as an HTTP API behind an API Gateway (one package only) | `false` |
| `env` | Environment variables, one `NAME=value` per line | |
| `api_url` | Cloud API base URL | `https://api.aux4.cloud` |

**Authentication** — provide **either** `aux4_token` (a raw access token, as a secret) **or** `client_id` + `client_secret` (minted via `client_credentials`).

> **Note:** for the `client_credentials` path, the OAuth client must be granted both the `cloud:deploy` scope and the target deployment scope (e.g. `myscope`). The action mints the token requesting `cloud:deploy <scope>`; the cloud API authorizes the deploy from the token's `scopes` claim. Alternatively use `aux4_token` (a user access token for a member of the scope).

Chain it after `publish`, or run it standalone:

```yaml
deploy:
  needs: publish
  runs-on: ubuntu-latest
  steps:
    - uses: aux4/action@v1
      with:
        command: cloud-deploy
        scope: myscope
        deploy_packages: myscope/mypackage
        aux4_token: ${{ secrets.AUX4_CLOUD_TOKEN }}
```

## Common Inputs

These inputs work with all commands:

| Input | Description | Default |
|-------|-------------|---------|
| `command` | Command to run: `lint`, `test`, `publish`, or `cloud-deploy` | *required* |
| `working_directory` | Working directory containing the repository | `.` |
| `package_directory` | Directory containing the `.aux4` file | `package` |
| `system_packages` | Space-separated system packages to install (apt/brew) | |
| `npm_packages` | Space-separated npm packages to install globally | |
| `packages` | Space-separated aux4 packages to install | |
| `build_command` | Build command to run before the action | |

## Recommended Pipeline

```
lint → test-linux ─┐
                    ├→ publish
lint → test-darwin ─┘
```

Lint runs first. Tests only start if lint passes (in parallel across platforms). Publish only after all checks succeed.

## Full Workflow Example

```yaml
name: Publish Package

on:
  push:
    branches:
      - main
    paths:
      - '**'
      - '!.github/**'
      - '!README.md'
      - '!LICENSE'
      - '!.gitignore'

  workflow_dispatch:
    inputs:
      level:
        description: 'Release level (patch, minor, major)'
        required: true
        default: 'patch'
        type: choice
        options:
          - patch
          - minor
          - major

concurrency:
  group: publish-package
  cancel-in-progress: false

permissions:
  contents: write

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: '22'

      - name: Install dependencies
        run: npm install

      - name: Build
        run: npm run build

      - uses: aux4/action@v1
        with:
          command: lint
          strict: 'true'

  test-linux:
    needs: [lint]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: '22'

      - name: Install dependencies
        run: npm install

      - uses: aux4/action@v1
        with:
          command: test
          build_command: npm run build

  test-darwin:
    needs: [lint]
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v6

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: '22'

      - name: Install dependencies
        run: npm install

      - uses: aux4/action@v1
        with:
          command: test
          build_command: npm run build

  publish:
    needs: [test-linux, test-darwin]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: '22'

      - name: Install dependencies
        run: npm install

      - name: Build
        run: npm run build

      - uses: aux4/action@v1
        with:
          command: publish
          level: ${{ inputs.level || 'patch' }}
          aux4_token: ${{ secrets.AUX4_ACCESS_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
```
