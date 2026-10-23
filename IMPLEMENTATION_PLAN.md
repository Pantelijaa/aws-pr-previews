# Implementation Plan

The build order for `aws-pr-previews`, arranged as a learning path. Requirements are in [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md); working rules are in [AGENTS.md](AGENTS.md).

## How to use this plan

- **One step per session, sometimes less.** Each step introduces one or two concepts and produces one small, verifiable deliverable. Steps are ordered so that no step relies on a concept you have not met.
- **Every step has the same shape:** Concepts → Build → Verify → Interview prep → Stop. The concept notes get written *before* the code. The stop is real: finish the step, ask questions, decide together whether to continue.
- **Checkboxes are the progress tracker.** Tick them as you go. The agent updates them at the end of each step.
- **Effort estimates** assume a learning pace with explanation time included. Total is roughly 28 hours, about nine or ten sessions of three hours.
- **Idle cost** is stated per step. In v1.0 it is zero at every step; the line exists so the habit of asking is there when the ECS backend arrives.

---

## Part A — Local foundations (nothing in AWS yet)

### Step 0 — Prerequisites and account safety  (~1 h, mostly waiting on sign-ups)

**Concepts:** `aws-account-and-iam-basics`, `aws-cost-safety`.

**Why now:** everything later needs an account that cannot surprise you with a bill.

**Build**
- [x] GitHub: create the empty public repository `aws-pr-previews` under `Pantelijaa`.
- [x] AWS: create an account. Enable MFA on the root user, then stop using root. Create a user in IAM Identity Center with the `AdministratorAccess` permission set and configure the CLI with `aws configure sso`.
- [x] AWS Budgets: a monthly budget of 5 USD with an email alert at 50 % and 100 %.
- [x] Service Quotas: check the Lambda "Concurrent executions" quota in your region. New accounts often start at 10. Request 100 now; approval takes a day or two and nothing in this plan needs it before Step 7.
- [x] Tools on Windows: Git, Docker Desktop with the WSL 2 backend, Node 22 LTS, Terraform ≥ 1.10, AWS CLI v2, `tflint`. Check each with `--version`.

**Verify**
- [x] `aws sts get-caller-identity` returns your Identity Center role, not root.
- [x] `docker run --rm hello-world` works. `node --version` prints 22 or newer.

**Interview prep:** root user versus IAM identities; why MFA on root; what a region and an availability zone are; what a service quota is and why new accounts have low ones.

---

### Step 1 — Repository bootstrap  (~1 h)

**Concepts:** `typescript-and-node-tooling`, `linting-formatting-typing`.

**Why now:** every later step adds code, and the quality gates have to exist before the first line, not after.

**Build**
- [x] `git init`, MIT `LICENSE`, `.gitignore` (node, Terraform, `.env`), `.editorconfig`.
- [x] `npm init`, `tsconfig.json` with `strict` and `noUncheckedIndexedAccess`, `biome.json`, `vitest` with one trivial test, an `esbuild` build script producing `dist/` from three entry points (empty placeholders for now).
- [x] `package.json` scripts: `check`, `test`, `build`. Exactly the dependencies in the spec's dependency budget.
- [x] `README.md` stub with the one-liner and a "built as a learning project" sentence. `CHANGELOG.md` with an `Unreleased` heading. `docs/concepts/` with its first notes.
- [x] Copy `PROJECT_SPECIFICATION.md`, `AGENTS.md`, `IMPLEMENTATION_PLAN.md` into the repo root.

**Verify**
- [x] `npm ci && npm run check && npm test && npm run build` all pass and `dist/` contains three files.

**Interview prep:** what a lockfile guarantees; what `tsc --noEmit` checks that a bundler does not; why bundle a GitHub Action into one file; what Biome is and how it differs from ESLint plus Prettier.

---

### Step 2 — The demo app and its Dockerfile  (~1.5 h)

**Concepts:** `containers-and-images`, `dockerfile-basics`, `lambda-web-adapter` (what the one line does; the Lambda side comes in Step 7).

