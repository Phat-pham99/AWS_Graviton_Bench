# Lesson 1 — Variables & Outputs

**Goal:** run your very first `init` / `plan` and understand variables + outputs.

No cloud needed — we only compute values in memory using `locals`.

## Files

- `main.tf` — defines **outputs** computed from **locals**
- `variables.tf` — defines two **variables** (with defaults)

## Commands

```bash
tofu init              # (or `terraform init`)
tofu plan              # see the computed values; nothing is created
tofu apply -auto-approve
tofu output            # read the outputs
tofu destroy -auto-approve
```

## Things to try

1. Override a variable on the CLI (no file edit):
   ```bash
   tofu apply -auto-approve -var environment=production
   ```
2. Override via a `.tfvars` file — copy `terraform.tfvars.example` to
   `terraform.tfvars`, edit it, then run `tofu plan`. Notice it is loaded
   automatically.
3. Inspect a single output: `tofu output service_name`.
4. Use `tofu console` to evaluate expressions interactively:
   ```
   tofu console
   > local.full_name
   > var.environment
   > "5*4 = ${5*4}"
   exit
   ```

## Concepts

- **`variable`** = an input knob. Has `type`, `default`, `description`.
  - No `default` → Terraform will **prompt** you (or you must pass `-var`).
- **`local`** = a computed value, no external input. `locals { name = ... }`.
- **`output`** = a value surfaced after apply. Visible in `tofu output`.
- **Interpolation** — `"${...}"` inside strings.
- **`-var` flag** — highest-precedence, one-off override.
- **`.tfvars` file** — bulk override, auto-loads when named `terraform.tfvars`.
- **`tofu console`** — REPL to test expressions.

## Precedence (lowest → highest)

```
default in variable block
  <  terraform.tfvars / *.auto.tfvars
  <  environment var TF_VAR_environment
  <  -var flag
```
