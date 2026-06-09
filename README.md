# aux4

GitHub Action to lint, test, and publish [aux4](https://aux4.io) packages.

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

## Full Workflow Example

```yaml
name: Publish Package

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      level:
        description: 'Release level'
        required: true
        default: 'patch'
        type: choice
        options: [patch, minor, major]

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
      - uses: aux4/action@v1
        with:
          command: lint
          strict: 'true'

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: aux4/action@v1
        with:
          command: test
          build_command: 'npm run build'

  publish:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: aux4/action@v1
        with:
          command: publish
          level: ${{ inputs.level || 'patch' }}
          aux4_token: ${{ secrets.AUX4_ACCESS_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
```