**Why now:** the whole product deploys containers. You should have built and run one by hand before any cloud service does it for you.

**Build**
- [x] `examples/demo-app/server.ts`: a `node:http` server, about 25 lines. `/` returns an HTML page showing the `PR_PREVIEW_*` environment variables (or "not set") and the build time; `/healthz` returns 200. Port from `PORT`, default 8080, listening on `0.0.0.0`.
- [x] `examples/demo-app/Dockerfile`: `node:24-slim`, a non-root user, the Web Adapter `COPY` line, `EXPOSE 8080`, `CMD ["node", "server.ts"]`. Single stage; there is nothing to compile.

**Verify**
- [x] `docker build -t demo-app:dev examples/demo-app`, then `docker run --rm -p 8080:8080 -e PR_PREVIEW_PR=1 demo-app:dev` and `curl localhost:8080/healthz` returns 200. The adapter does nothing outside Lambda, which you can see in the container's logs.
- [x] `docker image ls demo-app` shows the image size: 335 MB, almost all of it the `node:24-slim` base. An `alpine` base would roughly halve it; noted for later, not needed now.

**Interview prep:** image versus container; what a layer is and why order matters for the build cache; why run as non-root; `ENTRYPOINT` versus `CMD`; why `0.0.0.0` and not `127.0.0.1` inside a container; what the Web Adapter line adds to the image.

---

### Step 3 — First CI workflow  (~1 h)

**Concepts:** `ci-cd-overview`, `github-actions-basics`.

**Why now:** from here on every change gets checked by a machine before a human looks at it.

**Build**
- [x] `.github/workflows/ci.yml` on `pull_request` and `push` to `main`: one job that checks out, sets up Node from `package.json`, runs `npm ci`, `npm run check`, `npm test`, `npm run build` and fails if `git diff --exit-code dist/` shows changes; a second job that builds `examples/demo-app` without pushing.
- [x] `actionlint` and `gitleaks` as steps.
- [x] Push the repository to GitHub. Protect `main`: require the CI check to pass.

**Verify**
- [x] A deliberately failing test on a branch turns the PR red; fixing it turns it green.
- [x] The CI badge in the README is green.

**Interview prep:** continuous integration versus delivery versus deployment; what a runner is; where secrets live in Actions and why they never appear in logs; what `permissions:` on a workflow controls; why a committed build product must be verified in CI.

---

## Part B — AWS foundations, one resource group at a time

Every step in this part adds Terraform to `terraform/modules/aws-pr-previews/` and applies it through `terraform/examples/complete/`. You apply by hand from your laptop in this part. Automating the apply is Step 15, once you have done it manually enough times to know what it does.

### Step 4 — Terraform, state and the first apply  (~2 h)

**Concepts:** `infrastructure-as-code`, `terraform-state-and-backends`, `terraform-modules` (light).

**Why now:** every AWS resource in this project is declared in Terraform. Understanding plan, apply and state before the first resource avoids the most common beginner mistakes.

**Build**
- [x] `terraform/bootstrap/`: one S3 bucket for Terraform state (versioning on, public access blocked; encryption is the AWS default). Applied once with local state. The state file is not committed, since the provider records the account ID in it; the file header lists the import commands that reattach it.
- [x] `terraform/examples/complete/`: `versions.tf` (Terraform ≥ 1.10, AWS provider 6.x), `backend.tf` (S3 backend with `use_lockfile = true`), `providers.tf` with `default_tags`, `main.tf` calling `../../modules/aws-pr-previews` with `name = "main"`.
- [x] `terraform/modules/aws-pr-previews/`: `versions.tf`, `variables.tf` with `name` and `tags`. No resources yet; `outputs.tf` arrives with the first output in Step 5.

**Verify**
- [x] `terraform init`, `plan`, `apply` in `examples/complete` succeed with zero resources, and a state object appears in the bucket.
- [x] A second `plan` shows no changes.

