# Diff Artifacts

[日本語](./README_ja.md)

Compare build artifacts between base and PR branches via GitHub Pull Request.
This Action helps developers recognize artifact changes caused by their changes.

![Diff Viewer Example](./imgs/diff-viewer-example-01.png)

**Example Repository**

- https://github.com/Himenon/diff-artifacts-example
- https://github.com/Himenon/diff-artifacts-example-diff-viewer

**Example Pull Requests**

- [chore: change Next.js patch versions for v14, v15, and v16 projects #40](https://github.com/Himenon/diff-artifacts-example/pull/40)
- [fix: one word changes #39](https://github.com/Himenon/diff-artifacts-example/pull/39)

## Setup

1. Create a [GitHub App](https://docs.github.com/apps/creating-github-apps) with permissions: **Pull requests** (Read/Write), **Contents** (Read/Write)
2. Save `APP_ID` and `APP_PRIVATE_KEY` as repository secrets
3. Create an empty repository for `diff-viewer`

## Usage

**Compare artifacts**

```yaml
on:
  pull_request:

jobs:
  compare:
    runs-on: ubuntu-latest
    steps:
      - uses: Himenon/diff-artifacts/compare@v1.0.0
        with:
          app-id: ${{ secrets.APP_ID }}
          app-private-key: ${{ secrets.APP_PRIVATE_KEY }}
          diff-viewer-owner: "your-username"
          diff-viewer-repo-name: "your-diff-viewer-repo"
```

You can also configure workflows for uploading base artifacts and auto-closing PRs:

**Upload base artifacts**

```yaml
on:
  push:
    branches: [main]

jobs:
  upload:
    runs-on: ubuntu-latest
    steps:
      # build steps ...
      - uses: Himenon/diff-artifact/upload@v1.0.0
        with:
          path: dist/
```

**Auto-close PRs created by diff-artifacts**

```yaml
on:
  pull_request:
    types: [closed]

jobs:
  cleanup:
    runs-on: ubuntu-slim
    steps:
      - uses: Himenon/diff-artifact/pr-close@v1.0.0
        with:
          app-id: ${{ secrets.APP_ID }}
          app-private-key: ${{ secrets.APP_PRIVATE_KEY }}
          diff-viewer-owner: "your-username"
          diff-viewer-repo-name: "your-diff-viewer-repo"
```

## Developer's Notes

For production use, we recommend cloning this repository or forking it within your organization for customization. The default options are designed to work with minimal configuration and are not intended for complex workflows.

## License

[Himenon/diff-artifacts](https://github.com/Himenon/diff-artifacts), MIT
