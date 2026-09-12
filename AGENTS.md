# AGENTS.md

Instructions for AI agents working in this repository. Read this before changing anything.

## What this is

A Helm chart repository holding one chart, `helmet`, a **library chart**. It is not installable on its own. Application charts declare it as a dependency, write `{{ include "helmet.app" . }}`, and configure everything through `values.yaml`.

Charts are distributed as **OCI artifacts** to `ghcr.io/rashadansari/charts`. There is no `gh-pages` branch, no `index.yaml`, and no chart-releaser. Do not reintroduce them.

## Layout

```
charts/helmet/
  Chart.yaml            version and appVersion, kept in sync
  values.yaml           all values nested under exports.defaults, with ## @param annotations
  templates/_*.yaml     named template partials, all underscore-prefixed
  templates/_pod.yaml   the pod template shared by both workloads
  README.md             the Parameters section is GENERATED, see below
  examples/simple/      minimal chart, renders Deployment + Service + Ingress
  examples/full/        exercises most features, renders 11 resources
  examples/stateful/    StatefulSet with per-replica storage
Makefile                deps, lint, readme, readme-check, check
.github/workflows/ci.yaml
```

`image.repository` decides whether there is a workload at all; `workload.kind` decides whether it is a Deployment or a StatefulSet.

## Hard rules

**Never hand-edit the `## Parameters` section of `charts/*/README.md`.** It is generated from the `## @param` annotations in `values.yaml` by `@bitnami/readme-generator-for-helm` (pinned in the Makefile). Edit the annotation, then run `make readme`. CI fails on drift.

**Every value needs a `@param` and every `@param` needs a value.** The generator errors on either mismatch and the `check` job fails. A `@param` naming a key that does not exist is the most common way this breaks, usually from copy-paste.

**Bump the chart version in the same commit as the change it describes.** CI publishes on push to `main` based on `Chart.yaml`'s `version`. A bump committed ahead of its fixes ships a version that does not contain them. This already happened once: published `0.15.0` is missing the fixes that its own commit range implies.

**Both workloads share one pod template.** `templates/_pod.yaml` defines `helmet.podTemplate`, included by `helmet.deployment` and `helmet.statefulset`. Never add a container or pod-level field to one workload alone. If you change how storage is mounted, the volume condition in `_pod.yaml` and the `volumeClaimTemplates` condition in `_statefulset.yaml` must stay in step, or the pod mounts a volume nothing defines.

## Commands

```bash
make check     # what CI runs: lint plus parameter table verification
make readme    # regenerate parameter tables after editing @param annotations
make lint      # helm lint every chart
make help      # list targets
```

Requires `helm`, `yq` and `npx` on PATH.

## Making a change

1. Edit templates or `values.yaml`.
2. If you touched `@param` annotations, run `make readme`.
3. Run `make check`.
4. **Render an example.** See below. This is not optional.
5. Bump `version` and `appVersion` in `Chart.yaml`, plus the other references listed under Releasing.

### `helm lint` is not enough

Every file in `templates/` is an underscore-prefixed partial, so Helm renders none of them during `helm lint` on the library chart itself. Lint passes on templates that crash the moment a consumer includes them. A broken `helmet.notes` passed lint for the entire life of this repo.

The real test is rendering a chart that consumes helmet:

```bash
make deps
helm package charts/helmet --destination /tmp/dist
rm -rf /tmp/ex && cp -r charts/helmet/examples/full /tmp/ex
mkdir -p /tmp/ex/charts && cp /tmp/dist/helmet-*.tgz /tmp/ex/charts/
helm template demo /tmp/ex
```

`examples/full` should produce 11 resources. Vary `--set` to reach branches the examples do not cover, particularly each `service.type`.

To test `helmet.notes`, include it from a throwaway chart's ConfigMap and run `helm template`. `helm install --dry-run` cannot render NOTES without a reachable cluster, even with `--dry-run=client`.

## Releasing

Push to `main` publishes any chart whose `Chart.yaml` version is not already in the registry, pushing the OCI artifact and cutting a GitHub release with the `.tgz` attached. Already-published versions are skipped, so unrelated merges are no-ops.

A version bump touches six places. `grep -rn "<old version>" --exclude-dir=.git .` finds them all:

- `charts/helmet/Chart.yaml`: `version` and `appVersion`
- `charts/helmet/README.md`: the dependency snippet
- `README.md`: the dependency snippet and the `helm pull --version` command
- `charts/helmet/examples/README.md`: the `file://` snippet

The example charts pin `version: ^0` and need no edit.

The root `README.md` also carries a hand-written parameter count ("Behind those toggles sit N documented parameters"). Check it against `grep -cE '^\| `' charts/helmet/README.md` whenever the table changes size.

## Auditing values against templates

Worth re-running after template changes. Diff both directions: every `.Values.X` referenced across `templates/*` against every leaf path declared under `exports.defaults`. Values declared but never read are dead; values read but never declared are invisible in the generated docs. Both classes existed here and both are now empty.

One trap: `nameOverride`, `fullnameOverride`, `namespaceOverride`, `kubeVersion` and `ingress.apiVersion` look dead but are consumed by bitnami/common's `_names.tpl` and `_capabilities.tpl`. Extract `charts/common-*.tgz` and grep it before calling a top-level value dead.

## Gotchas

- The generator has no option for a values root prefix, and this chart nests everything under `exports.defaults` (required for `import-values`). The Makefile extracts the subtree with `yq '.exports.defaults // .'` first. The `// .` fallback also handles ordinary application charts.
- `helm package` fails if `charts/helmet/charts/` is missing. Run `make deps` first, and do not redirect its stderr to `/dev/null`, or you will silently test a stale `.tgz`.
- IDE YAML errors on `templates/_*.yaml` are the editor parsing Go templates as plain YAML. Expected, ignore them.
- `import-values: [defaults]` in a consumer's `Chart.yaml` is mandatory. Without it helmet's values are not merged and every template fails on a missing key.

## Documentation style

Match the existing prose: sentence-case headings, no em dashes, no emoji, straight quotes. Claims about behavior must be verified against the templates, not inferred from surrounding docs. Much of the original upstream text described things the chart never did.
