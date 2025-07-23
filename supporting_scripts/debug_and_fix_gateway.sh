#!/bin/bash

echo "=== Comprehensive Gateway Template Debug and Fix ==="

cd /home/ubuntu/DPI/DIGIT-DevOps/deploy-as-code/charts/core-services

echo "Current directory: $(pwd)"

echo -e "\n=== 1. Check Current Common Template Line 112 ==="
if [ -f "gateway/charts/common/templates/_deployment.yaml" ]; then
    echo "Line 112 in common deployment template:"
    sed -n '110,115p' gateway/charts/common/templates/_deployment.yaml
else
    echo "Common template not found in gateway/charts/"
    if [ -f "../common/templates/_deployment.yaml" ]; then
        echo "Line 112 in ../common/templates/_deployment.yaml:"
        sed -n '110,115p' ../common/templates/_deployment.yaml
    fi
fi

echo -e "\n=== 2. Force Clean and Rebuild Dependencies ==="
cd gateway
echo "Cleaning old dependencies..."
rm -rf charts/
rm -f Chart.lock

echo "Updating dependencies..."
helm dependency update

echo -e "\n=== 3. Check What Values Are Actually Being Passed ==="
echo "Creating test template to debug values..."

# Create a simple debug template
cat > templates/debug-values.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: debug-values
data:
  image-repository: "{{ .Values.image.repository | default "NOT_SET" }}"
  image-tag: "{{ .Values.image.tag | default "NOT_SET" }}"
  image-pullPolicy: "{{ .Values.image.pullPolicy | default "NOT_SET" }}"
  replicas: "{{ .Values.replicas | default "NOT_SET" }}"
  httpPort: "{{ .Values.httpPort | default "NOT_SET" }}"
  all-values: |
{{ toYaml .Values | indent 4 }}
EOF

echo "Testing with debug template..."
helm template gateway . --debug 2>&1 | grep -A 20 "debug-values" || echo "Debug template failed"

# Clean up debug template
rm -f templates/debug-values.yaml

echo -e "\n=== 4. Check Common Template Image Reference ==="
if [ -f "charts/common/templates/_deployment.yaml" ]; then
    echo "Searching for image references in common template:"
    grep -n "image" charts/common/templates/_deployment.yaml
    
    echo -e "\nContext around line 112:"
    sed -n '105,120p' charts/common/templates/_deployment.yaml
fi

