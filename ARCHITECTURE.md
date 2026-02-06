# Architecture Diagrams

## Basic Architecture (IAM Mode)

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                  VPC (10.0.0.0/16)                   │   │
│  │                                                      │   │
│  │  ┌──────────────────┐    ┌──────────────────┐      │   │
│  │  │   Subnet 1       │    │   Subnet 2       │      │   │
│  │  │  (10.0.1.0/24)   │    │  (10.0.2.0/24)   │      │   │
│  │  │   AZ: us-east-1a │    │   AZ: us-east-1b │      │   │
│  │  │                  │    │                  │      │   │
│  │  │  ┌────────────┐  │    │  ┌────────────┐  │      │   │
│  │  │  │ SageMaker  │  │    │  │ SageMaker  │  │      │   │
│  │  │  │  Studio    │  │    │  │  Studio    │  │      │   │
│  │  │  │ (IAM Auth) │  │    │  │ Resources  │  │      │   │
│  │  │  └────────────┘  │    │  └────────────┘  │      │   │
│  │  └──────────────────┘    └──────────────────┘      │   │
│  │           │                       │                 │   │
│  │           └───────────┬───────────┘                 │   │
│  │                       │                             │   │
│  │            ┌──────────▼──────────┐                  │   │
│  │            │  Internet Gateway   │                  │   │
│  │            └──────────┬──────────┘                  │   │
│  └───────────────────────┼──────────────────────────────┘   │
│                          │                                  │
│  ┌───────────────────────▼──────────────────┐               │
│  │        S3 Bucket (Artifacts)             │               │
│  │  sleetgale-sagemaker-{account-id}        │               │
│  └──────────────────────────────────────────┘               │
│                                                              │
│  ┌──────────────────────────────────────────┐               │
│  │     IAM Role: Execution Role             │               │
│  │  - AmazonSageMakerFullAccess             │               │
│  │  - S3 Access Policy                      │               │
│  └──────────────────────────────────────────┘               │
└──────────────────────────────────────────────────────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │   AWS User  │
                    │  (IAM Auth) │
                    └─────────────┘
```

## Custom Domain Architecture (with SSL)

```
                    ┌──────────────┐
                    │   Internet   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  Route 53    │
                    │  DNS Zone    │
                    │              │
                    │  A Record:   │
                    │  sagemaker.  │
                    │  savantpraxis│
                    │      .com    │
                    └──────┬───────┘
                           │
┌─────────────────────────▼────────────────────────────────────┐
│                      AWS Cloud                                │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │            Application Load Balancer                   │  │
│  │                                                        │  │
│  │  ┌────────────────┐         ┌────────────────┐        │  │
│  │  │ HTTP Listener  │         │ HTTPS Listener │        │  │
│  │  │   Port 80      │         │   Port 443     │        │  │
│  │  │                │         │                │        │  │
│  │  │ (Redirect to   ├────────►│  SSL Cert      │        │  │
│  │  │  HTTPS)        │         │  (ACM)         │        │  │
│  │  └────────────────┘         └────────┬───────┘        │  │
│  └─────────────────────────────────────┼────────────────┘  │
│                                         │                   │
│  ┌──────────────────────────────────────┼─────────────────┐ │
│  │                VPC                   │                 │ │
│  │                                      │                 │ │
│  │  ┌─────────────────┐    ┌───────────▼───────────┐     │ │
│  │  │   Subnet 1      │    │     Subnet 2          │     │ │
│  │  │                 │    │                       │     │ │
│  │  │  ┌───────────┐  │    │  ┌─────────────────┐  │     │ │
│  │  │  │ SageMaker │  │    │  │  SageMaker      │  │     │ │
│  │  │  │  Studio   │  │    │  │  Studio         │  │     │ │
│  │  │  └───────────┘  │    │  └─────────────────┘  │     │ │
│  │  └─────────────────┘    └───────────────────────┘     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │   ACM Certificate                                      │ │
│  │   - Domain: sagemaker.savantpraxis.com                 │ │
│  │   - Validation: DNS (automatic)                        │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

## SSO Architecture (with Okta)

