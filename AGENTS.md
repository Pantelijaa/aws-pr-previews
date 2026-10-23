# Agent Guide

How coding agents (and humans) work in this repository. Read this before touching anything.

## 1. What this repository is

`aws-pr-previews`: a GitHub Action plus a Terraform module that gives every pull request a live HTTPS preview on AWS Lambda and removes it when the PR closes. Full requirements live in [PROJECT_SPECIFICATION.md](PROJECT_SPECIFICATION.md). The build order lives in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

The repository has two jobs at once:

1. Be a small, clean, genuinely useful open-source tool.
2. Be the place where its maintainer learns AWS, Docker, TypeScript tooling and CI/CD from zero, well enough to defend every piece in an interview.

The second job shapes how we work more than the first. The maintainer has **no prior AWS knowledge**. Assume nothing.

## 2. The step loop

Work happens one step at a time, in the order given by the implementation plan. One step per turn. Never pull work forward from a later step, even when it looks trivial.

For every step:

1. **Read the step.** Note its concepts, deliverable and verification.
2. **Concepts first.** For every concept the step lists, write or refresh `docs/concepts/<no>-<slug>.md` (the number comes from the concept map in the plan) using the template in §3. The `docs/` folder is gitignored; the notes stay on the maintainer's machine. Then give a short walkthrough in chat: what it is, why this project needs it, where it will show up in the code. Keep it to roughly ten lines per concept. Write the full name next to every abbreviation the first time it appears, in chat and in notes: IAM (Identity and Access Management), ARN (Amazon Resource Name). End with "Ready to build?" and **wait**. Do not write implementation code before the maintainer says go.
3. **Build the smallest deliverable** that satisfies the step. If the step can be split further without producing dead code, split it and say so. **The maintainer types the code.** For application source and tests (`src/`, `tests/`, `examples/demo-app/`), present the complete code in chat, file by file, with a sentence on what each part does, and wait for the maintainer to write it. The agent writes configuration, workflows, Terraform, documentation and `package.json` changes directly. The maintainer may hand any file to the agent or take any file over by saying so.
4. **Verify** with the step's commands. Show the real output, including failures.
5. **Record progress.** Tick the step's checkboxes in the implementation plan. Add a line under `Unreleased` in `CHANGELOG.md` when something user-visible changed.
6. **Close the step.** Summarise what changed and how it was verified. Ask the maintainer two or three interview questions from the concept notes, without answering them. Name the next step. Stop.

A step that touches a new AWS service always starts with the concept, even when the code change is ten lines.

## 3. Concept note template

Path `docs/concepts/<no>-<slug>.md`, 40–60 lines, plain language, no marketing.

```markdown
# <Concept name>

**One sentence.** What it is, for someone who has never heard of it.

## Why it exists
The problem it solves, in two or three sentences. Mention what people did before it.

## How we use it here
Which files or resources in this repo, and the one or two decisions we made about it. Link to the spec section.

## Mental model
A short analogy or diagram if it genuinely helps. Skip if it does not.

## Gotchas
Two to four bullets: the things that bite in practice (cost, limits, eventual consistency, security).

## Interview questions
3–5 questions with model answers of two or three sentences each. Include at least one "why did you choose X over Y" question.

## Further reading
One or two links, official docs first.
```

Write it like a good colleague explaining at a whiteboard. If a note needs more than 60 lines, the concept should be split.

## 4. Code rules

The goal is the least code that does the job well. Code is a liability; every line must earn its place.

- **Smallest change that works.** No speculative abstractions, no "we might need this later", no feature flags for features that do not exist. The one planned abstraction is the `Backend` interface in the spec, and it has exactly three methods.
- **No helper that is used once.** Inline it.
- **No wrappers around the AWS SDK.** Call the client where the work happens. Clients are created once at the entry point and passed in, so tests can hand in `aws-sdk-client-mock` clients. A module-level `new LambdaClient()` is a bug.
- **Pure logic apart from I/O.** Naming, tag building, parsing, validation and formatting are plain functions with plain inputs. They need no AWS to test.
- **Functions fit on a screen.** Around 30 lines. A longer one is usually two.
- **No `utils.ts`, no `helpers.ts`, no `common.ts`.** Name the module after what it does.
- **Dependency budget.** Runtime: the four `@aws-sdk/client-*` packages, `@actions/core`, `@actions/github`. Dev: `typescript`, `esbuild`, `vitest`, `@biomejs/biome`, `aws-sdk-client-mock`, `@types/node`. Anything else needs one written sentence of justification in the PR, and the answer is usually no. Prefer Node built-ins (`fetch`, `node:util` `parseArgs`, `node:crypto`).
- **Strict TypeScript.** `strict: true`, `noUncheckedIndexedAccess: true`. No `any` without a comment saying why. Types describe data; avoid classes unless state genuinely needs encapsulating.
- **Errors tell the reader what to do.** "Stack 'main' not found. Did you apply the Terraform module?" beats a raw `ParameterNotFound`.
- **Delete before adding.** When a change makes code unnecessary, remove it in the same change.
- **Match the spec's names.** Inputs, outputs, tags and file names use the exact spellings in the specification. Change the spec first if a name must change.
- **`dist/` is a build product.** Never edit it by hand. `npm run build` regenerates it; CI fails when it is stale.

