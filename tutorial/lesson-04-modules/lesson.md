# Lesson 4 — Modules

**Goal:** refactor repeated code into a reusable **module**, and pass data
between root and module.

In the real repo, `bench_instance/` is a module used 3× (control, test, loadgen).
We'll mimic that with a `sut_instance/` module used twice.

## Structure

```
lesson-04-modules/
├── main.tf          # root: calls the module twice
├── variables.tf
├── outputs.tf
└── modules/
    └── sut_instance/
        ├── variables.tf   # module inputs (group, instance_type, count)
        └── main.tf        # the reusable resource logic
```

## Commands

```bash
tofu init
tofu plan
tofu apply -auto-approve
tofu output
tofu destroy -auto-approve
```

## Concepts

- **`module "name" { source = "./modules/..." ... }`** — instantiates a module.
- **Inputs** — the module's `variables.tf` is its API; pass values in the
  `module` block.
- **Outputs** — a module returns values; the root references them with
  `module.NAME.OUTPUT`.
- **DRY** — same code, different arguments → reused (exactly like control/test
  in the real setup).
- **`source`** can be a local path (`./...`), a git URL, or the Terraform
  Registry (like `hashicorp/aws`).
- **`for_each` / `count`** — loop to create N instances of a resource (we use a
  simple map loop in the module).

## Compare with the real repo

```
terraform/modules/bench_instance/   ← identical idea
  ├── module.tf                     (inputs: group, arch, instance_type, ami…)
  └── user_data.sh.tftpl
```

The root `main.tf` then calls `module "control"`, `module "test"`,
`module "loadgen"` — three calls, one definition. You already understand the
pattern!
