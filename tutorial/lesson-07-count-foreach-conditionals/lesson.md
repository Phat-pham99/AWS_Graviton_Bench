# Lesson 7 — `count`, `for_each`, and Conditionals

**Goal:** learn the two looping meta-arguments and how to conditionally toggle
resources — three features you'll see constantly in real Terraform.

## Files

- `main.tf` — demonstrates `count`, `for_each`, and `? :` conditional expressions
- `variables.tf` — a `list` and a `map`, plus a boolean toggle

## Commands

```bash
terraform init
terraform apply -auto-approve
terraform output
terraform destroy -auto-approve
```

## Concepts

### 1. `count` — create N copies (by integer)

```hcl
resource "random_pet" "many" {
  count  = var.pet_count
  prefix = "pet-${count.index}-"
}
```

- Managed as a **list**; each is `random_pet.many[0]`, `[1]`, …
- Changing `pet_count` from 3 → 2 destroys the *last* one (index-based, fragile).
- Use when order/position matters or you just need "a number of them".

### 2. `for_each` — create per-key copies (by map or set)

```hcl
resource "random_pet" "groups" {
  for_each = var.groups          # map e.g. { control = "c6i.xlarge", test = "c7g.xlarge" }
  prefix   = "${each.key}-"
}
```

- Managed as a **map**; address is `random_pet.groups["control"]`.
- Add/remove a key → only that key changes (stable, safe).
- `each.key`, `each.value` are available inside.
- Use when each item is a distinct named thing — like control vs test vs loadgen.

### 3. Conditional expressions — `condition ? true : false`

```hcl
locals {
  arch_label = var.use_arm ? "arm64" : "x86_64"
}
```

- If `use_arm` is `true` → `"arm64"`, else `"x86_64"`.
- Combine with `count` to *conditionally create* a whole resource:

```hcl
resource "random_pet" "only_if_enabled" {
  count = var.extra_pet_enabled ? 1 : 0     # 0 = "don't create'' in Terraform
}
```

## How this maps to the real repo

The real `terraform/main.tf` hardcodes three separate `module` blocks for
control/test/loadgen (clear, but repetitive). A `for_each` over a groups map
would express the same idea more concisely:

```hcl
module "sut" {
  for_each   = var.groups
  source     = "./modules/bench_instance"
  group      = each.key
  instance_type = each.value
  ...
}
```

Both approaches appear in the wild. Now you can read either.

## Things to try

1. Edit `variables.tf`: add `"loadgen" = "c6i.2xlarge"` to the `groups` map,
   then `terraform apply`. Notice only one new pet is created.
2. Flip `extra_pet_enabled` to `false`, apply, and watch the extra pet vanish.
3. Run `terraform console` and evaluate: `var.use_arm ? "arm64" : "x86_64"`.
