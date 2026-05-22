{{/*
common validations
*/}}
{{- define "llm-d-router.validations.gateway.common" -}}
{{- if or (empty $.Values.inferencePool.modelServers) (not $.Values.inferencePool.modelServers.matchLabels) }}
{{- fail ".Values.inferencePool.modelServers.matchLabels is required" }}
{{- end }}
{{- end -}}