**Interview prep:** what Terraform state is and why it must not be lost; why remote state and locking; plan versus apply; why state can contain secrets; what a module is and when to make one.

---

### Step 5 — ECR: a place for images  (~1 h)

**Concepts:** `container-registries-and-ecr`.

**Why now:** Lambda can only run container images that live in ECR in the same account and region.

**Build**
- [ ] `ecr.tf`: one repository per entry in `var.ecr_repositories`, scan on push, a lifecycle policy expiring untagged images after 1 day and `pr-*` tags after `var.ecr_pr_image_expiry_days`.
- [ ] Variables and outputs per the spec (§9.6). In the example root, `ecr_repositories = ["demo-app"]`.

**Verify**
- [ ] `aws ecr get-login-password | docker login …`, tag and push `demo-app:dev` to the new repository. The image appears in the console with a scan result.
- [ ] The lifecycle policy preview in the console shows which images would expire.

**Interview prep:** tags versus digests and why production pins digests; what a lifecycle policy is for; how registry authentication works; ECR versus Docker Hub versus GHCR; why Lambda insists on same-account ECR.

---

### Step 6 — IAM roles and the shared log group  (~1.5 h)

**Concepts:** `iam-policies-and-roles`, `cloudwatch-logs`.

**Why now:** a Lambda function cannot exist without an execution role, and you want to understand what you are handing it before Step 7 runs code under it.

**Build**
- [ ] `logs.tf`: the log group `/aws-pr-previews/<name>` with `var.log_retention_days`.
- [ ] `iam.tf` (part one): the preview execution role, trusted by `lambda.amazonaws.com`, allowed to write to the stack log group, pull from stack repositories, and read `/aws-pr-previews/<name>/*` parameters plus `var.secret_arns`.
- [ ] Outputs for the role ARN and log group name.

**Verify**
- [ ] `terraform apply` creates both; `aws iam get-role` shows the trust policy you expect.
- [ ] `checkov` passes or skips carry a written reason.

**Interview prep:** trust policy versus permission policy; what "principle of least privilege" means concretely for this role; what happens if a function writes to a log group it is not allowed to; how log retention affects cost.

---

### Step 7 — Your first Lambda from a container image, by hand  (~2 h)

**Concepts:** `aws-lambda`, `lambda-container-images-and-the-web-adapter`, `lambda-function-urls`.

**Why now:** this is the compute layer. Doing it once by hand shows exactly what the CLI will automate in Step 10.

**Build**
- [ ] With the AWS CLI: `aws lambda create-function` from the `demo-app` image, the Step 6 role, 1024 MB, 30 s, `LoggingConfig` pointing at the stack log group, env `AWS_LWA_PORT=8080`.
- [ ] `aws lambda create-function-url-config` with auth `NONE` and `aws lambda add-permission` for `lambda:InvokeFunctionUrl`.
- [ ] Open the URL. Watch the first request take a few seconds (cold start) and the second one be instant. Read the function's log stream in the shared log group.
- [ ] Delete the function. Confirm the URL stops answering.

**Verify**
- [ ] The demo page loaded over HTTPS at a `lambda-url` hostname with a valid certificate, and nothing is left in the account.
- [ ] `terraform plan` is still clean (the manual function was outside Terraform on purpose; the concept note says why).

**Interview prep:** what Lambda is and what it is not good for; cold starts and what affects them; how the Web Adapter turns an HTTP server into a Lambda handler; what a Function URL is compared to API Gateway; how Lambda pricing works and why idle is free.

---

### Step 8 — GitHub to AWS without keys: OIDC  (~1.5 h)

**Concepts:** `github-oidc-federation`.

**Why now:** the action has to call AWS from GitHub. This is where "least privilege" stops being a phrase.

