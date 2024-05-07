#!/bin/bash

# Set the name of your Helm chart
HELM_CHART_NAME="the_name_of_your_chart" # e.g. hello-world-go, etc

# Create the templates directory if it doesn't exist
mkdir -p "$HELM_CHART_NAME/templates"

# Replace hardcoded values in the Kubernetes YAML with Helm variables
cat << 'EOF' > "$HELM_CHART_NAME/templates/deployment.yaml"
{{- if .Values.deployment.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.deployment.name }}
spec:
  replicas: {{ .Values.deployment.replicas }}
  selector:
    matchLabels:
      app: {{ .Values.appName }}
  template:
    metadata:
      labels:
        app: {{ .Values.appName }}
    spec:
      serviceAccountName: {{ .Values.serviceAccount.serviceAccountName }}  # Add this line to specify the service account
      securityContext:
        runAsNonRoot: {{ .Values.deployment.securityContext.runAsNonRoot }}
        runAsUser: {{ .Values.deployment.securityContext.runAsUser }}
      containers:
      - name: {{ .Values.container.name }}
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        ports:
        - containerPort: {{ .Values.container.port }}
        resources:
          limits:
            cpu: {{ .Values.resources.limits.cpu }}
            memory: {{ .Values.resources.limits.memory }}
          requests:
            cpu: {{ .Values.resources.requests.cpu }}
            memory: {{ .Values.resources.requests.memory }}
        imagePullPolicy: {{ .Values.container.imagePullPolicy }}
        livenessProbe:
          httpGet:
            path: {{ .Values.livenessProbe.httpGet.path }}
            port: {{ .Values.container.port }}
        readinessProbe:
          httpGet:
            path: {{ .Values.readinessProbe.httpGet.path }}
            port: {{ .Values.container.port }}
        env:
{{ toYaml .Values.env | indent 10 }}
      imagePullSecrets:
{{ toYaml .Values.imagePullSecrets | indent 8 }}
{{- end }}
EOF

# Create or update values.yaml file
cat << EOF > "$HELM_CHART_NAME/values.yaml"
# This is a values file that works with a local deployment
deployment:
  enabled: true
  name: azureinterview-broken-deployment
  replicas: 1
  securityContext:
    runAsNonRoot: true
    runAsUser: 1337
container:
  name: azureinterview-broken-container
  port: 8080
  imagePullPolicy: Always
livenessProbe:
  httpGet:
    path: /healthz
readinessProbe:
  httpGet:
    path: /healthz
resources:
  limits:
    cpu: "0.5"
    memory: "512Mi"
  requests:
    cpu: "0.1"
    memory: "128Mi"
image:
  repository:
  tag: latest
env:
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_NAMESPACE
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  - name: POD_UID
    valueFrom:
      fieldRef:
        fieldPath: metadata.uid
imagePullSecrets:
  - name: regcred
appName: azureinterview-broken-app
serviceAccount:
  create: true
  serviceAccountName: mechanicode

role:
  enabled: true
  name: mechanicode
  rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["get", "list"]

roleBinding:
  enabled: true
  name: mechanicode-view-namespace
  namespace: mechanicode-go
  subjects:
    - kind: ServiceAccount
      name: mechanicode
  roleRef:
    kind: Role
    name: mechanicode

service:
  port: 8080
ingress:
  enabled: true
  name: azureinterview-broken-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    #nginx.ingress.kubernetes.io/rewrite-target: /$2 # Do you need this? Only if you're deploying behind an nginx-ingress controller
  ingressClassName: nginx
  tls:
    hosts:
      - test.com # you'll need to change this
    secretName: azureinterview-broken-tls
  rules:
    - host: test.com # you'll need to change this
      http:
        paths:
          - path: /az/go/
            pathType: Prefix
            backend:
              service:
                name: azureinterview-broken-service
                port:
                  number: 80
          - path: /container-info
            pathType: Prefix
            backend:
              service:
                name: azureinterview-broken-service
                port:
                  number: 80
          - path: /static/img
            pathType: Prefix
            backend:
              service:
                name: azureinterview-broken-service
                port:
                  number: 80
autoscaling:
  enabled: false
EOF

# Service
cat << 'EOF' > "$HELM_CHART_NAME/templates/service.yaml"
{{- if .Values.service.enabled }}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.service.name }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    protocol: {{ .Values.service.protocol }}
  selector:
    app: {{ .Values.appName }}
{{- end }}
EOF

# Role
cat << 'EOF' > "$HELM_CHART_NAME/templates/role.yaml"
{{- if .Values.role.enabled }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ .Values.role.name }}
  namespace: {{ .Values.role.namespace }}
rules:
{{ toYaml .Values.role.rules | indent 2 }}
{{- end }}
EOF

# RoleBinding
cat << 'EOF' > "$HELM_CHART_NAME/templates/rolebinding.yaml"
{{- if .Values.roleBinding.enabled }}
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ .Values.roleBinding.name }}
  namespace: {{ .Values.roleBinding.namespace }}
subjects:
{{ toYaml .Values.roleBinding.subjects | indent 2 }}
roleRef:
  kind: {{ .Values.roleBinding.roleRef.kind }}
  name: {{ .Values.roleBinding.roleRef.name }}
  apiGroup: {{ .Values.roleBinding.roleRef.apiGroup }}
{{- end }}
EOF

# Ingress
cat << 'EOF' > "$HELM_CHART_NAME/templates/ingress.yaml"
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Values.ingress.name }}
  annotations:
{{ toYaml .Values.ingress.annotations | indent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.ingressClassName }}
{{- if .Values.ingress.tls }}
  tls:
    - hosts:
{{ toYaml .Values.ingress.tls.hosts | indent 8 }}
      secretName: {{ .Values.ingress.tls.secretName | quote }}
{{- end }}
  rules:
{{ toYaml .Values.ingress.rules | indent 4 }}
{{- end }}
EOF

# Install the Helm chart
# helm install <release_name> "$HELM_CHART_NAME"