{{- define "common.name" -}}
{{- .Values.name | default .Chart.Name -}}
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

{{- define "common.image" -}}
{{- $serviceName := .Values.name | default .Chart.Name -}}
{{- $serviceConfig := index .Values $serviceName | default dict -}}
{{- $repo := "" -}}
{{- $tag := "latest" -}}

{{/* Handle different image configuration formats */}}
{{- if $serviceConfig.images -}}
  {{- if kindIs "slice" $serviceConfig.images -}}
    {{- $imageString := index $serviceConfig.images 0 | toString -}}
    {{- if contains ":" $imageString -}}
      {{- $parts := split ":" $imageString -}}
      {{- $repo = $parts._0 -}}
      {{- $tag = $parts._1 -}}
    {{- else -}}
      {{- $repo = $imageString -}}
    {{- end -}}
  {{- else -}}
    {{- $repo = $serviceConfig.images | toString -}}
  {{- end -}}
{{- else if $serviceConfig.image -}}
  {{- if kindIs "map" $serviceConfig.image -}}
    {{- $repo = $serviceConfig.image.repository | default $serviceConfig.image.name -}}
    {{- $tag = $serviceConfig.image.tag | default "latest" -}}
  {{- else -}}
    {{- $repo = $serviceConfig.image | toString -}}
  {{- end -}}
{{- else -}}
  {{- $repo = printf "egovio/%s" $serviceName -}}
{{- end -}}

{{/* Output the final image */}}
{{- if contains "/" $repo -}}      
{{- printf "%s:%s" $repo $tag -}}
{{- else -}}
{{- printf "%s/%s:%s" ($.Values.global.containerRegistry | default "egovio") $repo $tag -}}
{{- end -}}
{{- end }}

{{- define "common.serviceImage" -}}
{{- $serviceName := .Values.name | default .Chart.Name -}}
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
