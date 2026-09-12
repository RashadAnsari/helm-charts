{{/*
Create the name of the service account to use
*/}}
{{- define "helmet.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Render an array of env variables. The input can be a map or a slice.
Values can be templates using the "common.tplvalues.render" helper, but changes to scope are not processed.
Usage:
{{ include "helmet.toEnvArray" ( dict "envVars" .Values.envVars "context" $ ) }}
*/}}
{{- define "helmet.toEnvArray" -}}
{{- if kindIs "map" .envVars }}
{{- range $key, $val := .envVars }}
- name: {{ $key | quote }}
{{- if kindIs "string" $val }}
  value: {{ (include "common.tplvalues.render" (dict "value" $val "context" $.context)) | quote }}
{{- else if kindIs "map" $val }}
{{ include "common.tplvalues.render" (dict "value" (omit $val "name") "context" $.context) | indent 2 }}
{{- end -}}
{{- end -}}
{{- else if kindIs "slice" .envVars }}
{{ include "common.tplvalues.render" (dict "value" .envVars "context" $.context) }}
{{- end }}
{{- end -}}

{{/*
Returns a non-empty string when the chart is configured to render a StatefulSet.
Empty otherwise, so it can be used directly in an `if`.
Usage:
{{ if include "helmet.isStatefulSet" . }}
*/}}
{{- define "helmet.isStatefulSet" -}}
{{- if eq .Values.workload.kind "StatefulSet" -}}
true
{{- end -}}
{{- end -}}

{{/*
Name of the headless Service that governs the StatefulSet, providing stable
per-pod DNS. Honours workload.serviceName when set.
*/}}
{{- define "helmet.headlessServiceName" -}}
{{- default (printf "%s-headless" (include "common.names.fullname" .)) .Values.workload.serviceName -}}
{{- end -}}
