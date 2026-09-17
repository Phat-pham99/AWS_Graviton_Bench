# Lesson 6 — AWS Prep: Wiring It Back to the Real Repo

**Goal:** connect everything you learned to the actual `terraform/` setup, and
get the AWS **token/credentials** question fully answered.

No `tofu apply` here (that would cost money). This is a read-and-understand
lesson + a safe "offline" demonstration of how inputs flow.

---

## 6.1 How the real repo is structured

```
terraform/
├── main.tf          # provider + locals + wires 4 modules together
├── variables.tf     # the "knobs" (see TERRAFORM_REPORT.md table)
├── outputs.tf       # IPs + Grafana URL
└── modules/
    ├── network/         # VPC, subnets, NAT, IGW, security groups
    ├── bench_instance/  # one EC2 instance (used for control/test/loadgen)
    └── dashboard/       # Prometheus + Grafana host
```

The `provider "aws"` block in `main.tf:23` only sets `region`. **There is no
`access_key`/`secret_key`/`token` argument** — intentionally. Terraform reads
credentials from the standard AWS chain instead.

## 6.2 The AWS credential chain (where your token goes)

Terraform's AWS provider looks for credentials in this order:

| # | Source                       | How to set it                                            |
|---|------------------------------|----------------------------------------------------------|
| 1 | Static provider config       | `provider "aws" { access_key = ... }` — **avoid** (leaks)|
| 2 | Environment variables        | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` |
| 3 | Shared credentials file      | `~/.aws/credentials`                                     |
| 4 | IAM role (EC2/ECS/EKS)       | automatic when running *on* AWS                          |
| 5 | SSO / OIDC                   | `aws sso login` (`.aws/config`)                          |

**Your token** (session token, e.g. from `aws sts assume-role` or SSO) is
`AWS_SESSION_TOKEN`, and it belongs in **`~/.aws/credentials`** or the
**environment variables** — *never* in a `.tf` or `.tfvars` file that gets
committed.

### The two recommended ways

**Option A — `~/.aws/credentials` (persistent):**
```bash
mkdir -p ~/.aws
```

`~/.aws/credentials`:
```ini
[default]
aws_access_key_id     = AKIAXXXXXXXX
aws_secret_access_key = yyyyyyyyyyyy
aws_session_token     = zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz  # your TOKEN
region                = us-east-1
```

**Option B — environment variables (per-shell, good for CI):**
```bash
export AWS_ACCESS_KEY_ID="AKIAXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="yyyyyyyyyyyy"
export AWS_SESSION_TOKEN="zzzzzzzz..."     # the token
export AWS_REGION="us-east-1"
```

Any of these flows into `provider "aws" { region = var.region }` automatically.
Verify with: `aws sts get-caller-identity` (before running Terraform).

## 6.3 The S3 backend (the *other* thing you need)

`main.tf:20` has:
```hcl
backend "s3" {}
```
It's deliberately empty. Terraform needs backend settings to know *where* to
store state. You supply them a `backend.hcl` file that you **do not commit**:

`terraform/backend.hcl` (or pass via `-backend-config` flags):
```hcl
bucket         = "your-state-bucket"
key            = "graviton-bench/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-locks"   # optional but recommended
```

Then initialize with:
```bash
cd terraform
tofu init -backend-config=backend.hcl
```

## 6.4 Required inputs

From `variables.tf`, these have **no default** — Terraform will prompt you:

- `ssh_key_name`      — an existing EC2 key pair name
- `x86_ami`           — Ubuntu 24.04 x86_64 AMI id (region-specific)
- `arm_ami`           — Ubuntu 24.04 arm64 AMI id
- `grafana_admin_password` — a secret (marked `sensitive = true`)

Supply them safely (never commit the password):
```bash
export TF_VAR_grafana_admin_password='your-secret'   # env var, not in git
tofu plan -var ssh_key_name=my-key -var x86_ami=ami-... -var arm_ami=ami-...
```

## 6.5 A safe offline demo of input flow

The `demo/` subfolder here models the repo's input pattern using only `local`
and `random` — no AWS, no cost. Run it to see how `variables.tf` + a
`terraform.tfvars` + a `sensitive` output behave:

```bash
cd demo
tofu init
tofu plan
tofu apply -auto-approve
tofu output            # note the password is marked <sensitive>
```

## 6.6 Security checklist (before you ever `tofu apply` the real repo)

- [ ] Credentials in `~/.aws/credentials` or env vars — **not** in git.
- [ ] `backend.hcl` (with bucket/key) is git-ignored.
- [ ] `terraform.tfvars` (with AMIs/password) is git-ignored.
- [ ] `ssh_cidr` tightened from `0.0.0.0/0` (see the security-group note in
      `TERRAFORM_REPORT.md` § modules/network).
- [ ] `grafana_admin_password` passed via `TF_VAR_` env var, not typed in a file.

---

## Recap — the direct answer to "where does the AWS token go?"

Put the **session token** as `aws_session_token` in `~/.aws/credentials`
(alongside `aws_access_key_id` and `aws_secret_access_key`), **or** as the
environment variable `AWS_SESSION_TOKEN`. The Terraform code itself has no token
variable — it picks credentials up from that standard chain automatically.
