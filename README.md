# AWS Security Infrastructure via Terraform

<p align="left">
  <a href="#-project-overview">English</a> •
  <a href="#-visão-geral-do-projeto">Português</a>
</p>

---

## 📌 Project Overview
This repository contains a production-ready, highly secure, and isolated network topology built on AWS using Terraform. The architecture enforces strict network layering, perimeter security mitigation, and segregation of duties following AWS Well-Architected Framework best practices.

## 🏗️ Architecture Design
The infrastructure is deployed entirely as code, featuring:
* **Production VPC** (`10.0.0.0/16`) with full DNS support enabled.
* **Public/DMZ Subnet (`10.0.1.0/24`)**: Configured in `us-east-1a` to host public-facing infrastructure components with an attached Internet Gateway.
* **Private/Application Subnet (`10.0.10.0/24`)**: Completely isolated infrastructure tier. No direct routing to the Internet Gateway to guarantee zero external exposure for sensitive database or application workloads.
* **Perimeter Hardening Layer**: Stateful AWS Security Groups enforcing strict ingress/egress rules (allowing internal `HTTPS/443` traffic strictly bound to the VPC CIDR block).

## 🛠️ Tech Stack & Standards
* **Infrastructure as Code:** Terraform `>= 1.5.0`
* **Cloud Provider:** AWS (Provider version `~> 5.0`)
* **Branching Strategy:** Git-flow with protected branch rulesets (`main` branch restriction enforcement).
* **Commit Standard:** Conventional/Semantic Commits.

## 🚀 How to Deploy
1. **Initialize the workspace and download providers:**
   ```bash
   terraform init
