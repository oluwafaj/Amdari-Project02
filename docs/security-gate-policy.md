# Security Gate Policy

## Overview
This document defines the differentiated gate policy for the SecureFlow
DevSecOps pipeline. It governs which findings block merges and which
are routed to the appropriate team.

## Ownership Matrix

| Scanner | Owner | Gate Behaviour |
|---------|-------|----------------|
| Gitleaks | DevSecOps | Hard-fail on ANY finding |
| Trivy Image | DevSecOps | Hard-fail on CRITICAL/HIGH |
| Checkov | DevSecOps | Hard-fail on CRITICAL/HIGH |
| Trivy K8s | DevSecOps | Hard-fail on CRITICAL/HIGH |
| SonarQube | AppSec | Soft-fail — route to AppSec |
| OWASP ZAP | AppSec | Soft-fail — route to AppSec |

## Hard-Fail Rules
The pipeline blocks merges when ANY of the following occur:
- Gitleaks finds any committed secret
- Trivy finds CRITICAL or HIGH CVEs in any service image
- Checkov finds CRITICAL or HIGH IaC misconfigurations
- Trivy finds CRITICAL or HIGH Kubernetes misconfigurations

## Soft-Fail Rules
The pipeline posts a PR comment but does NOT block merges when:
- SonarQube finds any severity finding (routed to AppSec)
- OWASP ZAP finds any severity finding (routed to AppSec)

## Exception Process
To bypass a hard-fail finding:
1. Post a comment on the PR: /security-exception <reason>
2. A DevSecOps team member must approve the exception
3. The exception is logged in the audit trail
4. A remediation deadline must be set (maximum 30 days)

## AppSec Handoff
All SonarQube and ZAP findings are routed to the AppSec team via:
- PR comment under the "AppSec Findings" section
- Link to the AppSec intake ticket template
- Severity and file/line attribution included

## Rationale
This differentiated policy exists because:
- DevSecOps owns: secrets, CVEs, IaC, container security
- AppSec owns: SQL injection, XSS, IDOR, CSRF, auth flaws
- Mixing ownership creates alert fatigue and unclear accountability
- Hard-failing on AppSec findings would block all merges permanently
  since application vulnerabilities are not remediated in this engagement
