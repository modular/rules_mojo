# Releasing

[Release Please](https://github.com/googleapis/release-please) maintains a release
PR as changes land on upstream `main`. A maintainer reviews and merges that PR
to release. The PR updates `MODULE.bazel`, `CHANGELOG.md`, and the release manifest
using the Bazel release strategy. Tags remain unprefixed, for example `0.9.0`.

Use [Conventional Commit](https://www.conventionalcommits.org/) PR titles and
squash merges:

- `fix:` increments the patch version.
- `feat:` increments the minor version.
- `!` or a `BREAKING CHANGE:` footer increments the minor version before 1.0.0
  and the major version afterward.
- Changes such as `chore:` and `ci:` normally do not trigger a release.

The `Validate PR title` check accepts titles such as `fix: correct imports`,
`feat(toolchain): add support`, and `refactor!: remove deprecated API`. Scopes
are optional, and subjects may start with an uppercase letter. Use `!` in the
title to indicate a breaking change; a `BREAKING CHANGE:` footer belongs in the
squash commit body.

To override the proposed version, include a `Release-As: X.Y.Z` footer in a commit
on `main`, such as a PR's squash commit. Review the updated release PR before
merging it. The initial baseline is the published `0.8.0` release; subsequent
versions are maintained by release-please.

## Setup and CI

Release Please uses the built-in `GITHUB_TOKEN`. Enable **Allow GitHub Actions to
create and approve pull requests** in Settings > Actions > General, subject to
organization policy. No separate release-please token is needed.

A repository administrator must configure squash merges to default to the PR
title in Settings > General > Pull Requests. After the title workflow is on
`main` and has reported a result, add `Validate PR title` from GitHub Actions to
the required status checks in the existing `main CI` ruleset. Keep the current
required checks. Adding the workflow alone does not make it a merge requirement.

BCR publication requires a `modular/bazel-central-registry` fork and the
`BCR_PUBLISH_TOKEN` repository secret with access to push to that fork and open
the registry PR. See the publisher's
[token setup](https://github.com/bazel-contrib/publish-to-bcr#3-create-a-personal-access-token).

Release Please explicitly dispatches the Test workflow on its PR branch, running
the Bazel matrix, pre-commit, `conclusion`, and compatibility checks. Dispatch
Test on that branch to rerun it. Cache writes remain restricted to upstream
`main` push CI.

Title validation runs separately on PR opens, reopens, edits, and new commits.
For bot-created release PRs, GitHub can place these runs in an approval-required
state. A maintainer with write access selects **Approve workflows to run** in
the PR merge box to start them; editing the description is not required. See
[GitHub's workflow trigger rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow).

## Release and recovery

After a release PR is merged, Release Please creates its tag and GitHub Release,
then directly calls the Release workflow to test, package source and API docs,
upload attestations, and publish a BCR PR. The GitHub Release is visible before
its assets finish uploading. Final notes contain the reviewed changelog entry
and installation instructions.

If packaging, uploads, or BCR publication fails, dispatch the
[Release workflow](https://github.com/modular/rules_mojo/actions/workflows/release.yaml)
from `main` with the existing unprefixed tag as `tag_name`. It can update an
existing GitHub Release; it rejects versions already present in BCR. Rerunning
Release Please alone does not retry packaging for an already-created release.

Manually pushed version tags also start the Release workflow, for example:

```sh
git fetch upstream
git tag 0.9.0 upstream/main
git push upstream 0.9.0
```

Tags must point to a commit on upstream `main` containing the release automation
and BCR templates. Tags without a matching changelog entry use GitHub-generated
notes alongside installation instructions. Manual tags use the stable-release
pipeline, including tags with prerelease suffixes; use release PRs for routine
releases to keep the module version and manifest synchronized. Tags created by
Release Please do not trigger a second tag-push workflow run.
