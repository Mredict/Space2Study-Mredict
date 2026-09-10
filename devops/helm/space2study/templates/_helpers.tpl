{{- define "space2study.labels" -}}
app.kubernetes.io/part-of: space2study
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
