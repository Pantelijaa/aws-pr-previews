# aws-pr-previews

[![ci](https://github.com/Pantelijaa/aws-pr-previews/actions/workflows/ci.yml/badge.svg)](https://github.com/Pantelijaa/aws-pr-previews/actions/workflows/ci.yml)

Per-pull-request preview environments on AWS: a GitHub Action plus a Terraform module that gives every PR a live HTTPS URL running its container image in your own AWS account, at zero cost while idle, and removes it when the PR closes.

**Status:** under construction. Nothing here works yet.

Built as a learning project: its maintainer is learning AWS, Docker, TypeScript tooling and CI/CD by building it, one concept at a time. The design lives in [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md) and the build order in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
