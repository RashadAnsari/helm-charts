# Examples

Three runnable application charts that depend on helmet. All contain the same single-line `templates/app.yaml`; everything else is `values.yaml`.

| Example                | Renders                                                                 | Shows                                                        |
|------------------------|-------------------------------------------------------------------------|--------------------------------------------------------------|
| [simple](simple)       | Deployment, Service, Ingress                                            | The smallest chart that produces a working service           |
| [full](full)           | The above plus ConfigMap, Secret, PVC, HPA, ServiceAccount, ServiceMonitor, CronJob | Probes, persistence, autoscaling, monitoring and scheduled jobs |
| [stateful](stateful)   | StatefulSet, Service, headless Service                                  | `workload.kind`, per-replica volumeClaimTemplates, stable pod DNS |

## Running one

```bash
$ cd simple
$ helm dependency update
$ helm template demo .
```

Swap `helm template demo .` for `helm install demo .` to deploy it to the cluster in your current context.

All three pull helmet from `oci://ghcr.io/rashadansari/charts`. To try local changes to the chart instead, point the dependency at the working copy:

```yaml
# Chart.yaml
dependencies:
  - name: helmet
    version: 0.20.1
    repository: file://../..
    import-values:
      - defaults
```

## Note on `import-values`

All three declare:

```yaml
    import-values:
      - defaults
```

Without it, helmet's `values.yaml` is not merged into the parent chart and every template fails on a missing key. It is not optional.
