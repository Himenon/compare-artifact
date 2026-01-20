# Himenon/diff-artifacts/upload

A GitHub Action to upload build artifacts to GitHub Actions Artifacts at a specified path.
Use in conjunction with [Himenon/diff-artifacts](https://github.com/Himenon/diff-artifacts).

## Usage

**Single Target:**

```yaml
on:
  push:
    branches: [main]

jobs:
  upload:
    runs-on: ubuntu-latest
    steps:
      # build steps ...
      - uses: Himenon/diff-artifacts/upload@v1.1.0
        with:
          path: dist/
```

**Multi Target:**

```yaml
on:
  push:
    branches: [main]

jobs:
  upload:
    runs-on: ubuntu-latest
    steps:
      # build steps ...
      - uses: Himenon/diff-artifact/upload@v1.1.0
        with:
          path: |
            apps/web/dist
            apps/api/dist
```

## License

[Himenon/diff-artifact](https://github.com/Himenon/diff-artifact), MIT
