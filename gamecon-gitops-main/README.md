# GameCon GitOps Repository

> Production-ready GitOps configuration for GameCon application deployment on Kubernetes, featuring comprehensive infrastructure automation, monitoring, logging, and secure secrets management.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Prerequisites](#prerequisites)
- [Monitoring & Observability](#monitoring--observability)
- [Security](#security)
## Overview

This repository implements a complete GitOps workflow for the GameCon application, demonstrating enterprise-grade Kubernetes deployment patterns with comprehensive infrastructure automation. The setup includes automated certificate management, centralized logging, metrics collection, secrets management, and database replication.

**Key Features:**

- **App of Apps Pattern** - Hierarchical application management with ArgoCD
- **Complete Observability Stack** - Prometheus, Grafana, Elasticsearch, Fluent Bit, Kibana
- **Automated TLS Management** - Cert-manager with Let's Encrypt integration
- **Secrets Management** - External Secrets Operator with AWS Secrets Manager
- **Database High Availability** - PostgreSQL with read replicas and automated failover
- **Intelligent Scaling** - Karpenter for cost-optimized node provisioning
- **Production Security** - Network policies, RBAC, and security contexts

## OverView

![OverView](architecture/OverView.drawio.png)

## K8S Architecture

![K8S Architecture](architecture/K8S-OverView.drawio.png)

## K8S Flow

![K8S Flow](architecture/K8S-Flow.drawio.png)


**Deployment Flow:**
1. ArgoCD monitors GitOps repository for changes
2. Bootstrap application deploys infrastructure components using sync waves
3. Infrastructure components establish monitoring, logging, and security foundations
4. GameCon application deploys with all dependencies ready
5. Continuous monitoring and automated healing ensure system reliability

## Technology Stack

| Component              | Technology                   | Purpose                           |
| ---------------------- | ---------------------------- | --------------------------------- |
| **GitOps Controller**  | ArgoCD 8.0.10               | Automated deployment & sync       |
| **Application**        | Flask (Python), Helm Charts | Web application & packaging       |
| **Database**           | PostgreSQL 16.7.4           | Primary DB with read replicas     |
| **Ingress Controller** | NGINX Ingress 4.10.0        | Load balancing & SSL termination  |
| **Certificate Mgmt**   | cert-manager v1.14.4        | Automated TLS certificate mgmt    |
| **Secrets Management** | External Secrets 0.17.0     | AWS Secrets Manager integration   |
| **Monitoring Stack**   | Prometheus, Grafana, AlertManager | Metrics, visualization, alerting |
| **Logging Stack**      | Elasticsearch, Fluent Bit, Kibana | Centralized logging & analysis  |
| **Container Registry** | AWS ECR                      | Private container image storage   |
| **Auto-scaling**       | Karpenter                    | Intelligent node provisioning     |
| **Security**           | RBAC, Pod Security, Network Policies | Multi-layer security controls |


## Prerequisites

Ensure you have the following components ready before deploying:

### Infrastructure Requirements
- **EKS Cluster** - Kubernetes 1.32+ with OIDC provider enabled
- **AWS Secrets Manager** - Database credentials stored securely
- **ECR Repository** - GameCon container images (tag: 1.0.24)
- **DNS Management** - Domain configured for gamecon.freedynamicdns.net
- **IAM Roles** - External Secrets Operator with Secrets Manager access

### Tool Requirements
- **kubectl** (1.28+) configured for your EKS cluster
- **helm** (3.0+) for chart management
- **aws-cli** (2.0+) with appropriate permissions
- **Git** access to this repository

3. **Deploy Karpenter (Optional but Recommended)**

```bash
cd karpenter
chmod +x deploy-karpenter.sh
./deploy-karpenter.sh
```

Expected output: All infrastructure components healthy and ready, Karpenter provisioning nodes on-demand.


## Infrastructure Components

### Certificate Management (Wave 0)
- **cert-manager** automatically provisions and renews TLS certificates
- **ClusterIssuer** configured for Let's Encrypt production environment
- **Automated DNS validation** for certificate challenges

### Monitoring Stack (Wave 1)
- **Prometheus** collects metrics from all cluster components
- **Grafana** provides visualization dashboards and alerting
- **AlertManager** handles alert routing and notification
- **ServiceMonitor** configured for GameCon application metrics

### Ingress & Load Balancing (Wave 2)
- **NGINX Ingress Controller** with AWS NLB integration
- **Cross-zone load balancing** for high availability
- **Metrics integration** with Prometheus monitoring

### Secrets Management (Wave 3)
- **External Secrets Operator** syncs secrets from AWS Secrets Manager
- **ClusterSecretStore** configured for regional access
- **Automatic secret rotation** and refresh capabilities

### Centralized Logging (Waves 4-6)
- **Elasticsearch** cluster for log storage and indexing
- **Fluent Bit** agents collect logs from all pods
- **Kibana** provides log search and visualization interface

## Application Deployment

### GameCon Application (Wave 7)

The GameCon application demonstrates a production-ready Flask application with comprehensive Kubernetes integration:

**Security Features:**
- Non-root container execution
- Security contexts with user/group isolation
- Network policies for pod-to-pod communication
- TLS encryption for all external traffic

**Database Integration:**
- PostgreSQL cluster with primary/replica architecture
- 3 read replicas for improved performance
- Comprehensive logging configuration
- Automated backup and recovery procedures

## Monitoring & Observability

### Metrics Collection
- **Application Metrics**: Custom metrics exposed on `/metrics` endpoint
- **Infrastructure Metrics**: Node, pod, and cluster-level monitoring
- **Database Metrics**: PostgreSQL performance and replication status
- **Ingress Metrics**: Request rates, latency, and error rates

### Log Aggregation
- **Application Logs**: Structured JSON logging with correlation IDs
- **Access Logs**: NGINX ingress request logging
- **System Logs**: Kubernetes events and system component logs
- **Database Logs**: PostgreSQL query and connection logging

### Dashboards
Pre-configured Grafana dashboards available for:
- Application performance and error rates
- Database cluster health and performance
- Kubernetes cluster resource utilization
- Ingress controller traffic patterns

## Security

### Network Security
- **Private Subnets**: Application pods run in private networks
- **Security Groups**: Strict ingress/egress rules
- **Network Policies**: Pod-to-pod communication controls
- **TLS Everywhere**: End-to-end encryption for all traffic

### Identity & Access Management
- **RBAC**: Role-based access control for all components
- **Service Accounts**: Dedicated accounts with minimal permissions
- **IRSA**: IAM Roles for Service Accounts integration
- **Pod Security Standards**: Enforced security contexts

### Secrets Management
- **External Secrets**: No secrets stored in Git repository
- **AWS Secrets Manager**: Centralized secret storage with rotation
- **Encryption at Rest**: All persistent volumes encrypted
- **Secret Rotation**: Automated credential rotation capabilities

### Container Security
- **Non-root Execution**: All containers run as non-privileged users
- **Read-only Filesystems**: Immutable container filesystems
- **Resource Limits**: CPU and memory constraints prevent resource exhaustion
- **Image Scanning**: Container vulnerability scanning in CI/CD pipeline


### Performance Optimization

**Database Performance:**
- Monitor replication lag between primary and replicas
- Optimize PostgreSQL configuration for workload patterns
- Use connection pooling for efficient resource utilization
- Regular VACUUM and ANALYZE operations

**Application Scaling:**
- Configure Horizontal Pod Autoscaler (HPA) based on CPU/memory metrics
- Implement readiness and liveness probes for proper health checking
- Use Karpenter for automatic node scaling based on pod requirements
- Monitor application metrics to identify bottlenecks


## Cost Optimization

**Resource Management:**
- Right-sized resource requests and limits
- Karpenter for intelligent instance selection
- Spot instance utilization where appropriate
- Automated scaling based on actual usage

**Storage Optimization:**
- GP3 storage for cost-effective performance
- Lifecycle policies for log retention
- Compressed log storage in Elasticsearch

**Monitoring Costs:**
- Track resource usage with Grafana dashboards
- Set up alerts for unexpected cost increases
- Regular review of resource allocation vs. utilization


## Acknowledgments

- **ArgoCD Community** for powerful GitOps capabilities and best practices
- **Helm Community** for comprehensive Kubernetes package management
- **cert-manager Project** for automated certificate lifecycle management
- **External Secrets Operator** for secure secrets management integration
- **Elastic Stack** for centralized logging and observability solutions
- **Prometheus Community** for metrics collection and monitoring standards
- **PostgreSQL Team** for robust database clustering capabilities
- **Karpenter Project** for intelligent Kubernetes node provisioning
- **AWS** for managed services integration and cloud-native patterns