```
                    ┌──────────────┐
                    │     User     │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │     Okta     │
                    │              │
                    │ SAML 2.0 IdP │
                    └──────┬───────┘
                           │ SAML Assertion
                           │
┌──────────────────────────▼───────────────────────────────────┐
│                      AWS Cloud                                │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │         AWS IAM Identity Center                        │  │
│  │         (AWS SSO)                                      │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │  External Identity Provider (Okta)               │ │  │
│  │  │  - SAML Configuration                            │ │  │
│  │  │  - Attribute Mapping                             │ │  │
│  │  └──────────────────┬───────────────────────────────┘ │  │
│  │                     │                                 │  │
│  │  ┌──────────────────▼───────────────────────────────┐ │  │
│  │  │  Permission Sets (created by Terraform)          │ │  │
│  │  │                                                   │ │  │
│  │  │  ┌───────────────────┐  ┌──────────────────────┐ │ │  │
│  │  │  │ SageMaker Admin   │  │ SageMaker User       │ │ │  │
│  │  │  │ - FullAccess      │  │ - Limited Access     │ │ │  │
│  │  │  └───────────────────┘  └──────────────────────┘ │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  └────────────────────┬───────────────────────────────────┘  │
│                       │                                       │
│  ┌────────────────────▼───────────────────────────────────┐  │
│  │         SageMaker Studio Domain (SSO Mode)             │  │
│  │                                                        │  │
│  │  User Profiles (Auto-created on first login):         │  │
│  │  - john.doe@savantpraxis.com                           │  │
│  │  - jane.smith@savantpraxis.com                         │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘  │
│                       │                                       │
│  ┌────────────────────▼───────────────────────────────────┐  │
│  │         VPC with SageMaker Resources                   │  │
│  └────────────────────────────────────────────────────────┘  │
│                       │                                       │
│  ┌────────────────────▼───────────────────────────────────┐  │
│  │  IAM Role: SSO Execution Role                          │  │
│  │  - Assumed by SageMaker                                │  │
│  │  - Assumed by SAML Provider (Okta)                     │  │
│  │  - SageMaker Permissions + S3 Access                   │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘

Okta Groups:
┌─────────────────────┐         ┌─────────────────────┐
│  SageMakerAdmins    │         │  SageMakerUsers     │
│                     │         │                     │
│  Members:           │         │  Members:           │
│  - admin1@corp.com  │         │  - user1@corp.com   │
│  - admin2@corp.com  │         │  - user2@corp.com   │
└─────────────────────┘         └─────────────────────┘
```

## Combined Architecture (Custom Domain + SSO)

```
                          ┌──────────────┐
                          │     User     │
                          └──────┬───────┘
                                 │
                          ┌──────▼───────┐
                          │     Okta     │
                          │  SAML IdP    │
                          └──────┬───────┘
                                 │ SAML
┌────────────────────────────────▼──────────────────────────────┐
│                         AWS Cloud                              │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │          AWS IAM Identity Center (SSO)                   │ │
│  │          - External IdP (Okta)                           │ │
│  │          - Permission Sets                               │ │
│  └──────────────────────┬───────────────────────────────────┘ │
│                         │                                      │
│  ┌──────────────────────▼───────────────────────────────────┐ │
│  │                  Route 53 DNS                            │ │
│  │          sagemaker.savantpraxis.com → ALB              │ │
│  └──────────────────────┬───────────────────────────────────┘ │
│                         │                                      │
│  ┌──────────────────────▼───────────────────────────────────┐ │
│  │         Application Load Balancer                        │ │
│  │         - HTTPS (Port 443) with ACM Certificate          │ │
│  │         - HTTP (Port 80) → Redirect to HTTPS             │ │
│  └──────────────────────┬───────────────────────────────────┘ │
│                         │                                      │
│  ┌──────────────────────▼───────────────────────────────────┐ │
│  │                     VPC                                  │ │
│  │                                                          │ │
│  │  ┌────────────────────────────────────────────────────┐ │ │
│  │  │    SageMaker Studio Domain (SSO Mode)             │ │ │
│  │  │                                                    │ │ │
│  │  │    - User profiles auto-created                   │ │ │
│  │  │    - SSO execution role                           │ │ │
│  │  │    - Security groups                              │ │ │
│  │  └────────────────────────────────────────────────────┘ │ │
│  │                         │                                │ │
│  │  ┌──────────────────────▼──────────────────────────────┐ │ │
│  │  │         S3 Bucket (Artifacts)                       │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────── │
└────────────────────────────────────────────────────────────────┘

Features Combined:
✓ Custom domain with valid SSL certificate
✓ HTTPS enforcement (HTTP → HTTPS redirect)
✓ Okta SAML-based authentication
✓ Role-based access control via permission sets
✓ Auto-provisioned user profiles
✓ Enterprise-grade security
```

## Authentication Flow (SSO Mode)

```
┌─────────────┐
│    User     │
└──────┬──────┘
       │
       │ 1. Click AWS SageMaker Studio in Okta
       │
       ▼
┌──────────────┐
│    Okta      │
│              │
│ 2. Authenticate user (username/password/MFA)
│ 3. Generate SAML assertion
│ 4. Send assertion to AWS
└──────┬───────┘
       │
       │ SAML Assertion
       │
       ▼
┌──────────────────────┐
│  AWS IAM Identity    │
│  Center              │
│                      │
│ 5. Validate assertion│
│ 6. Map to permission │
│    set               │
│ 7. Grant access      │
└──────┬───────────────┘
       │
       │ 8. Redirect to AWS Console
       │
       ▼
┌──────────────────────┐
│  AWS Console         │
│                      │
│ 9. Navigate to       │
│    SageMaker         │
└──────┬───────────────┘
       │
       │ 10. Select domain
       │
       ▼
┌──────────────────────┐
│  SageMaker Domain    │
│                      │
│ 11. Create user      │
│     profile (first   │
│     time only)       │
│ 12. Launch Studio    │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  SageMaker Studio    │
│  Interface           │
│                      │
│ 13. User can work    │
│     with notebooks   │
└──────────────────────┘
```

