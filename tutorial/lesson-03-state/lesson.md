# Lesson 3 — State

**Goal:** understand the state file — what it is, what's in it, and the commands
that poke at it.

Run lesson 2 first (`tofu apply`) so there is state to inspect. Then:

## Commands

```bash
tofu show                    # human-readable summary of state
tofu show -json | head -40   # the raw JSON structure
ls -la                       # see terraform.tfstate & terraform.tfstate.backup
tofu refresh                 # reconcile state with reality
tofu state list              # list resource addresses in state
tofu state show random_pet.sut
tofu plan -out=saved.plan    # write a plan to a file
tofu apply saved.plan        # apply that exact plan later
```

## Concepts

- **`terraform.tfstate`** — the canonical JSON record of everything Terraform
  manages. Do **not** edit by hand.
- **State maps** your config to real-world objects via resource **addresses**.
- **Remote state** — for a team (or CI), state lives in S3/Consul/etc. The real
  repo uses `backend "s3" {}` for exactly this (see `main.tf:20` in
  `terraform/`).
- **Locking** — prevents two people applying at once. S3 backend uses a
  DynamoDB table for this.
- **`.terraform.lock.hcl`** — records provider versions so everyone applies with
  identical plugins.

## Why state matters for this repo

The real `main.tf` has:
```hcl
backend "s3" {}
```

That means state is *not* stored locally — it's in S3. Moving state to a remote
backend is a topic for later, but now you know what it's for: **shared,
versioned, locked** knowledge of what's deployed.

## Warning

Never commit `terraform.tfstate` to git if it contains secrets. The repo's
`.gitignore` doesn't cover it yet — but remote backends (S3) avoid the problem
entirely.
