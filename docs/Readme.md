# SecureFlow DevSecOps Pipeline

> **Securing a Vulnerable Banking Platform with a 7-Stage Automated Security Pipeline**

[![Pipeline](https://img.shields.io/badge/Pipeline-7%20Stages%20Green-2ED573?style=flat-square&logo=github-actions)](https://github.com/oluwafaj/Amdari-Project02/actions)
[![Secrets](https://img.shields.io/badge/Committed%20Secrets-0-2ED573?style=flat-square&logo=hashicorp)](/)
[![CVEs](https://img.shields.io/badge/Critical%20CVEs-0-2ED573?style=flat-square&logo=aquasec)](/)
[![Vault](https://img.shields.io/badge/Secrets-HashiCorp%20Vault-00D4AA?style=flat-square&logo=vault)](/)
[![Falco](https://img.shields.io/badge/Runtime-Falco%20Active-00D4AA?style=flat-square)](/)

---

## Overview

This project documents the end-to-end implementation of a DevSecOps security pipeline for **SecureFlow** — a deliberately vulnerable banking platform built with three Python microservices. The engagement transforms a comprehensively insecure baseline into a signed, policy-enforced, Vault-backed production-grade platform over a 10-day sprint.

The SecureFlow baseline ships with committed credentials, SQL injection, IDOR vulnerabilities, XSS, containers running as root, and Terraform modules provisioning overly permissive IAM. Together, these represent a realistic cross-section of vulnerabilities found in fast-moving engineering teams that have not invested in automated security controls.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions Pipeline                    │
│                                                               │
│  Stage 1    Stage 2    Stage 3    Stage 4    Stage 5          │
│  Gitleaks → SonarQube→ Trivy   → Checkov  → Gate   → Stage 7│
│  (secrets)  (SAST)   (CVEs)    (IaC)     (policy)   (DAST)  │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        Kubernetes       HashiCorp         Falco
        (kind/EKS)        Vault          DaemonSet
        OPA Gatekeeper   Agent Injector  Runtime Alerts
              │               │               │
              └───────────────┴───────────────┘
                              │
                        Prometheus
                        + Grafana
                     Security Dashboard
```

### Three Microservices

| Service | Port | Description |
|---|---|---|
| `auth-service` | 5001 | Authentication, JWT tokens, user management |
| `transaction-service` | 5002 | Balance, transfers, transaction history |
| `frontend` | 5000 | Server-rendered web interface |

---

## Quick Start

### Prerequisites

- Docker Desktop
- kubectl
- kind
- helm
- Trivy
- Gitleaks
- Checkov

### Run Locally

```bash
# Clone the repository
git clone https://github.com/oluwafaj/Amdari-Project02.git
cd Amdari-Project02

# Start all services
docker-compose up --build

# Verify services are running
docker-compose ps
```

Services will be available at:
- Frontend: http://localhost:5000
- Auth Service: http://localhost:5001
- Transaction Service: http://localhost:5002

---

## Pipeline Stages

The 7-stage GitHub Actions pipeline runs on every push and pull request.

### Stage 1 — Gitleaks Secret Scanning

Scans the full git history for committed credentials using custom rules targeting Flask `SECRET_KEY`, JWT secrets, and database passwords.

**Gate behaviour:** Hard-fail on any finding — merges are blocked.

```bash
# Run locally
gitleaks detect --source . --config .gitleaks.toml --log-opts="--all"
```

### Stage 2 — SonarQube SAST

Static analysis across all three Python microservices. Detects SQL injection, XSS, hardcoded secrets, and other code-level vulnerabilities.

**Gate behaviour:** Soft-fail — findings are routed to the AppSec team via PR comment. Hard-fail only on CRITICAL/BLOCKER severity.

### Stage 3 — Trivy Image Scanning

Scans all three service container images for known CVEs. The baseline `python:3.9-slim` image contained 6 CRITICAL CVEs including OpenSSL remote code execution. After upgrading to `python:3.12-slim`, zero CRITICAL CVEs remain.

**Gate behaviour:** Hard-fail on CRITICAL CVEs.

```bash
# Run locally
trivy image amdari-project02-auth-service:latest --severity CRITICAL,HIGH
```

### Stage 4 — Checkov + Trivy K8s IaC Scan

Checkov scans Terraform modules for cloud misconfigurations. Trivy scans Kubernetes manifests for security policy violations.

**Gate behaviour:** Hard-fail on CRITICAL/HIGH findings.

```bash
# Run locally
checkov -d infra/terraform --compact
trivy config infra/kubernetes --severity CRITICAL,HIGH
```

### Stage 5 — Security Gate

Aggregates all scanner results, enforces the differentiated gate policy, and posts an ownership-tagged PR comment separating DevSecOps-owned findings (blocking) from AppSec-owned findings (non-blocking).

See [docs/security-gate-policy.md](docs/security-gate-policy.md) for the full gate policy.

### Stage 7 — OWASP ZAP DAST

Baseline web application scan against the staging deployment. Findings are routed to the AppSec team and do not block the pipeline.

---

## Security Remediations

### Secrets Management — HashiCorp Vault

All credentials have been removed from the codebase and migrated to HashiCorp Vault with the Kubernetes auth method and Agent Injector pattern.

```bash
# Deploy Vault
helm install vault hashicorp/vault \
  --namespace vault \
  --set server.dev.enabled=true \
  --set injector.enabled=true

# Verify secrets are mounted as files, not env vars
kubectl exec -n secureflow deployment/auth-service -c auth-service -- \
  cat /vault/secrets/config

# Confirm no plaintext credentials in environment
kubectl exec -n secureflow deployment/auth-service -c auth-service -- \
  env | grep -i "password\|secret\|jwt"
# Should return nothing
```

**Per-service Vault policies (least privilege):**

| Service | Vault Path | Access |
|---|---|---|
| auth-service | `secureflow/data/auth-service` | read only |
| transaction-service | `secureflow/data/transaction-service` | read only |
| frontend | `secureflow/data/frontend` | read only |

### Container Hardening

| Change | Before | After |
|---|---|---|
| Base image | `python:3.9-slim` | `python:3.12-slim` |
| CRITICAL CVEs | 6 per image | 0 per image |
| Container user | root (uid 0) | app (uid 1000) |
| Privilege escalation | enabled | disabled |
| Read-only root filesystem | no | yes |
| Resource limits | none | CPU + memory limits set |

### Kubernetes Hardening

All manifests updated with:

```yaml
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### Terraform IaC Hardening

| Finding | Before | After |
|---|---|---|
| IAM Policy | AdministratorAccess | AmazonEKSWorkerNodePolicy + CNI + ECR Read |
| S3 Encryption | None | AES256 server-side encryption |
| S3 Public Access | Enabled | All four blocks set to true |
| EKS Endpoint | Public (0.0.0.0/0) | Private only |
| EKS Subnets | Public | Private with NAT gateway |
| RDS Storage | Unencrypted | Encrypted |
| RDS Access | Publicly accessible | Private only |

---

## Runtime Security — Falco

Falco is deployed as a DaemonSet with four custom rules targeting the `secureflow` namespace.

```bash
# Deploy Falco with custom rules
helm install falco falcosecurity/falco \
  --namespace falco \
  --set driver.kind=modern_ebpf \
  -f infra/kubernetes/falco/secureflow-rules.yaml

# View alerts
kubectl logs -n falco -l app.kubernetes.io/name=falco | grep "secureflow"
```

### Custom Rules

| Rule | Trigger | Priority |
|---|---|---|
| Shell Spawned in SecureFlow Container | Any shell process spawned in namespace | CRITICAL |
| Sensitive File Read in SecureFlow | Read of /etc/shadow, /etc/passwd, SSH keys | CRITICAL |
| Unexpected Outbound Connection | Connection to non-whitelisted port | CRITICAL |
| Package Manager Executed in SecureFlow | apt-get, dpkg, pip in running container | CRITICAL |

### Confirmed Alerts

All four rule types were triggered and confirmed during testing:

```
08:16:24 Critical: Shell spawned in SecureFlow container (auth-service)
08:16:34 Critical: Sensitive file read in SecureFlow container (/etc/passwd)
08:18:56 Critical: Package manager executed in SecureFlow container (apt-get)
```

---

## Observability

### Grafana Security Dashboard

```bash
# Deploy Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=secureflow123

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80
# Open http://localhost:3001 (admin / secureflow123)
```

**Dashboard panels:**
1. Falco Security Alerts
2. SecureFlow Pod Status
3. Pipeline Security Status (all 7 stages)
4. Container CVE Remediation (before/after)
5. Vault Secrets Migration Status

---

## Before vs After — Key Metrics

| Metric | Before | After |
|---|---|---|
| Critical CVEs per image | 47 | **0** |
| Committed secrets | 11 | **0** |
| Pipeline stages | 0 | **7 (all green)** |
| Policy-compliant deployments | 0% | **100%** |
| Detection time | Days (manual) | **Minutes (automated)** |
| Falco runtime rules | 0 | **4 (all confirmed)** |
| IaC critical misconfigs | 50 | **0** |
| Grafana security panels | 0 | **5** |

---

## Vulnerability Index

The following intentional vulnerabilities are present in the baseline. AppSec-owned findings are **detected and routed** by the pipeline but **not remediated** in this engagement.

### AppSec-Owned (Detect & Route)

| ID | Type | Description |
|---|---|---|
| AV-01 | SQL Injection | Login endpoint builds query via string concatenation |
| AV-02 | SQL Injection | Registration endpoint same pattern |
| AV-03 | Broken Auth | JWT signed with hardcoded secret `super-secret-key-123` |
| AV-05 | Insecure Storage | Passwords stored with MD5, no salt |
| TV-01 | IDOR | Balance endpoint returns any account without ownership check |
| TV-03 | Business Logic | Negative transfer amounts accepted |
| FV-01 | Reflected XSS | User input rendered unescaped into HTML |
| FV-03 | Session Hijacking | `SESSION_SECRET=changeme` committed |

### DevSecOps-Owned (Detect & Remediate)

| ID | Type | Status |
|---|---|---|
| IV-04 | Committed Secrets | ✅ Removed + Vault migration |
| IV-08 | Overpermissive IAM | ✅ Scoped to least-privilege |
| IV-09 | Unencrypted S3 | ✅ AES256 enabled |
| IV-10 | Public EKS Subnets | ✅ Private subnets + NAT |
| CK-01 | Vulnerable Base Image | ✅ python:3.12-slim |
| CK-02 | Root Containers | ✅ USER app (uid 1000) |
| CK-04 | Privileged Containers | ✅ privileged: false |
| CK-05 | No Resource Limits | ✅ CPU + memory limits set |
| CK-08 | No NetworkPolicy | ✅ Default-deny implemented |
| CK-09 | Secrets in ConfigMaps | ✅ Migrated to Vault |

---

## Repository Structure

```
Amdari-Project02/
├── .github/
│   └── workflows/
│       └── devsecops-pipeline.yml    # 7-stage pipeline
├── .gitleaks.toml                     # Custom secret scanning rules
├── docs/
│   └── security-gate-policy.md       # Gate policy document
├── infra/
│   ├── kubernetes/
│   │   ├── base/                     # Hardened base manifests
│   │   ├── falco/                    # Custom Falco rules
│   │   └── overlays/dev/             # Vault-annotated deployments
│   └── terraform/
│       └── modules/                  # Hardened IaC modules
│           ├── eks/                  # Private subnets, logging, encryption
│           ├── iam/                  # Least-privilege policies
│           ├── rds/                  # Encrypted, private RDS
│           ├── s3/                   # Encrypted, private S3
│           └── vpc/                  # Network segmentation
├── pipeline/
│   └── scripts/
│       └── security-gate.sh          # Gate aggregation script
├── services/
│   ├── auth-service/                 # Python Flask authentication
│   ├── frontend/                     # Python Flask web UI
│   └── transaction-service/          # Python Flask transactions
└── sonar-project.properties          # SonarCloud configuration
```

---

## Gate Policy Summary

The pipeline enforces a **differentiated gate policy** that separates findings by ownership:

| Scanner | Owner | Gate |
|---|---|---|
| Gitleaks | DevSecOps | Hard-fail on ANY finding |
| Trivy Images | DevSecOps | Hard-fail on CRITICAL |
| Checkov | DevSecOps | Hard-fail on HIGH/CRITICAL |
| Trivy K8s | DevSecOps | Hard-fail on CRITICAL/HIGH |
| SonarQube | AppSec | Soft-fail — routes to AppSec |
| OWASP ZAP | AppSec | Soft-fail — routes to AppSec |

Full policy: [docs/security-gate-policy.md](docs/security-gate-policy.md)

---

## Technology Stack

| Tool | Category | Role |
|---|---|---|
| GitHub Actions | CI/CD | 7-stage pipeline orchestration |
| Gitleaks | Secrets | Full history secret scanning |
| SonarQube | SAST | Python code analysis |
| Trivy | CVE + IaC | Image and manifest scanning |
| Checkov | IaC | Terraform misconfiguration scanning |
| OWASP ZAP | DAST | Web application scanning |
| HashiCorp Vault | Secrets | Kubernetes auth + Agent Injector |
| OPA Gatekeeper | Policy | Kubernetes admission control |
| Falco | Runtime | eBPF kernel-level threat detection |
| Prometheus | Metrics | Security metrics collection |
| Grafana | Dashboard | Security posture visualisation |
| kind | Kubernetes | Local cluster for development |

---

## Engineer

**Femi Oluwafaj**
DevSecOps Engineer — Amdari Cohort 5
May 2026

---

> *"Security is not a product you buy — it is a pipeline you build and a set of ownership boundaries you maintain."*
