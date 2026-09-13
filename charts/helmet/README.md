# Helmet

[![Release](https://img.shields.io/github/v/release/RashadAnsari/helm-charts?sort=semver&label=chart)](https://github.com/RashadAnsari/helm-charts/releases/latest)
[![ghcr.io](https://img.shields.io/badge/ghcr.io-rashadansari%2Fcharts%2Fhelmet-2088FF?logo=github&logoColor=white)](https://github.com/RashadAnsari/helm-charts/pkgs/container/charts%2Fhelmet)
[![Chart type](https://img.shields.io/badge/chart%20type-library-0F1689?logo=helm&logoColor=white)](https://helm.sh/docs/topics/library_charts/)
[![Helm](https://img.shields.io/badge/Helm-3.9%2B-0F1689?logo=helm&logoColor=white)](https://helm.sh)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.23%2B-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![License](https://img.shields.io/github/license/RashadAnsari/helm-charts?color=blue)](../../LICENSE)

Helmet is a [Helm library chart](https://helm.sh/docs/topics/library_charts/) holding the templates that every application chart ends up needing. Declare it as a dependency, write a single `include`, and describe the application in `values.yaml`. Helmet renders the workload, its networking and its monitoring with names, labels and selectors already consistent.

## Background

Helm 3 introduced the library chart:

> A library chart is a type of Helm chart that defines chart primitives or
definitions which can be shared by Helm templates in other charts. This
allows users to share snippets of code that can be re-used across charts,
avoiding repetition and keeping charts DRY.

Most application charts differ in a handful of values and are otherwise the same file twice: identical Deployment scaffolding, identical Service, identical probe blocks. Copying that between repositories means every fix has to be applied everywhere it was pasted. Helmet keeps the scaffolding in one versioned chart, so an application chart contains only the part that is actually specific to the application.

## Resources

`helmet.app` renders twelve resource kinds. Each is gated on the values that need it, so a chart that never sets `persistence` never gets a PVC.

| Resource                | Enabled by                           |
|-------------------------|--------------------------------------|
| Deployment              | `image.repository`, when `workload.kind` is `Deployment` |
| StatefulSet             | `image.repository`, when `workload.kind` is `StatefulSet` |
| Service                 | `ports` and `service.ports`          |
| Service (headless)      | `workload.kind` is `StatefulSet` and `workload.serviceName` is empty |
| Ingress                 | `ingress.enabled`                    |
| ConfigMap               | `configMap.data`                     |
| Secret                  | `secret.data` or `secret.stringData` |
| PersistentVolumeClaim   | `persistence.enabled` on a Deployment, unless `persistence.existingClaim` is set |
| HorizontalPodAutoscaler | `autoscaling.enabled`                |
| ServiceAccount          | `serviceAccount.create`              |
| ServiceMonitor          | `serviceMonitor.enabled`             |
| PodMonitor              | `podMonitor.enabled`                 |
| CronJob                 | `cronjob.enabled`                    |

### Choosing the workload

`image.repository` decides whether there is a workload at all. `workload.kind` decides which kind it is, and defaults to `Deployment`:

```yaml
workload:
  kind: StatefulSet
  podManagementPolicy: Parallel   # or OrderedReady, the default
```

Switching to `StatefulSet` changes three things:

- A headless Service is created to govern it, named `<fullname>-headless`, giving each pod stable DNS at `<pod>.<service>.<namespace>.svc.<clusterDomain>`. Set `workload.serviceName` to point at a Service you manage instead, and helmet will not create one.
- `persistence` becomes `volumeClaimTemplates`, so every replica gets its own volume rather than sharing one. `persistence.existingClaim` is the exception: a named claim is a single shared volume, so it stays a plain pod volume.
- `updateStrategy` is rendered as `spec.updateStrategy` rather than a Deployment's `spec.strategy`. The two accept different `rollingUpdate` fields, so set it to match your `workload.kind`.

Everything else, including probes, resources, affinity, sidecars and the ConfigMap and Secret checksums that trigger restarts, is identical between the two. Both workloads share one pod template.

When the Ingress is enabled, helmet also renders TLS Secrets from `ingress.secrets`. If no secrets are supplied and both `ingress.tls` and `ingress.selfSigned` are set, it generates a self-signed certificate instead.

Naming, label and capability helpers come from [bitnami/common](https://github.com/bitnami/charts/tree/main/bitnami/common) 2.41.0, so resource names and `app.kubernetes.io` labels match the conventions used across the Bitnami catalog.

To include only part of the set, call the individual templates instead of `helmet.app`: `helmet.deployment`, `helmet.statefulset`, `helmet.service`, `helmet.service.headless`, `helmet.ingress`, `helmet.hpa`, `helmet.configmap`, `helmet.secret`, `helmet.persistence`, `helmet.serviceaccount`, `helmet.servicemonitor`, `helmet.podmonitor` and `helmet.cronjob`.

### Validating your values

[`values.schema.json`](values.schema.json) is generated from the same annotations as the parameter table below, and describes the type of every value helmet accepts.

Helm applies a chart's schema to that chart's own values. Helmet keeps its values under `exports.defaults`, so the schema does nothing while it sits here. To get validation, drop it into your application chart, next to your `values.yaml`:

```shell
$ curl -sfLO https://github.com/RashadAnsari/helm-charts/releases/download/helmet-0.20.1/helmet-0.20.1-values.schema.json
$ mv helmet-0.20.1-values.schema.json values.schema.json
```

Helm then checks your `values.yaml` on every `template`, `install` and `upgrade`:

```console
$ helm template my-app . --set replicaCount=two
Error: values don't meet the specifications of the schema(s) in the following chart(s):
my-app:
- at '/replicaCount': got string, want number
```

The file is also attached to each [release](https://github.com/RashadAnsari/helm-charts/releases).

### Install notes

`helmet.notes` prints the post-install message telling the user how to reach the application, picking the right instructions for your `ingress.enabled` and `service.type`. It is not part of `helmet.app`, so add it to your own `NOTES.txt`:

```
# file: templates/NOTES.txt

{{ include "helmet.notes" . }}
```

## Prerequisites

- Kubernetes 1.23+
- Helm 3.9.0+

## Getting started
1. Add the Helmet as a dependency to your chart.
```yaml
# file: Chart.yaml

dependencies:
  - name: helmet
    version: 0.20.1
    repository: oci://ghcr.io/rashadansari/charts
    import-values: # <== It is mandatory if you want to import the Helmet default values.
      - defaults
```

2. Update the Helm dependencies:
```shell
$ helm dependency update
```

3. Include the app template:
```yaml
# file: templates/app.yaml

{{ include "helmet.app" . }}
```

4. Configure your chart
```yaml
# file: values.yaml

image:
  repository: nginx

ports:
  - name: http
    containerPort: 80
    protocol: TCP

ingress:
  enabled: true
```

5. Install the chart:
```shell
$ helm install nginx .
```

Three runnable charts are in [examples](examples): `simple` is the chart above, `full` exercises probes, persistence, autoscaling, monitoring and a CronJob, and `stateful` shows a StatefulSet with per-replica storage.

## Parameters

### Global parameters

| Name                                                  | Description                                                                                                                                                                                                                                                                                                                                                         | Value   |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `global.imageRegistry`                                | Global Docker image registry                                                                                                                                                                                                                                                                                                                                        | `""`    |
| `global.imagePullSecrets`                             | Global Docker registry secret names as an array                                                                                                                                                                                                                                                                                                                     | `[]`    |
| `global.defaultStorageClass`                          | Global default StorageClass for Persistent Volume(s)                                                                                                                                                                                                                                                                                                                | `""`    |
| `global.compatibility.openshift.adaptSecurityContext` | Adapt the securityContext sections of the deployment to make them compatible with Openshift restricted-v2 SCC: remove runAsUser, runAsGroup and fsGroup and let the platform use their allowed default IDs. Possible values: auto (apply if the detected running cluster is Openshift), force (perform the adaptation always), disabled (do not perform adaptation) | `auto`  |
| `global.compatibility.omitEmptySeLinuxOptions`        | If set to true, removes the seLinuxOptions from the securityContexts when it is set to an empty object                                                                                                                                                                                                                                                              | `false` |

### Common parameters

| Name                | Description                                                                                                | Value           |
| ------------------- | ---------------------------------------------------------------------------------------------------------- | --------------- |
| `kubeVersion`       | Force target Kubernetes version (using Helm capabilities if not set)                                       | `""`            |
| `nameOverride`      | String to partially override common.names.fullname template with a string (will maintain the release name) | `""`            |
| `fullnameOverride`  | String to fully override common.names.fullname template with a string                                      | `""`            |
| `namespaceOverride` | String to fully override common.names.namespace template with a string                                     | `""`            |
| `clusterDomain`     | Kubernetes Cluster Domain name                                                                             | `cluster.local` |
| `annotations`       | Additional annotations to be added to the App Deployment. Evaluated as a template                          | `{}`            |
| `labels`            | Additional labels to be added to the App Deployment. Evaluated as a template                               | `{}`            |
| `commonLabels`      | Labels to be added to all deployed resources                                                               | `{}`            |
| `commonAnnotations` | Annotations to be added to all deployed resources                                                          | `{}`            |

### Image parameters

| Name                | Description                                                                                     | Value       |
| ------------------- | ----------------------------------------------------------------------------------------------- | ----------- |
| `image.registry`    | Image registry                                                                                  | `docker.io` |
| `image.repository`  | Image repository                                                                                | `""`        |
| `image.tag`         | Image tag (immutable tags are recommended)                                                      | `latest`    |
| `image.digest`      | Image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag | `""`        |
| `image.pullPolicy`  | Image pull policy                                                                               | `""`        |
| `image.pullSecrets` | Image pull secrets                                                                              | `[]`        |

### Workload parameters

| Name                           | Description                                                                                                     | Value          |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------- | -------------- |
| `workload.kind`                | Workload to render for the application. Allowed values: `Deployment` or `StatefulSet`                           | `Deployment`   |
| `workload.podManagementPolicy` | Pod creation and scaling order. StatefulSet only. Allowed values: `OrderedReady` or `Parallel`                  | `OrderedReady` |
| `workload.serviceName`         | Existing headless Service governing the StatefulSet. When empty, helmet creates one named `<fullname>-headless` | `""`           |

### Deployment parameters

| Name                                    | Description                                                                                                              | Value           |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | --------------- |
| `replicaCount`                          | Number of APP replicas                                                                                                   | `1`             |
| `revisionHistoryLimit`                  | The number of old history to retain to allow rollback                                                                    | `10`            |
| `ports`                                 | List of ports to expose from the container. Each entry takes name, containerPort and protocol                            | `[]`            |
| `livenessProbe.enabled`                 | Enable livenessProbe on the main container. Define the probe itself alongside this key                                   | `false`         |
| `readinessProbe.enabled`                | Enable readinessProbe on the main container. Define the probe itself alongside this key                                  | `false`         |
| `startupProbe.enabled`                  | Enable startupProbe on the main container. Define the probe itself alongside this key                                    | `false`         |
| `podRestartPolicy`                      | Restart policy for all containers within the pod                                                                         | `Always`        |
| `podSecurityContext.enabled`            | Enabled APP pods' Security Context                                                                                       | `false`         |
| `podSecurityContext.fsGroup`            | Set APP pod's Security Context fsGroup                                                                                   | `0`             |
| `containerSecurityContext.enabled`      | Enabled APP containers' Security Context                                                                                 | `false`         |
| `containerSecurityContext.runAsUser`    | Set APP containers' Security Context runAsUser                                                                           | `1001`          |
| `containerSecurityContext.runAsNonRoot` | Set APP container's Security Context runAsNonRoot                                                                        | `true`          |
| `lifecycleHooks`                        | LifecycleHook to set additional configuration at startup Evaluated as a template                                         | `{}`            |
| `resources.limits`                      | The resources limits for the container                                                                                   | `{}`            |
| `resources.requests`                    | The requested resources for the container                                                                                | `{}`            |
| `hostAliases`                           | Add deployment host aliases                                                                                              | `[]`            |
| `podLabels`                             | Additional pod labels                                                                                                    | `{}`            |
| `podAnnotations`                        | Additional pod annotations                                                                                               | `{}`            |
| `podAffinityPreset`                     | Pod affinity preset. Allowed values: soft, hard                                                                          | `""`            |
| `podAntiAffinityPreset`                 | Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                 | `soft`          |
| `nodeAffinityPreset.type`               | Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                | `""`            |
| `nodeAffinityPreset.key`                | Node label key to match Ignored if `affinity` is set.                                                                    | `""`            |
| `nodeAffinityPreset.values`             | Node label values to match. Ignored if `affinity` is set.                                                                | `[]`            |
| `affinity`                              | Affinity for pod assignment                                                                                              | `{}`            |
| `nodeSelector`                          | Node labels for pod assignment.                                                                                          | `{}`            |
| `tolerations`                           | Tolerations for pod assignment.                                                                                          | `[]`            |
| `topologySpreadConstraints`             | Topology Spread Constraints for pod assignment spread across your cluster among failure-domains. Evaluated as a template | `[]`            |
| `priorityClassName`                     | Priority Class Name                                                                                                      | `""`            |
| `schedulerName`                         | Use an alternate scheduler, e.g. "stork".                                                                                | `""`            |
| `terminationGracePeriodSeconds`         | Seconds APP pod needs to terminate gracefully                                                                            | `""`            |
| `updateStrategy.type`                   | APP update strategy type. Add `rollingUpdate` alongside it to tune the rollout                                           | `RollingUpdate` |
| `extraVolumes`                          | Array to add extra volumes (evaluated as a template)                                                                     | `[]`            |
| `extraVolumeMounts`                     | Array to add extra mounts (normally used with extraVolumes, evaluated as a template)                                     | `[]`            |
| `sidecars`                              | Add additional sidecar containers to the APP pods                                                                        | `[]`            |
| `initContainers`                        | Add additional init containers to the APP pods                                                                           | `[]`            |
| `command`                               | Override default container command                                                                                       | `[]`            |
| `args`                                  | Override default container args                                                                                          | `[]`            |
| `envVars`                               | Environment variables to be set on APP container                                                                         | `{}`            |
| `envVarsConfigMap`                      | ConfigMap with environment variables                                                                                     | `""`            |
| `envVarsSecret`                         | Secret with environment variables                                                                                        | `""`            |

### Autoscaling parameters

| Name                       | Description                                                                      | Value   |
| -------------------------- | -------------------------------------------------------------------------------- | ------- |
| `autoscaling.enabled`      | Deploy a HorizontalPodAutoscaler object for the APP deployment                   | `false` |
| `autoscaling.minReplicas`  | Minimum number of replicas to scale back                                         | `3`     |
| `autoscaling.maxReplicas`  | Maximum number of replicas to scale out                                          | `5`     |
| `autoscaling.targetCPU`    | Define the CPU target to trigger the scaling actions (utilization percentage)    | `80`    |
| `autoscaling.targetMemory` | Define the memory target to trigger the scaling actions (utilization percentage) | `80`    |
| `autoscaling.metrics`      | Metrics to use when deciding to scale the deployment (evaluated as a template)   | `[]`    |

### ConfigMap parameters

| Name                    | Description                                                                | Value         |
| ----------------------- | -------------------------------------------------------------------------- | ------------- |
| `configMap.mounted`     | Mount the ConfigMap as a volume in the main container                      | `false`       |
| `configMap.mountPath`   | Path to mount the ConfigMap at. Only used when `configMap.mounted` is true | `/app/config` |
| `configMap.subPath`     | Key of the ConfigMap to mount as a single file instead of the whole volume | `""`          |
| `configMap.data`        | Store data in key-value pairs                                              | `{}`          |
| `configMap.annotations` | Additional custom annotations for the ConfigMap                            | `{}`          |
| `configMap.labels`      | Additional custom labels for the ConfigMap                                 | `{}`          |

### Secret parameters

| Name                 | Description                                                             | Value    |
| -------------------- | ----------------------------------------------------------------------- | -------- |
| `secret.type`        | the type is used to facilitate programmatic handling of the Secret data | `Opaque` |
| `secret.data`        | store data in key-value pairs                                           | `{}`     |
| `secret.stringData`  | store data in key-value pairs                                           | `{}`     |
| `secret.annotations` | Additional custom annotations for the Secret                            | `{}`     |
| `secret.labels`      | Additional custom labels for the Secret                                 | `{}`     |

### Ingress parameters

| Name                       | Description                                                                                                                      | Value                    |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `ingress.enabled`          | Enable ingress resource for the APP                                                                                              | `false`                  |
| `ingress.path`             | Path for the default host                                                                                                        | `/`                      |
| `ingress.apiVersion`       | Override API Version (automatically detected if not set)                                                                         | `""`                     |
| `ingress.pathType`         | Ingress path type                                                                                                                | `ImplementationSpecific` |
| `ingress.hostname`         | Default host for the ingress resource, a host pointing to this will be created                                                   | `app.local`              |
| `ingress.annotations`      | Additional annotations for the Ingress resource. To enable certificate autogeneration, place here your cert-manager annotations. | `{}`                     |
| `ingress.ingressClassName` | Set the ingerssClassName on the ingress record for k8s 1.18+                                                                     | `""`                     |
| `ingress.tls`              | Enable TLS configuration for the hostname defined at ingress.hostname parameter                                                  | `false`                  |
| `ingress.extraHosts`       | An array with additional hostname(s) to be covered with the ingress record                                                       | `[]`                     |
| `ingress.extraPaths`       | Any additional arbitrary paths that may need to be added to the ingress under the main host.                                     | `[]`                     |
| `ingress.selfSigned`       | Create a TLS secret for this ingress record using self-signed certificates generated by Helm                                     | `false`                  |
| `ingress.extraTls`         | TLS configuration for additional hostname(s) to be covered with this ingress record                                              | `[]`                     |
| `ingress.secrets`          | If you're providing your own certificates, please use this to add the certificates as secrets                                    | `[]`                     |
| `ingress.existingSecret`   | It is you own the certificate as secret.                                                                                         | `""`                     |
| `ingress.extraRules`       | Additional rules to be covered with this ingress record                                                                          | `[]`                     |

### Persistence parameters

| Name                        | Description                                                                                             | Value               |
| --------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------- |
| `persistence.enabled`       | Enable persistence using Persistent Volume Claims                                                       | `false`             |
| `persistence.mountPath`     | Path to mount the volume at.                                                                            | `/data`             |
| `persistence.subPath`       | The subdirectory of the volume to mount to, useful in dev environments and one PV for multiple services | `""`                |
| `persistence.storageClass`  | Storage class of backing PVC                                                                            | `""`                |
| `persistence.annotations`   | Persistent Volume Claim annotations                                                                     | `{}`                |
| `persistence.accessModes`   | Persistent Volume Access Modes                                                                          | `["ReadWriteOnce"]` |
| `persistence.size`          | Size of data volume                                                                                     | `8Gi`               |
| `persistence.existingClaim` | The name of an existing PVC to use for persistence                                                      | `""`                |
| `persistence.selector`      | Selector to match an existing Persistent Volume for WordPress data PVC                                  | `{}`                |
| `persistence.dataSource`    | Custom PVC data source                                                                                  | `{}`                |

### Service parameters

| Name                               | Description                                                             | Value       |
| ---------------------------------- | ----------------------------------------------------------------------- | ----------- |
| `service.type`                     | APP service type                                                        | `ClusterIP` |
| `service.ports`                    | APP service ports. Each entry takes name, protocol, port and targetPort | `[]`        |
| `service.sessionAffinity`          | Control where client requests go, to the same pod or round-robin        | `None`      |
| `service.sessionAffinityConfig`    | Additional settings for the sessionAffinity (evaluated as a template)   | `{}`        |
| `service.clusterIP`                | APP service Cluster IP                                                  | `""`        |
| `service.loadBalancerIP`           | APP service Load Balancer IP                                            | `""`        |
| `service.loadBalancerSourceRanges` | APP service Load Balancer sources                                       | `[]`        |
| `service.externalTrafficPolicy`    | APP service external traffic policy                                     | `Cluster`   |
| `service.annotations`              | Additional custom annotations for APP service                           | `{}`        |

### Metrics parameters

| Name                               | Description                                                                      | Value      |
| ---------------------------------- | -------------------------------------------------------------------------------- | ---------- |
| `serviceMonitor.enabled`           | Specify if a ServiceMonitor will be deployed for Prometheus Operator             | `false`    |
| `serviceMonitor.namespace`         | Namespace in which Prometheus is running                                         | `""`       |
| `serviceMonitor.labels`            | Additional ServiceMonitor labels (evaluated as a template)                       | `{}`       |
| `serviceMonitor.annotations`       | Additional ServiceMonitor annotations (evaluated as a template)                  | `{}`       |
| `serviceMonitor.jobLabel`          | The name of the label on the target service to use as the job name in Prometheus | `""`       |
| `serviceMonitor.honorLabels`       | honorLabels chooses the metric's labels on collisions with target labels         | `false`    |
| `serviceMonitor.interval`          | How frequently to scrape metrics                                                 | `""`       |
| `serviceMonitor.scrapeTimeout`     | Timeout after which the scrape is ended                                          | `""`       |
| `serviceMonitor.metricRelabelings` | Specify additional relabeling of metrics                                         | `[]`       |
| `serviceMonitor.relabelings`       | Specify general relabeling                                                       | `[]`       |
| `serviceMonitor.selector`          | Prometheus instance selector labels                                              | `{}`       |
| `serviceMonitor.namespaceSelector` | is a selector for selecting either all namespaces or a list of namespaces.       | `{}`       |
| `serviceMonitor.port`              | port used by serviceMonitor                                                      | `http`     |
| `serviceMonitor.path`              | path used by serviceMonitor                                                      | `/metrics` |
| `podMonitor.enabled`               | Specify if a PodMonitor will be deployed for Prometheus Operator                 | `false`    |
| `podMonitor.namespace`             | Namespace in which Prometheus is running                                         | `""`       |
| `podMonitor.jobLabel`              | The name of the label on the target pod to use as the job name in Prometheus     | `""`       |
| `podMonitor.annotations`           | Additional PodMonitor annotations (evaluated as a template)                      | `{}`       |
| `podMonitor.honorLabels`           | honorLabels chooses the metric's labels on collisions with target labels         | `false`    |
| `podMonitor.port`                  | The port where metrics should be scraped                                         | `http`     |
| `podMonitor.path`                  | The path where metrics are exposed.                                              | `/metrics` |
| `podMonitor.interval`              | Scrape interval. Prometheus default used if not set.                             | `30s`      |
| `podMonitor.scrapeTimeout`         | The timeout duration after which the scrape is ended.                            | `10s`      |
| `podMonitor.labels`                | Additional PodMonitor labels (evaluated as a template)                           | `{}`       |
| `podMonitor.relabelings`           | Specify general relabeling                                                       | `[]`       |
| `podMonitor.metricRelabelings`     | Specify additional relabeling of metrics                                         | `[]`       |
| `podMonitor.namespaceSelector`     | is a selector for selecting either all namespaces or a list of namespaces.       | `{}`       |
| `podMonitor.selector`              | is a selector to select which pods will be monitored.                            | `{}`       |

### ServiceAccount parameters

| Name                                          | Description                                                            | Value   |
| --------------------------------------------- | ---------------------------------------------------------------------- | ------- |
| `serviceAccount.create`                       | Enable creation of ServiceAccount for APP pods                         | `false` |
| `serviceAccount.name`                         | The name of the ServiceAccount to use.                                 | `""`    |
| `serviceAccount.automountServiceAccountToken` | Allows auto mount of ServiceAccountToken on the serviceAccount created | `true`  |
| `serviceAccount.annotations`                  | Additional custom annotations for the ServiceAccount                   | `{}`    |
| `serviceAccount.labels`                       | Additional custom labels for the ServiceAccount                        | `{}`    |

### CronJob parameters

| Name                                 | Description                                                                                   | Value       |
| ------------------------------------ | --------------------------------------------------------------------------------------------- | ----------- |
| `cronjob.enabled`                    | Deploy a CronJob alongside the application                                                    | `false`     |
| `cronjob.concurrencyPolicy`          | Allow/Forbid/Replace concurrency                                                              | `Allow`     |
| `cronjob.schedule`                   | run schedule for the cronjob                                                                  | `""`        |
| `cronjob.successfulJobsHistoryLimit` | Number of successful finished jobs to retain                                                  | `3`         |
| `cronjob.podAnnotations`             | Additional annotations for the CronJob pods (evaluated as a template)                         | `{}`        |
| `cronjob.nodeSelector`               | Node labels for CronJob pod assignment. Falls back to the top-level `nodeSelector` when empty | `{}`        |
| `cronjob.tolerations`                | Tolerations for CronJob pod assignment. Falls back to the top-level `tolerations` when empty  | `[]`        |
| `cronjob.restartPolicy`              | Restart policy for the CronJob pod                                                            | `OnFailure` |
| `cronjob.podSecurityContext.enabled` | Enable the CronJob pods' Security Context                                                     | `false`     |
| `cronjob.podSecurityContext.fsGroup` | Set the CronJob pod's Security Context fsGroup                                                | `0`         |
| `cronjob.initContainers`             | Add init containers to the CronJob pods                                                       | `[]`        |
| `cronjob.containers`                 | Add containers to the CronJob pods. This is where the scheduled workload itself is defined    | `[]`        |
| `cronjob.volumes`                    | Array to add volumes to the CronJob pods (evaluated as a template)                            | `[]`        |


Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```shell
$ helm install my-release --set ingress.hostname=example.com,serviceMonitor.enabled=true .
```

The above command sets the APP Ingress hostname to `example.com` and enabled the ServiceMonitor.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
$ helm install my-release -f values.yaml .
```

> **Tip**: You can use the default [values.yaml](values.yaml) just by [`import-values`](#Getting started)

## Configuration and installation details

It is strongly recommended to use immutable tags in a production environment. This ensures your deployment does not change automatically if the same tag is updated with a different image.

### Ingress

This chart provides support for ingress resources. If you have an ingress controller installed on your cluster, such as nginx-ingress or traefik you can utilize the ingress controller to serve your application.
To enable ingress integration, please set `ingress.enabled` to `true`.

#### Hosts

Most likely you will only want to have one hostname that maps to this APP installation. If that's your case, the property `ingress.hostname` will set it. However, it is possible to have more than one host. To facilitate this, the `ingress.extraHosts` object can be specified as an array. You can also use `ingress.extraTLS` to add the TLS configuration for extra hosts.

For each host indicated at `ingress.extraHosts`, please indicate a `name`, `path`, and any `annotations` that you may want the ingress controller to know about.

For annotations, please see [this document](https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md). Not all annotations are supported by all ingress controllers, but this document does a good job of indicating which annotation is supported by many popular ingress controllers.

### TLS Secrets

This chart will facilitate the creation of TLS secrets for use with the ingress controller, however, this is not required.  There are three common use cases:

- Helm generates/manages certificate secrets
- User generates/manages certificates separately
- An additional tool (like cert-manager) manages the secrets for the application

In the first two cases, one will need a certificate and a key.  We would expect them to look like this:

- certificate files should look like (and there can be more than one certificate if there is a certificate chain)

```
-----BEGIN CERTIFICATE-----
MIID6TCCAtGgAwIBAgIJAIaCwivkeB5EMA0GCSqGSIb3DQEBCwUAMFYxCzAJBgNV
...
jScrvkiBO65F46KioCL9h5tDvomdU1aqpI/CBzhvZn1c0ZTf87tGQR8NK7v7
-----END CERTIFICATE-----
```

- keys should look like:

```
-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAvLYcyu8f3skuRyUgeeNpeDvYBCDcgq+LsWap6zbX5f8oLqp4
...
wrj2wDbCDCFmfqnSJ+dKI3vFLlEz44sAV8jX/kd4Y6ZTQhlLbYc=
-----END RSA PRIVATE KEY-----
```

If you are going to use Helm to manage the certificates, please copy these values into the `certificate` and `key` values for a given `ingress.secrets` entry.

If you are going to manage TLS secrets outside of Helm, please know that you can create a TLS secret (named `app.local-tls` for example).

See the [Kubernetes TLS Ingress documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls) for more information.

### Adding environment variables

In case you want to add extra environment variables (useful for advanced operations like custom init scripts), you can use the `envVars` property.

```yaml
envVars:
  - name: LOG_LEVEL
    value: error
```

Alternatively, you can use a ConfigMap or a Secret with the environment variables. To do so, use the `.envVarsConfigMap` or the `envVarsSecret` properties.

### Setting Pod's affinity

This chart allows you to set your custom affinity using the `affinity` parameter. Find more information about Pod's affinity in the [kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity).

As an alternative, you can use of the preset configurations for pod affinity, pod anti-affinity, and node affinity available at the [bitnami/common](https://github.com/bitnami/charts/tree/master/bitnami/common#affinities) chart. To do so, set the `podAffinityPreset`, `podAntiAffinityPreset`, or `nodeAffinityPreset` parameters.

### Sidecars and Init Containers

To run additional containers in the same pod as the application, define them under the `sidecars` parameter using the Kubernetes container spec.

```yaml
sidecars:
  - name: your-image-name
    image: your-image
    imagePullPolicy: Always
    ports:
      - name: portName
        containerPort: 1234
```

Similarly, you can add extra init containers using the `initContainers` parameter.

```yaml
initContainers:
  - name: your-image-name
    image: your-image
    imagePullPolicy: Always
    ports:
      - name: portName
        containerPort: 1234
```
