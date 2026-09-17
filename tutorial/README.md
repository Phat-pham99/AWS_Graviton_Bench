# Terraform Tutorial — A Hands-On Guide for this Repo

Welcome! This is a self-contained, **zero-AWS-cost** tutorial that teaches you
Terraform (core) before you touch the real `terraform/` infrastructure in this
repo.

> You can complete every lesson with only the **`random`** and **`local`**
> providers — no cloud account, no credentials, no billing. By the end you'll
> understand _variables, providers, resources, outputs, modules, state_ and
> _workspaces_ well enough to feel at home in the real Graviton benchmark IaC.

---

## 0. Before you start

You need one of these two CLIs (either works — they share the same HCL language
and command set):

| Tool      | Check version          | Notes                          |
|-----------|------------------------|--------------------------------|
| Terraform | `terraform version`    | HashiCorp official (installed) |
| OpenTofu  | `tofu version`         | Drop-in fork (found as a snap) |

**Terraform `v1.16.3` is installed** for you in `~/.local/bin` (matches the
repo's `required_version = ">= 1.5"`). Every `terraform` command below has an
identical `tofu` form, e.g. `tofu init`, `tofu plan`, `tofu apply`. Use
`terraform` to follow along; the commands are interchangeable.

> Verify it: `terraform version` → should print `Terraform v1.16.3`.

---

## 1. Mental model — what Terraform actually does

```
  your .tf files          ┌────────────────────┐        ┌──────────────────┐
 (desired state)  ───────▶│  terraform plan    │───────▶│  providers (AWS, │
                          │  (diff vs. real)   │        │  random, local…) │
                          └────────────────────┘        └────────┬─────────┘
                                                                 │
                    ┌───────────────┐                            │
                    │  state file   │◀─────── records what's ────┘
                    │ (.tfstate)    │        actually created
                    └───────────────┘
```

Terraform is **declarative, not imperative**. You write down _what should
exist_, and it figures out the _how_ (create/update/delete) to reach that state.
It keeps a **state file** to remember what it already built.

Key vocabulary you'll meet constantly:

- **Provider** — plugin that talks to a platform (`aws`, `random`, `local`).
- **Resource** — a single thing to manage (an EC2 instance, a generated string).
- **Data source** — read something that already exists (no create).
- **Variable** — an input knob (`type`, `default`, `description`).
- **Output** — a value returned after apply (like the Grafana URL).
- **Module** — a reusable bundle of resources.
- **State** — the JSON file recording what Terraform manages.
- **Workspace** — an isolated copy of state (dev vs prod, control vs test).

---

## 2. What's in this tutorial

```
tutorial/
├── lesson-01-variables/      # variables + outputs + terraform console
├── lesson-02-resources/      # real resources via the random provider
├── lesson-03-state/          # what the state file is + refresh
├── lesson-04-modules/        # refactor into a reusable module
├── lesson-05-workspaces/     # isolate "control" vs "test" groups
├── lesson-06-aws-prep/       # tie-back: how the real AWS setup works
└── lesson-07-count-foreach-conditionals/  # count, for_each, ?: conditionals
```

Each lesson is a folder you `cd` into and run commands. They build on each
other but are independent (you can jump around).

---

## 3. The lesson flow (quick version)

```bash
cd tutorial/lesson-01-variables
tofu init               # download providers, make .terraform/
tofu plan               # preview WITHOUT changing anything (safe!)
tofu apply -auto-approve  # actually create
tofu output             # read the outputs
tofu destroy            # clean up when done
```

That 5-command loop is **90% of Terraform**. Everything else is just fancier
versions of it.

---

## 4. Before running — your first Terraform secrets lesson

Never hardcode secrets. The real repo expects credentials via environment
variables and the AWS shared-credentials file, not inside `.tf` files:

```bash
# ~/.aws/credentials  (NOT committed to git)
[default]
aws_access_key_id     = AKIA...
aws_secret_access_key = ...
aws_session_token     = ...   # only for temporary tokens
```

For this tutorial nothing is secret, but **lesson 6** shows you exactly how to
pass an AWS token correctly.

---

## 5. Where to go next

1. Finish lessons 1–7 to learn core Terraform.
2. Read `lesson-06-aws-prep/lesson.md` to connect it to the real `terraform/`.
3. Then (and only then) read `TERRAFORM_REPORT.md` at the repo root — it will
   finally make sense.
