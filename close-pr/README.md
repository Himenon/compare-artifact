# Himenon/diff-artifacts/close-pr

A GitHub Action to automatically close Pull Requests created by [Himenon/diff-artifacts](https://github.com/Himenon/diff-artifacts).

## Setup

1. Create a [GitHub App](https://docs.github.com/apps/creating-github-apps) with permissions: **Pull requests** (Read/Write), **Contents** (Read/Write)
2. Save `APP_ID` and `APP_PRIVATE_KEY` as repository secrets

## Usage

```yaml
on:
  pull_request:
    types: [closed]

jobs:
  cleanup:
    runs-on: ubuntu-slim
    steps:
      - uses: Himenon/diff-artifacts/close-pr@v1.1.0
        with:
          app-id: ${{ secrets.APP_ID }}
          app-private-key: ${{ secrets.APP_PRIVATE_KEY }}
          diff-viewer-owner: "your-username"
          diff-viewer-repo-name: "your-diff-viewer-repo"
```

## License

[Himenon/diff-artifact](https://github.com/Himenon/diff-artifact), MIT
