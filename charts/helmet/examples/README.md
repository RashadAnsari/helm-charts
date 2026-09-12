# Examples

Two runnable application charts that depend on helmet. Both contain the same single-line `templates/app.yaml`; everything else is `values.yaml`.

| Example             | Renders                                                                 | Shows                                                        |
|---------------------|-------------------------------------------------------------------------|--------------------------------------------------------------|
| [simple](simple)    | Deployment, Service, Ingress                                            | The smallest chart that produces a working service           |
| [full](full)        | The above plus ConfigMap, Secret, PVC, HPA, ServiceAccount, ServiceMonitor, CronJob | Probes, persistence, autoscaling, monitoring and scheduled jobs |

## Running one

```bash
$ cd simple
$ helm dependency update
$ helm template demo .
```

Swap `helm template demo .` for `helm install demo .` to deploy it to the cluster in your current context.

Both examples pull helmet from `oci://ghcr.io/rashadansari/charts`. To try local changes to the chart instead, point the dependency at the working copy:

```yaml
# Chart.yaml
dependencies:
  - name: helmet
    version: 0.15.0
    repository: file://../..
    import-values:
      - defaults
```

## Note on `import-values`

Both charts declare:

```yaml
    import-values:
      - defaults
```

Without it, helmet's `values.yaml` is not merged into the parent chart and every template fails on a missing key. It is not optional.
