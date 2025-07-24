{{- define "common.name" -}}
{{- .Values.name | default "unknown" -}}
{{- end }}

{{- define "common.labels" -}}
app: {{ template "common.name" . }}
{{- if .Values.labels }}
{{- if .Values.labels.group }}      
group: {{ .Values.labels.group }}  
{{- end }}
{{- end }}
{{- if .Values.additionalLabels }}
{{- range $key, $val := .Values.additionalLabels }}
{{ $key }}: {{ $val | quote }}
{{- end }}    
{{- end }}
{{- end }}

{{- define "common.serviceImage" -}}
{{- $serviceName := .Values.name | default "unknown" -}}
{{- $serviceConfig := index .Values $serviceName | default dict -}}
{{- if $serviceConfig.images -}}
  {{- if kindIs "slice" $serviceConfig.images -}}
    {{- $imageString := index $serviceConfig.images 0 | toString -}}
    {{- if contains ":" $imageString -}}
      {{- $imageString -}}
    {{- else -}}
      {{- printf "%s:latest" $imageString -}}
    {{- end -}}
  {{- else -}}
    {{- printf "%s:latest" ($serviceConfig.images | toString) -}}
  {{- end -}}
{{- else -}}
  {{- printf "egovio/%s:latest" $serviceName -}}
{{- end -}}
{{- end }}

{{- define "common.image" -}}
{{- $Values := .Values -}}
{{- $repository := .repository -}}
{{- $tag := .tag -}}
{{- if and $repository $tag -}}
  {{- printf "%s/%s:%s" ($Values.global.containerRegistry | default "egovio") $repository $tag -}}
{{- else if $repository -}}
  {{- printf "%s/%s:latest" ($Values.global.containerRegistry | default "egovio") $repository -}}
{{- else -}}
  {{- printf "egovio/unknown:latest" -}}
{{- end -}}
{{- end }}