**Build**
- [ ] `iam.tf` (part two): the GitHub OIDC provider (or `var.github_oidc_provider_arn`), the deploy role with a trust policy limited to `repo:<owner>/<repo>:*` for each entry in `var.github_repositories`, and the permission policy from spec §9.7. Start with exactly the listed actions; widen only when a real call is denied, and record why.
- [ ] A workflow step in `ci.yml`: `configure-aws-credentials` with the role, then `aws sts get-caller-identity`.
- [ ] Log the `docker` job in to `public.ecr.aws` with `aws ecr-public get-login-password` before building, and remove the adapter image cache that Step 3 added to the `docker` job. Anonymous pulls from shared runner addresses hit the registry's rate limit.

**Verify**
- [ ] The workflow prints the deploy role's ARN. Reason through why a fork or another repository cannot assume it.
- [ ] `checkov` passes on the IAM policy or skips are justified.

**Interview prep:** how OIDC federation replaces access keys and why that is safer; what the `sub` claim is and how it is pinned; what `iam:PassRole` is and why it is dangerous; how you would debug an `AccessDenied`.

---

### Step 9 — Publishing the stack config to SSM  (~0.5 h)

**Concepts:** `ssm-parameter-store-vs-secrets-manager`.

**Why now:** the CLI needs the role ARN, log group and defaults. One JSON parameter is the handshake between Terraform and the code.

**Build**
- [ ] `ssm.tf`: a `String` parameter `/aws-pr-previews/<name>/config` with the JSON from spec §9.3, built with `jsonencode` from the module's own resources.
- [ ] Output `ssm_config_parameter_name`.

**Verify**
- [ ] `aws ssm get-parameter --name /aws-pr-previews/main/config` returns JSON with every field from the spec.

**Interview prep:** Parameter Store versus Secrets Manager (cost, rotation, size limits); `String` versus `SecureString`; why publish config this way rather than copying Terraform outputs into workflow files.

---

## Part C — The product

### Step 10 — The backend interface and `up`  (~2.5 h)

**Concepts:** `aws-sdk-v3`, `idempotency-and-deterministic-naming`, `ports-and-adapters` (the backend interface).

**Why now:** everything the code needs now exists. This step automates what you did by hand in Step 7.

**Build**
- [ ] `config.ts`: `StackConfig` type, validator, SSM loader.
- [ ] `naming.ts`: `slugify`, `previewId`, `functionName`, `tags`. Pure functions.
- [ ] `backends/backend.ts`: the interface from spec §7.3. `backends/lambda.ts`: `deploy` only, create or update, returning the URL. No `destroy`, no `diagnose` yet.
- [ ] `preview.ts::up` wiring config, naming and backend, without the probe. `cli.ts` with the `up` command via `parseArgs`.
- [ ] Tests: pure tests for `naming.ts` and the validator; mocked flow test that `up` creates function, URL and permission with the right tags, and that a second `up` updates instead of creating.

**Verify**
- [ ] `npm test` green.
- [ ] From your laptop: `node dist/cli.js up --stack main --image <demo-app uri> --name demo --pr 1`. The printed URL serves the demo page and shows `PR_PREVIEW_PR=1`.
- [ ] Run the same command again: still one function, same URL.
- [ ] Leave the preview running for Step 11, and say so.

**Interview prep:** what idempotency means and how deterministic names give it to you; how the SDK authenticates (credential chain); why clients are injected rather than created at import; what ports-and-adapters buys you and what it costs.

---

### Step 11 — Readiness probe and useful failure output  (~2 h)

**Concepts:** `lambda-failure-modes`, `debugging-lambda-containers`.

**Why now:** a tool that says "deployed" when the container cannot start is worse than none. This is where the project earns trust.

**Build**
- [ ] `probe.ts`: poll the URL per spec §8.4 using `fetch`.
- [ ] `backends/lambda.ts::diagnose`: function state and reasons, last 50 log lines, one hint from the spec's list.
- [ ] `up` runs the probe and, on timeout, prints diagnostics and exits 1, leaving resources in place.
- [ ] Tests: pure tests for hint selection from fixture payloads (`Runtime.InvalidEntrypoint`, adapter readiness timeout, 404); mocked test for the happy path.

