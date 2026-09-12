# Helm Charts

[![Charts CI](https://github.com/RashadAnsari/helm-charts/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/RashadAnsari/helm-charts/actions/workflows/ci.yaml)
[![Release](https://img.shields.io/github/v/release/RashadAnsari/helm-charts?sort=semver)](https://github.com/RashadAnsari/helm-charts/releases)
[![License](https://img.shields.io/github/license/RashadAnsari/helm-charts)](LICENSE)

Helm charts published as OCI artifacts to GitHub Container Registry.

## Charts

| Chart                            | Type    | Description                                                    |
|----------------------------------|---------|----------------------------------------------------------------|
| [helmet](charts/helmet)          | library | Common template definitions shared by application Helm charts  |

## TL;DR

```bash
$ helm pull oci://ghcr.io/rashadansari/charts/helmet --version 0.14.0
```

`helmet` is a [library chart](https://helm.sh/docs/topics/library_charts/), so it is not installed on its own. Add it as a dependency of your application chart:

```yaml
# file: Chart.yaml

dependencies:
  - name: helmet
    version: 0.14.0
    repository: oci://ghcr.io/rashadansari/charts
    import-values:
      - defaults
```

```bash
$ helm dependency update
```

See the [helmet README](charts/helmet/README.md) for the full parameter reference and a walkthrough.

## Before you begin

### Prerequisites

- Kubernetes 1.23+
- Helm 3.9.0+

### Install Helm

Helm is a tool for managing Kubernetes charts. Charts are packages of pre-configured Kubernetes resources.

To install Helm, refer to the [Helm install guide](https://github.com/helm/helm#install) and ensure that the `helm` binary is in the `PATH` of your shell.

### Pulling charts

These charts are distributed as OCI artifacts rather than through a classic `helm repo add` index, so there is no repository to register. Reference a chart by its full registry path instead:

```bash
$ helm pull oci://ghcr.io/rashadansari/charts/<chart> --version <version>
```

Packaged `.tgz` files are also attached to each [GitHub release](https://github.com/RashadAnsari/helm-charts/releases).

The packages are public, so no authentication is needed to pull them. If you are pushing, log in first:

```bash
$ helm registry login ghcr.io -u <github-username>
```

### Using Helm

Please refer to the [Quick Start guide](https://helm.sh/docs/intro/quickstart/) if you wish to get running in just a few commands, otherwise the [Using Helm Guide](https://helm.sh/docs/intro/using_helm/) provides detailed instructions on how to use the Helm client to manage packages on your Kubernetes cluster.

## Releasing

Every push to `main` runs [Charts CI](.github/workflows/ci.yaml), which lints each chart and then publishes any chart whose `version` in `Chart.yaml` is not in the registry yet. Publishing means pushing the OCI artifact to `ghcr.io/rashadansari/charts` and creating a GitHub release with the packaged `.tgz` attached. To cut a release, bump `version` in the chart's `Chart.yaml` and merge to `main`.

## License

Copyright &copy; 2026 Rashad Ansari

This project is a fork of [companyinfo/helm-charts](https://github.com/companyinfo/helm-charts), Copyright &copy; 2025 Company.info.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
