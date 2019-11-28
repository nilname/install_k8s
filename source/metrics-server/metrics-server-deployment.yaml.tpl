apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-server
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: metrics-server-config
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: EnsureExists
data:
  NannyConfiguration: |-
    apiVersion: nannyconfig/v1alpha1
    kind: NannyConfiguration
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server-v0.3.6
  namespace: kube-system
  labels:
    k8s-app: metrics-server
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    version: v0.3.6
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
      version: v0.3.6
  template:
    metadata:
      name: metrics-server
      labels:
        k8s-app: metrics-server
        version: v0.3.6
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: 'docker/default'
    spec:
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      containers:
      - name: metrics-server
        image: PRI_DOCKER_HOST:5000/k8s.gcr.io/metrics-server-amd64:v0.3.6
        command:
        - /metrics-server
        - --metric-resolution=30s
        # These are needed for GKE, which doesn't support secure communication yet.
        # Remove these lines for non-GKE clusters, and when GKE supports token-based auth.
        - --kubelet-port=10255
        - --deprecated-kubelet-completely-insecure=true
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP
        - --requestheader-allowed-names=aggregator
        ports:
        - containerPort: 443
          name: https
          protocol: TCP
      - name: metrics-server-nanny
        image: PRI_DOCKER_HOST:5000/k8s.gcr.io/addon-resizer:1.8.5
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 5m
            memory: 50Mi
        env:
          - name: MY_POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: MY_POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
        volumeMounts:
        - name: metrics-server-config-volume
          mountPath: /etc/config
        command:
          - /pod_nanny
          - --config-dir=/etc/config
          #- --cpu={{ base_metrics_server_cpu }}
          - --cpu=80m
          - --extra-cpu=0.5m
          #- --memory={{ base_metrics_server_memory }}
          - --memory=300Mi
          #- --extra-memory={{ metrics_server_memory_per_node }}Mi
          - --extra-memory=50Mi
          - --threshold=5
          - --deployment=metrics-server-v0.3.6
          - --container=metrics-server
          - --poll-period=300000
          - --estimator=exponential
          # Specifies the smallest cluster (defined in number of nodes)
          # resources will be scaled to.
          #- --minClusterSize={{ metrics_server_min_cluster_size }}
          #- --minClusterSize=10
      volumes:
        - name: metrics-server-config-volume
          configMap:
            name: metrics-server-config
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      hostNetwork: true
