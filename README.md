# Helm Charts

[![Charts CI](https://github.com/RashadAnsari/helm-charts/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/RashadAnsari/helm-charts/actions/workflows/ci.yaml)
[![Release](https://img.shields.io/github/v/release/RashadAnsari/helm-charts?sort=semver&label=release)](https://github.com/RashadAnsari/helm-charts/releases/latest)
[![ghcr.io](https://img.shields.io/badge/ghcr.io-rashadansari%2Fcharts-2088FF?logo=github&logoColor=white)](https://github.com/RashadAnsari/helm-charts/pkgs/container/charts%2Fhelmet)
[![Helm](https://img.shields.io/badge/Helm-3.9%2B-0F1689?logo=helm&logoColor=white)](https://helm.sh)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.23%2B-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![License](https://img.shields.io/github/license/RashadAnsari/helm-charts?color=blue)](LICENSE)

Every Kubernetes service you ship needs the same eleven YAML files. Most teams solve that by copying the last chart they wrote and deleting the parts they don't need, which is how you end up maintaining nine slightly different Deployment templates.

**helmet** is a Helm library chart that holds those templates once. Your application chart declares it as a dependency, writes one `include`, and describes the app in `values.yaml`.

## Charts

| Chart                   | Type    | Version                                                                                                                            | Description                                                            |
|-------------------------|---------|------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| [helmet](charts/helmet) | library | [![Release](https://img.shields.io/github/v/release/RashadAnsari/helm-charts?sort=semver&label=%20&color=0F1689)](https://github.com/RashadAnsari/helm-charts/releases/latest) | Common templates shared by application charts. Not deployable on its own |

## Quick start

Add helmet to your chart:

```yaml
# Chart.yaml
apiVersion: v2
name: my-app
version: "0.1.0"

dependencies:
  - name: helmet
    version: 0.17.0
    repository: oci://ghcr.io/rashadansari/charts
    import-values:
      - defaults # Required to inherit helmet's default values
```

Write one line of template:

```yaml
# templates/app.yaml
{{ include "helmet.app" . }}
```

Describe the app:

```yaml
# values.yaml
image:
  repository: nginx

ports:
  - name: http
    containerPort: 80
    protocol: TCP

ingress:
  enabled: true
```

Then install it:

```bash
$ helm dependency update
$ helm install my-app .
```

Those ten lines of `values.yaml` render a Deployment, a Service and an Ingress, wired together with matching labels, selectors and ports. Three runnable charts are in [charts/helmet/examples](charts/helmet/examples): `simple` is the one above, `full` exercises probes, persistence, autoscaling, monitoring and a CronJob, and `stateful` shows a StatefulSet with per-replica storage.

## What helmet renders

`helmet.app` emits twelve resource kinds. Each one appears only when the values that need it are set, so a chart that never touches `persistence` never gets a PVC.

| Resource                  | Enabled by                                  |
|---------------------------|---------------------------------------------|
| Deployment                | `image.repository`, the default workload    |
| StatefulSet               | `image.repository` with `workload.kind: StatefulSet` |
| Service                   | `ports` and `service.ports`                 |
| Service (headless)        | a StatefulSet without its own `workload.serviceName` |
| Ingress                   | `ingress.enabled`                           |
| ConfigMap                 | `configMap.data`                            |
| Secret                    | `secret.data` or `secret.stringData`        |
| PersistentVolumeClaim     | `persistence.enabled` on a Deployment, without an existing claim |
| HorizontalPodAutoscaler   | `autoscaling.enabled`                       |
| ServiceAccount            | `serviceAccount.create`                     |
| ServiceMonitor            | `serviceMonitor.enabled`                    |
| PodMonitor                | `podMonitor.enabled`                        |
| CronJob                   | `cronjob.enabled`                           |

Stateful workloads set `workload.kind: StatefulSet`. That swaps the Deployment for a StatefulSet, adds the headless Service Kubernetes needs for stable per-pod DNS, and turns `persistence` into `volumeClaimTemplates` so each replica gets its own volume. Both workloads share one pod template, so every other parameter behaves identically.

Behind those toggles sit 160 documented parameters covering probes, affinity presets, security contexts, sidecars, init containers, TLS secrets and self-signed certificates. See the [helmet reference](charts/helmet/README.md) for the full table, which is generated from `values.yaml` and checked in CI.

Naming, labels and capability detection come from [bitnami/common](https://github.com/bitnami/charts/tree/main/bitnami/common) 2.29.1, so resource names and the `app.kubernetes.io` labels follow the same conventions as the Bitnami catalog.

## Requirements

- Kubernetes 1.23+
- Helm 3.9+

Charts are distributed as OCI artifacts, which Helm supports natively from 3.8 onward. To install Helm, see the [Helm install guide](https://helm.sh/docs/intro/install/).

## Pulling charts

There is no `helm repo add` step. OCI charts are referenced by their full registry path:

```bash
$ helm pull oci://ghcr.io/rashadansari/charts/helmet --version 0.17.0
```

The packages are public, so pulling needs no authentication. Packaged `.tgz` files are also attached to every [GitHub release](https://github.com/RashadAnsari/helm-charts/releases).

## Releasing

[Charts CI](.github/workflows/ci.yaml) lints every chart on pull requests. On a push to `main` it publishes any chart whose `version` in `Chart.yaml` is not in the registry yet, pushing the OCI artifact to `ghcr.io/rashadansari/charts` and cutting a GitHub release with the packaged `.tgz` attached.

To ship a change, bump `version` in the chart's `Chart.yaml` and merge. Versions that are already published are skipped, so merges that touch nothing else are no-ops.

## Contributing

Issues and pull requests are welcome. Run the same checks CI does before opening one:

```bash
$ make check
```

That lints every chart and verifies the parameter tables still match `values.yaml`. If you changed a `## @param` annotation, regenerate the tables and commit the result:

```bash
$ make readme
```

`make help` lists the rest.

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