**Verify**
- [ ] `up` with the correct image prints "ready" and the URL.
- [ ] `up` with an image built without the Web Adapter line fails within the timeout and the diagnostics name the cause.
- [ ] `up` with `--health-check-path /nope` fails with a 404 hint.

**Interview prep:** how a Lambda function's lifecycle states work; what a cold start looks like in logs; the order you check things when a function will not answer; why the probe lives in the core and the diagnostics in the backend.

---

### Step 12 — `down`  (~1 h)

**Concepts:** `eventual-consistency-and-retries`.

**Why now:** cleanup is the whole point of the project. It gets its own step so it is never an afterthought.

**Build**
- [ ] `backends/lambda.ts::destroy` per spec §8.2, treating `ResourceNotFoundException` as success and retrying `ResourceConflictException` with backoff.
- [ ] `preview.ts::down` and the `down` CLI command.
- [ ] Tests: mocked tests for delete, not-found no-op, and conflict retry.

**Verify**
- [ ] `down` on the preview from Step 10 removes the function. The URL stops answering. Run it again: no-op, exit 0.

**Interview prep:** what eventual consistency is, with Lambda's update-in-progress as the example; why retries need a bound and backoff; why `down` must be safe to run twice.

---

### Step 13 — Packaging the GitHub Action, and dogfooding  (~2.5 h)

**Concepts:** `github-javascript-actions-and-bundling`, `github-event-payloads-and-permissions`.

**Why now:** the code works from a laptop. Now it runs where it belongs, on every PR of this very repository.

**Build**
- [ ] `action.ts`: read inputs with `@actions/core`, derive `command`, PR number, repo and sha from the event, call `up` or `down`, set outputs.
- [ ] `comment.ts`: find-or-create the sticky comment through Octokit; render the four states from spec §8.5.
- [ ] `action.yml` with the inputs and outputs from spec §9.1, `runs: using: node24`, `main: dist/index.js`.
- [ ] `.github/workflows/dogfood.yml`: on `pull_request` opened, synchronize, reopened and closed, build and push `demo-app` to ECR, then `uses: ./`. `concurrency` per PR. Build with `--provenance=false` so the pushed tag is a plain image, not an index, which Lambda rejects (found in Step 5).
- [ ] `examples/workflows/preview.yml`: the copy-paste workflow for users.

**Verify**
- [ ] Open a PR on the repository. Within two minutes the 🟢 comment appears with a working URL; pushing a commit updates the same comment and keeps the URL; closing the PR turns it into 🗑️ and the URL stops answering.

**Interview prep:** how a JavaScript action runs and why the bundle is committed; what the `pull_request` event payload contains; which `permissions` the workflow needs and why `id-token: write` exists; what a concurrency group prevents.

---

### Step 14 — The reaper  (~2 h)

**Concepts:** `eventbridge-schedules`, `tag-based-resource-discovery`.

**Why now:** the workflow-driven cleanup exists. The reaper is the safety net for everything the workflow cannot see.

**Build**
- [ ] `reaper.ts`: discover by tags through the Resource Groups Tagging API, call `destroy` on expired previews, `--dry-run`, one JSON log line per action; export the Lambda handler.
- [ ] `reaper.tf`: the function from `dist/reaper.js` on `nodejs22.x`, 60-second timeout, the reaper role, an EventBridge schedule from `var.reaper_schedule`.
- [ ] Tests: mocked tests for expired versus live, and skipping a function mid-update.

**Verify**
- [ ] `up` with `--ttl-hours 0`, then `node dist/cli.js reap --stack main --dry-run` lists it; a real `reap` removes it.
- [ ] Invoke the reaper Lambda from the console and read its JSON log lines.

**Interview prep:** what EventBridge is beyond cron; why tags are a reliable discovery mechanism and what happens if someone strips them; why the reaper reuses `destroy` rather than deleting on its own.