## Security Flow (Custom Domain with SSL)

```
┌─────────────┐
│    User     │
└──────┬──────┘
       │
       │ 1. Navigate to http://sagemaker.savantpraxis.com
       │
       ▼
┌──────────────────────┐
│  Route 53            │
│                      │
│ 2. Resolve domain    │
│    to ALB IP         │
└──────┬───────────────┘
       │
       │ 3. HTTP request
       │
       ▼
┌──────────────────────┐
│  Application Load    │
│  Balancer            │
│                      │
│ 4. HTTP Listener     │
│    (Port 80)         │
│ 5. Redirect to HTTPS │
└──────┬───────────────┘
       │
       │ 6. 301 Redirect to https://sagemaker.savantpraxis.com
       │
       ▼
┌─────────────┐
│    User     │
└──────┬──────┘
       │
       │ 7. Navigate to https://sagemaker.savantpraxis.com
       │
       ▼
┌──────────────────────┐
│  Application Load    │
│  Balancer            │
│                      │
│ 8. HTTPS Listener    │
│    (Port 443)        │
│ 9. Present ACM cert  │
│ 10. Establish TLS    │
└──────┬───────────────┘
       │
       │ 11. Encrypted HTTPS traffic
       │
       ▼
┌──────────────────────┐
│  SageMaker Studio    │
│                      │
│ 12. Serve content    │
│     over HTTPS       │
└──────────────────────┘
```

## Resource Dependencies

```
main.tf (Provider)
    │
    ├─→ variables.tf (Input Variables)
    │
    ├─→ network.tf
    │       │
    │       ├─→ VPC
    │       ├─→ Subnets (2 AZs)
    │       ├─→ Internet Gateway
    │       ├─→ Route Tables
    │       └─→ Security Groups
    │
    ├─→ iam.tf (IAM Mode)
    │       │
    │       ├─→ SageMaker Execution Role
    │       ├─→ S3 Policy
    │       └─→ S3 Bucket
    │
    ├─→ sso.tf (SSO Mode - if enable_sso = true)
    │       │
    │       ├─→ SSO Permission Sets
    │       ├─→ SSO Execution Role
    │       └─→ SSO IAM Policies
    │
    ├─→ ssl.tf (Custom Domain - if enable_custom_domain = true)
    │       │
    │       ├─→ Route 53 Zone (optional)
    │       ├─→ ACM Certificate
    │       ├─→ Certificate Validation
    │       ├─→ Application Load Balancer
    │       ├─→ ALB Security Group
    │       ├─→ Target Group
    │       ├─→ HTTPS Listener
    │       ├─→ HTTP Listener (redirect)
    │       └─→ DNS A Record
    │
    ├─→ sagemaker.tf
    │       │
    │       ├─→ SageMaker Domain
    │       │   (auth_mode: IAM or SSO based on enable_sso)
    │       │   (execution_role: IAM or SSO based on enable_sso)
    │       │
    │       └─→ User Profile (only if IAM mode)
    │
    └─→ outputs.tf (Outputs)
            │
            ├─→ Domain outputs
            ├─→ SSL outputs (if enabled)
            └─→ SSO outputs (if enabled)
```

## Cost Breakdown by Component

```
Component                    Monthly Cost    Usage Cost
─────────────────────────────────────────────────────────
VPC & Networking              $0              $0
Internet Gateway              $0              Data transfer
Subnets                       $0              $0
Security Groups               $0              $0
─────────────────────────────────────────────────────────
IAM Roles                     $0              $0
S3 Bucket                     $0              Storage + requests
SageMaker Domain              $0              $0
─────────────────────────────────────────────────────────
Optional: Custom Domain
  Route 53 Zone              ~$0.50          Query charges
  ACM Certificate             $0              $0
  Application Load Balancer  ~$16-20         Data processing
─────────────────────────────────────────────────────────
Optional: SSO
  IAM Identity Center         $0              $0
  Permission Sets             $0              $0
─────────────────────────────────────────────────────────
Usage Costs (when apps running)
  JupyterServer (system)      $0/hour         $0
  ml.t3.medium               ~$0.05/hour      Variable
─────────────────────────────────────────────────────────
Total Base Cost:
  IAM Mode                    ~$0/month       + usage
  + Custom Domain            ~$16-20/month    + usage
  + SSO                       $0              + usage
  + Both                     ~$16-20/month    + usage
```
