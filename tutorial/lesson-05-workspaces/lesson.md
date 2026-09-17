# Lesson 5 — Workspaces

**Goal:** isolate state between "control" and "test" deployments without
duplicating files.

Workspaces are named copies of your state. You write **one** config, and
`tofu workspace` lets you apply it separately per environment/group.

## Commands

```bash
tofu init
tofu workspace list          # default only, to start
tofu workspace new control   # create + switch to "control"
tofu apply -auto-approve     # applies into the "control" state only
tofu workspace new test
tofu apply -auto-approve     # separate, isolated state for "test"
tofu workspace list          # shows: default, control, test (+ current *)
tofu output group_name
```

## Things to try

1. Inspect `terraform.tfstate.d/` — note the per-workspace folders.
2. `tofu workspace select default` then `tofu plan` — notice it's a *different*
   (empty) state. That's the isolation.
3. Switch back: `tofu workspace select control`.

## Concepts

- **Workspace** = an isolated copy of state for the *same* config.
- Use `terraform.workspace` to read the current name — great for the group label:
  ```hcl
  locals {
    group_name = terraform.workspace
  }
  ```
- **When to use workspaces vs a variable?**
  - Workspaces: same code, fully separate instances (dev/prod, per-group labs).
  - Variables: same deployment, just different params.
- The real benchmark hardcodes `control` / `test` as *modules* (cleaner for a
  fixed 2-group experiment), but workspaces are the tool for "run this whole lab
  again under a new name".

## Watch out

Workspaces can get confusing because state is scattered. For a fixed experiment
like this repo, modules (Lesson 4) are usually the better fit. Know both —
you'll see workspaces referenced in the wild constantly.