---

## Part D — Pipelines and release

### Step 15 — Terraform in CI: plan on PR, apply on main  (~2 h)

**Concepts:** `gitops-for-infrastructure`, `github-environments-and-approvals`.

**Why now:** you have applied by hand ten times. You know what it does. Now a pipeline does it, with a human approval gate.

**Build**
- [ ] `.github/workflows/terraform.yml`: on PRs touching `terraform/**`, run fmt, validate, tflint, checkov, then `plan` via OIDC and post the plan summary as a PR comment. On push to `main`, `apply` inside the `aws-main` environment with a required reviewer.
- [ ] A dedicated OIDC role for Terraform in CI, separate from the deploy role, with the permissions the module needs. Record the decision.
- [ ] `terraform-docs` generates the module README's inputs and outputs table in CI and fails if it is stale.

**Verify**
- [ ] A PR that changes `log_retention_days` shows the plan diff as a comment; merging it waits for your approval, then applies.
- [ ] `terraform plan` from your laptop afterwards shows no drift.

**Interview prep:** what GitOps means for infrastructure; how you review an infrastructure change safely; what drift is and how you detect it; why the apply needs an approval gate and the plan does not.

---

### Step 16 — Releases: tags, `dist/`, major version pointer  (~1.5 h)

**Concepts:** `semantic-versioning-and-release-automation`, `supply-chain-security`.

**Why now:** users will reference `@v1`. Everything behind that tag must be reproducible and audited.

**Build**
- [ ] `.github/workflows/release.yml` on tags `v*.*.*`: `npm ci`, `npm run build`, fail if `dist/` differs from the tag, move the floating `vX` tag, generate release notes from Conventional Commits.
- [ ] `npm audit` gate in `ci.yml`. Trivy on the demo image. `dependabot.yml` for npm, docker, github-actions and terraform.
- [ ] `CONTRIBUTING.md` describing the step loop and the release process.

**Verify**
- [ ] Tag `v0.1.0`. `uses: Pantelijaa/aws-pr-previews@v0` in a scratch repository runs from the committed bundle.
- [ ] The release page shows generated notes.

**Interview prep:** what semantic versioning promises; why a floating major tag is convenient and what it risks compared to pinning a sha; what supply-chain attacks on CI look like and which of our controls address each.

---

## Part E — Launch

### Step 17 — Documentation, costs, marketplace, launch  (~3 h)

**Concepts:** `open-source-project-hygiene`, `networking-basics-for-interviews` (interview-only: VPC, subnets, security groups, load balancers; nothing is built).

**Why now:** the tool works. Now it has to be discoverable, understandable in sixty seconds, and honest about limits.

**Build**
- [ ] `README.md`: pitch, GIF of a PR receiving its URL, architecture diagram, quick start (Terraform then workflow), the Dockerfile requirement, inputs and outputs table, cost table, limits, FAQ, comparison with PullPreview, "built as a learning project" section linking `docs/concepts/`.
- [ ] `docs/costs.md` (Lambda today, ECS plus ALB table for the future backend) and `docs/troubleshooting.md` (every diagnostics hint explained).
- [ ] Issue and PR templates, `CODE_OF_CONDUCT.md`.
- [ ] Marketplace listing, tag `v1.0.0`.
- [ ] Launch posts: r/aws, r/devops, Hacker News "Show HN", dev.to, LinkedIn. Each one honest: what it does, what it costs, what it does not do.

**Verify**
- [ ] Every box in spec §16 is ticked.
- [ ] Someone who has never seen the repo follows the quick start on a fresh account and gets a preview URL. Time them.

**Interview prep:** how you would explain this project in two minutes; the hardest bug and how you found it; what you would do differently; what you would build next and why.

---

## Roadmap — the ECS Fargate plus load balancer backend

Planned, not scheduled. Pick it up after v1.0 with the same step loop. Idle cost: about 20 USD per month for the load balancer, plus a domain.