## 5. Comment rules

Comments explain **why**, never **what**. The code already says what.

- Write a comment only when a reader would otherwise stop and wonder. Typical reasons: an AWS quirk, an ordering constraint, a deliberate deviation from the obvious approach, a limit we are working around.
- Write it as a human sentence. Capital letter, full stop, no tags like `TODO:` unless there is an issue number next to it.
- No comment that restates the next line. No section banners. No commented-out code.
- JSDoc only on the `Backend` interface and the three public entry points (`up`, `down`, `reap`), and only when the name and signature leave something unsaid.

Good:

```ts
// Lambda rejects a second update while one is in flight, so a push that
// lands mid-deploy gets ResourceConflictException. Retrying for a minute
// is cheaper than making users serialise their workflows.
```

Bad:

```ts
// Delete the function
await lambda.send(new DeleteFunctionCommand({ FunctionName: name }));
```

Also bad:

```ts
// TODO handle errors
```

## 6. Terraform rules

- One file per concern, as laid out in the specification. Resources named `aws-pr-previews-<name>-<purpose>`.
- Every variable has a `description` and, where sensible, a `validation` block. Every output has a `description`.
- No hard-coded regions, account IDs or ARNs. Derive them from data sources or variables.
- Tags come from `default_tags` in the example root, plus `pr-previews:stack` on everything the module creates.
- `terraform fmt`, `terraform validate` and `tflint` pass before any commit. `checkov` findings are fixed or explicitly skipped with a one-line reason in the resource.
- Changes to IAM policies state in the PR which API calls were added and why each is needed.

## 7. Tests

- Pure functions get pure tests. SDK flows get `aws-sdk-client-mock`. Nothing talks to real AWS in `vitest`.
- Each behaviour in the specification's §8 has at least one test that names it, for example `second up updates the function instead of creating one`.
- Fixtures live in `tests/fixtures/` as real payloads (an SSM config, a `pull_request` event, a `GetFunction` response in state `Failed`). No fixture is edited to make a test pass.
- The dogfood workflow is the integration test. If something can only be verified against real AWS, say so and verify it there with the maintainer watching.

## 8. Boundaries

- **Never create, change or destroy real AWS resources without explicit permission in the current conversation.** That includes `terraform apply`, `aws lambda create-function` and `docker push` to ECR. Ask, naming the expected cost (usually zero, say so anyway).
- **Cost awareness is part of correctness.** Anything that would cost money while idle (a load balancer, NAT, provisioned concurrency, a database) is outside v1.0 and needs the maintainer's explicit yes. Never leave a manual test resource behind.
- **No secrets in the repository.** No keys, tokens, account IDs in committed files, webhook URLs. Account IDs in the spec and examples are the placeholder `123456789012`.
- **Do not change requirements silently.** If a step turns out to be wrong, too costly or unclear, say so and propose the smallest change to the specification. The maintainer decides.
- **Do not commit, push, tag or open PRs** unless asked. Prepare the commit message and show it.

## 9. Commands

Run from the repository root.

```bash
npm ci                                    # install exactly what the lockfile says
npm run check                             # biome ci . && tsc --noEmit
npm test                                  # vitest run
npm run build                             # esbuild → dist/index.js, dist/cli.js, dist/reaper.js
node dist/cli.js --help
docker build -t demo-app:dev examples/demo-app
terraform -chdir=terraform/examples/complete fmt -check -recursive
terraform -chdir=terraform/examples/complete validate
tflint --chdir terraform/modules/aws-pr-previews
```

Before saying a step is done, run everything in this list that the step touched and show the output.

## 10. Commits and pull requests

- Conventional Commits: `feat:`, `fix:`, `docs:`, `chore:`, `ci:`, `refactor:`, `test:`. Scope optional, for example `feat(cli): add down command`.
- One step per pull request. The PR description says what changed, how it was verified, and links the step in the implementation plan.
- The maintainer reviews every PR. Reviews are a learning moment, so explain non-obvious lines in the PR description rather than in code comments.

## 11. When unsure

Say what you are unsure about, propose the simplest option, and ask. A wrong guess that touches AWS costs trust, and sometimes money. A question costs a minute.
