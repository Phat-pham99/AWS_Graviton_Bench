# Lesson 2 — Resources & Providers

**Goal:** create your first *real* resource using the **`random`** provider, and
understand the resource lifecycle.

A "resource" is something Terraform manages for real. The `random` provider
generates random-looking values (useful for unique names, IDs, passwords).
This is a real resource with real state — but costs nothing.

## Files

- `main.tf` — declares a `required_providers` block + one `random_pet` resource
- `variables.tf` — optional input (`pet_length`, `prefix`)

## Commands

```bash
tofu init      # downloads the `random` provider plugin
tofu plan      # preview: "+" will create a random_pet
tofu apply -auto-approve
tofu output    # see the generated pet name & password
tofu destroy   # removes the resource
```

## Things to try

1. Run `tofu apply` **again** (same values). Notice:
   ```
   No changes. Your infrastructure matches the configuration.
   ```
   That's the "idempotent" nature of state: it remembers the existing value.
2. Change `prefix` (or pass `-var prefix=prod`). Run `tofu plan`. Most of the
   time a new value means "re-create" (the random provider can't update).

## Concepts

- **`terraform { required_providers { ... } }`** — pins which providers + versions.
- **`provider "..." { }`** — configures a provider (in this case, none needed).
- **Resource addressing** — every resource is `type.name`, e.g. `random_pet.sut`.
- **Attributes** — each resource exposes read-only attributes like `.id`.
- **Plan symbols**:
  - `+` create, `-` destroy, `~` update in-place, `-/+` destroy then create.

## The random_pet resource

```hcl
resource "random_pet" "sut" {
  prefix    = "sut-"
  length    = 2
  separator = "-"
}
```

Produces something like `sut-supreme-gibbon`. Attributes: `.id` (the string).
We use it here as a stand-in for any "thing with a generated name".