- **R1 — Networking:** VPC with two public subnets, internet gateway, security groups. Concepts `vpc-and-subnets`, `security-groups`.
- **R2 — ECS cluster and a manual Fargate task.** Concepts `ecs-and-fargate`, `ecs-task-definitions-and-iam-roles`.
- **R3 — ALB, wildcard ACM certificate, wildcard Route 53 record.** Concepts `load-balancers-and-the-alb`, `tls-certificates-and-acm`, `dns-and-route53`. Requires a domain.
- **R4 — `backends/ecs.ts`:** task definition, service, target group, host-based listener rule; `diagnose` from stopped tasks and target health. Deploy role gains ECS and ELBv2 permissions.
- **R5 — `backend = "ecs"` module variable** and the extra SSM config fields; reaper filter gains `ecs:service` and sweeps orphaned target groups.
- **R6 — Docs:** when to choose which backend (WebSockets, long requests, stable hostnames versus zero idle cost).

---

## Concept map

Every note lives in `docs/concepts/<no>-<slug>.md`, numbered in the order the steps introduce them, and is written in the step that introduces it.

| No. | Slug | Step | Area |
|-----|------|------|------|
| 01 | `aws-account-and-iam-basics` | 0 | AWS |
| 02 | `aws-cost-safety` | 0 | AWS |
| 03 | `typescript-and-node-tooling` | 1 | Tooling |
| 04 | `linting-formatting-typing` | 1 | Tooling |
| 05 | `containers-and-images` | 2 | Docker |
| 06 | `dockerfile-basics` | 2 | Docker |
| 07 | `lambda-web-adapter` | 2 | Docker, AWS |
| 08 | `ci-cd-overview` | 3 | CI/CD |
| 09 | `github-actions-basics` | 3 | CI/CD |
| 10 | `infrastructure-as-code` | 4 | IaC |
| 11 | `terraform-state-and-backends` | 4 | IaC |
| 12 | `terraform-modules` | 4 | IaC |
| 13 | `container-registries-and-ecr` | 5 | Docker, AWS |
| 14 | `iam-policies-and-roles` | 6 | Security |
| 15 | `cloudwatch-logs` | 6 | AWS |
| 16 | `aws-lambda` | 7 | AWS |
| 17 | `lambda-container-images-and-the-web-adapter` | 7 | AWS |
| 18 | `lambda-function-urls` | 7 | AWS |
| 19 | `github-oidc-federation` | 8 | Security, CI/CD |
| 20 | `ssm-parameter-store-vs-secrets-manager` | 9 | AWS |
| 21 | `aws-sdk-v3` | 10 | Code |
| 22 | `idempotency-and-deterministic-naming` | 10 | Design |
| 23 | `ports-and-adapters` | 10 | Design |
| 24 | `lambda-failure-modes` | 11 | Operations |
| 25 | `debugging-lambda-containers` | 11 | Operations |
| 26 | `eventual-consistency-and-retries` | 12 | Design |
| 27 | `github-javascript-actions-and-bundling` | 13 | CI/CD |
| 28 | `github-event-payloads-and-permissions` | 13 | CI/CD |
| 29 | `eventbridge-schedules` | 14 | AWS |
| 30 | `tag-based-resource-discovery` | 14 | Design |
| 31 | `gitops-for-infrastructure` | 15 | CI/CD |
| 32 | `github-environments-and-approvals` | 15 | CI/CD |
| 33 | `semantic-versioning-and-release-automation` | 16 | CI/CD |
| 34 | `supply-chain-security` | 16 | Security |
| 35 | `open-source-project-hygiene` | 17 | Community |
| 36 | `networking-basics-for-interviews` | 17 | Networking (interview only) |
| R | `vpc-and-subnets`, `security-groups`, `ecs-and-fargate`, `ecs-task-definitions-and-iam-roles`, `load-balancers-and-the-alb`, `tls-certificates-and-acm`, `dns-and-route53` | Roadmap R1–R3 | ECS backend |