echo -e "\n=== 5. Create Fixed Common Template ==="
# Let's create a fixed version of the common deployment template
if [ -f "charts/common/templates/_deployment.yaml" ]; then
    echo "Backing up original common template..."
    cp charts/common/templates/_deployment.yaml charts/common/templates/_deployment.yaml.backup
    
    echo "Creating fixed common template..."
    cat > charts/common/templates/_deployment.yaml << 'EOF'
{{- define "common.deployment" -}}
{{- if .Capabilities.APIVersions.Has "apps/v1" }}
apiVersion: apps/v1
{{- else }}
apiVersion: extensions/v1beta1
{{- end }}
kind: Deployment
metadata:
  name: {{ template "common.name" . }}
  namespace: {{ .Values.namespace }}
  labels:
{{- include "common.labels" . | nindent 4 }}   
spec:
{{- if .Capabilities.APIVersions.Has "apps/v1" }}
  selector:
    matchLabels:
      {{- include "common.labels" . | nindent 6 }}  
{{- end }}
{{- $persistence := .Values.persistence | default dict -}}
{{- if and (not (hasKey $persistence "enabled")) (eq (.Values.replicas | int) 1) }}
  strategy:
    rollingUpdate:
      maxUnavailable: 0
{{- end }}     
  replicas: {{ .Values.replicas }}
  template:
    metadata:  
      annotations:
      {{- if not .Values.disableAnnotationTimestamp }}      
        deployment-timestamp: "{{ date "20060102150405" .Release.Time }}"    
      {{- end }}          
      {{- if .Values.additionalAnnotations }}                                   
        {{- tpl  .Values.additionalAnnotations . | nindent 8 }}
      {{- end }}        
      labels:
      {{- include "common.labels" . | nindent 8 }}            
    spec:
    {{- if .Values.initContainers.gitSync.enabled }}
      securityContext:
        fsGroup: 65533 # to make SSH key readable 
    {{- end }} 
    {{- if or .Values.initContainers.gitSync.enabled .Values.extraVolumes }}     
      volumes:  
    {{- if .Values.initContainers.gitSync.enabled }}  
      - name: git-secret
        secret:
          secretName: git-creds
          defaultMode: 288 # = mode 0440
      - name: workdir
        emptyDir: {}               
    {{- end }}     
      {{- with .Values.extraVolumes }}
        {{- tpl . $ | nindent 6 }}
      {{- end }}     
    {{- end }}        
    {{- if .Values.affinity.preferSpreadAcrossAZ }}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              topologyKey: "failure-domain.beta.kubernetes.io/zone"
              labelSelector:
                matchLabels:
                {{- include "common.labels" . | nindent 18 }}     
    {{- end }}  
    {{- if .Values.serviceAccount }}
      {{- if and .Values.serviceAccount.create .Values.serviceAccount.name }}
      serviceAccountName: {{ .Values.serviceAccount.name }}
      {{- else if (kindIs "string" .Values.serviceAccount) }}
      serviceAccountName: {{ .Values.serviceAccount }}
      {{- end }}  
    {{- end }}     
      initContainers:
      {{- with .Values.initContainers.extraInitContainers }}
        {{- tpl . $ | nindent 8 }}
      {{- end }}
      {{- if .Values.initContainers.dbMigration.enabled }}
      {{ with .Values.initContainers.dbMigration}}
      - name: "db-migration"
        image: {{ template "common.image" (dict "Values" $.Values "repository" .image.repository "tag" .image.tag) }}
        imagePullPolicy: {{ .image.pullPolicy }} 
      {{- end }}    
        {{- if .Values.initContainers.dbMigration.env }}               
        env: 
          {{- tpl  .Values.initContainers.dbMigration.env . | nindent 12 }}
        {{- end }}
      {{- end }}        
      {{- if .Values.initContainers.gitSync.enabled }}
      {{ with .Values.initContainers.gitSync }}
      - name: "git-sync"
        image: {{ template "common.image" (dict "Values" $.Values "repository" .image.repository "tag" .image.tag) }}
        imagePullPolicy: {{ .image.pullPolicy }}   
      {{- end }}
        securityContext:
          runAsUser: 65533 # git-sync user
        volumeMounts:
        - name: git-secret
          mountPath: /etc/git-secret              
        - name: workdir
          mountPath: "/work-dir"                   
        {{- if .Values.initContainers.gitSync.env }}               
        env: 
          {{- tpl  .Values.initContainers.gitSync.env . | nindent 12 }}
        {{- end }}        
      {{- end }}            
      containers:
      {{- with .Values.extraContainers }}
        {{- tpl . $ | nindent 8 }}
      {{- end }}      
        - name: {{ template "common.name" . }}
          {{- if and .Values.image .Values.image.repository .Values.image.tag }}
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          {{- else }}
          image: {{ template "common.image" (dict "Values" $.Values "repository" .Values.image.repository "tag" .Values.image.tag) }}
          {{- end }}
          {{- if .Values.image.pullPolicy }}
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- else }}
          imagePullPolicy: IfNotPresent
          {{- end }}
      {{- if .Values.args }}              
          args:  
          {{- tpl  .Values.args . | nindent 12 }}          
       {{- end }}             
          ports:
            - name: http
              containerPort: {{ .Values.httpPort }}
              protocol: TCP
      {{- if .Values.healthChecks.enabled }}              
          readinessProbe:
          {{- tpl  .Values.healthChecks.readinessProbe . | nindent 12 }} 
          livenessProbe:
          {{- tpl  .Values.healthChecks.livenessProbe . | nindent 12 }}                      
       {{- end }}       
        {{- if .Values.lifecycle }}
          lifecycle:
          {{- toYaml .Values.lifecycle | nindent 12 }}
        {{- end }}      
        {{- if or .Values.initContainers.gitSync.enabled .Values.extraVolumeMounts }}
          volumeMounts:              
        {{- if .Values.initContainers.gitSync.enabled }}            
          - name: workdir
            mountPath: "/work-dir"
        {{- end }}             
        {{- with .Values.extraVolumeMounts }}
          {{- tpl . $ | nindent 10 }}
        {{- end }}          
        {{- end }}     
      {{- if or .Values.env (eq .Values.appType "java-spring") (index .Values "global" "tracing-enabled") }}                         
          env:  
        {{- if .Values.env }}                                   
          {{- tpl  .Values.env . | nindent 12 }}
        {{- end -}}         
        {{- if eq .Values.appType "java-spring" }} 
          {{- tpl  .Values.extraEnv.java . | nindent 12 }}         
        {{- end -}} 
        {{- if or (index .Values "global" "tracing-enabled") (index .Values "tracing-enabled") }} 
          {{- tpl  .Values.extraEnv.jaeger . | nindent 12 }}         
        {{- end }}
      {{- end }}
      {{- if .Values.resources }}                                     
          resources:
            {{- tpl .Values.resources . | nindent 12 }}
      {{- end }}            
    {{- with .Values.nodeSelector }}
      nodeSelector:
{{ toYaml . | indent 8 }}
    {{- end }}
    {{- with .Values.tolerations }}
      tolerations:
{{ toYaml . | indent 8 }}
    {{- end }}
{{- end -}}
EOF

    echo "Fixed common template created."
fi

echo -e "\n=== 6. Test the Fixed Template ==="
cd ..
echo "Testing fixed template..."
helmfile -f coreservices-helmfile.yaml.gotmpl --selector name=gateway template 2>&1 | head -50

echo -e "\n=== 7. Summary ==="
echo "Key changes made:"
echo "1. Added proper null checks for image values"
echo "2. Fixed image template reference on line 112"
echo "3. Added fallback image handling"
echo "4. Ensured serviceAccount name is properly referenced"
echo ""
echo "If the test above shows valid YAML, proceed with deployment:"
echo "helmfile -f coreservices-helmfile.yaml.gotmpl --selector name=gateway apply"
