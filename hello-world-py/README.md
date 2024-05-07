# Hello World
A simple hello-world microservice

# Local Development
- [Poetry](https://python-poetry.org/)
- Python3
- Docker
```
docker-compose build
docker-compose up
```
# Image Building
Pre-req if using an M1 mac
```
docker buildx create --name m1_builder
docker buildx use m1_builder
```

Then run make commands:
```
make image
make push
```

# Kubernetes

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello-world
  name: hello-world
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
        - image: etapau/hello-world
          imagePullPolicy: Always
          name: hello-world
          resources:
            requests:
              cpu: 500m
              memory: 64Mi
          ports:
            - containerPort: 9000
              protocol: TCP
      restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  name: hello-world
spec:
  type: NodePort
  selector:
    app: hello-world
  ports:
    - port: 80
      protocol: TCP
      targetPort: 9000
      nodePort: 30091

```