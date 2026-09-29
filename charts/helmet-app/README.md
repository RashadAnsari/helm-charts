# helmet-app

[![Release](https://img.shields.io/github/v/release/RashadAnsari/helmet?sort=semver&filter=helmet-app-*&label=chart)](https://github.com/RashadAnsari/helmet/releases?q=helmet-app)
[![ghcr.io](https://img.shields.io/badge/ghcr.io-rashadansari%2Fcharts%2Fhelmet--app-2088FF?logo=github&logoColor=white)](https://github.com/RashadAnsari/helmet/pkgs/container/charts%2Fhelmet-app)
[![Chart type](https://img.shields.io/badge/chart%20type-application-0F1689?logo=helm&logoColor=white)](https://helm.sh/docs/topics/charts/#chart-types)

An installable chart that deploys an application from a values file alone. It bundles [helmet](../helmet) and does nothing else: its only template is `{{ include "helmet.app" . }}`.

Use it when you do not want to maintain a chart of your own. If you need templates of your own next to helmet's, or want to pin the helmet version in your repository, depend on [helmet](../helmet) directly instead. Both take the same values.

## Install

Write a `values.yaml`:

```yaml
image:
  repository: nginx

ports:
  - name: http
    containerPort: 80
    protocol: TCP

ingress:
  enabled: true
```

Install it:

```bash
$ helm install my-app oci://ghcr.io/rashadansari/charts/helmet-app --version 0.22.0 -f values.yaml
```

Upgrade with `helm upgrade` and the same arguments. Every value in the [helmet parameter table](../helmet/README.md#parameters) works here, at the top level of your file.

## Names

Resource names come from bitnami/common and include the chart name, so the release above creates `my-app-helmet-app` with the label `app.kubernetes.io/name: helmet-app`. To name them after your application, set both:

```yaml
nameOverride: my-app
fullnameOverride: my-app
```

## Validation

helmet's `values.schema.json` is bundled, so Helm checks your values on every `template`, `install` and `upgrade` with no extra setup:

```console
$ helm template my-app oci://ghcr.io/rashadansari/charts/helmet-app --version 0.22.0 --set replicaCount=two
Error: values don't meet the specifications of the schema(s) in the following chart(s):
helmet-app:
- at '/replicaCount': got string, want number
```

## Versions

helmet-app is released with helmet and always has the same version, containing that version of helmet's templates.
