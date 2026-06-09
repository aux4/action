<p align="center">
  <img src="logo.png" alt="aux4" width="200">
</p>

<h1 align="center">aux4</h1>

<p align="center">GitHub Action to lint, test, and publish <a href="https://aux4.io">aux4</a> packages.</p>

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

Runs tests for an aux4 package using the `aux4/test` framework.

```yaml
- uses: aux4/action@v1
  with:
    command: test
    build_command: 'npm run build'
```

| Input | Description | Default |
|-------|-------------|---------|
| `test_directory` | Directory containing test files | `test` |
| `build_command` | Build command to run before testing | |

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
| `aux4_token` | aux4 access token for hub.aux4.io | *required* |
| `github_token` | GitHub token for creating releases | *required* |
| `aux4_image` | Docker image for aux4 | `aux4/aux4:latest` |

#### Outputs

| Output | Description |
|--------|-------------|
| `version` | The new package version |
| `scope` | The package scope |
| `name` | The package name |

## Common Inputs

These inputs work with all commands:

| Input | Description | Default |
|-------|-------------|---------|
| `command` | Command to run: `lint`, `test`, or `publish` | *required* |
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
