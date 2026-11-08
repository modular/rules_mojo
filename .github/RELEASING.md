# Releasing rules_mojo

The Release Please workflow runs on pushes to upstream `main` and can also be
dispatched manually. It maintains a release PR containing `CHANGELOG.md`,
`MODULE.bazel`, and `.release-please-manifest.json`, starting from release 0.8.0.
Conventional Commits determine the next version: `fix:` increments the patch,
`feat:` increments the minor, and breaking changes increment the minor while
the project is below 1.0. Review the version and changelog before merging the
release PR; use release-please's `Release-As:` commit footer for an explicit
version, including the first major release.

Merging the release PR creates an unprefixed tag and GitHub release, then calls
the release workflow directly to test, build archives and API documentation,
attest artifacts, and publish to the BCR. The reviewed changelog is included in
the final release notes. The Bazel release strategy updates the module's own
version without changing dependency versions.

Repository setup requires these secrets:

- `RELEASE_PLEASE_TOKEN`: a dedicated bot PAT or equivalent token with repository
  contents, issues, and pull requests read/write access. Unlike `GITHUB_TOKEN`,
  this allows release PRs to trigger required CI. Keep this separate from the
  registry token.
- `BCR_PUBLISH_TOKEN`: the token required by `bazel-contrib/publish-to-bcr` for
  pushing to `modular/bazel-central-registry` and opening the registry PR.

There is no scheduled release or cooldown; maintainers control release timing
by merging the release PR. A GitHub release exists before its assets finish
building. If artifact publishing fails, rerun the failed jobs, or dispatch the
Release workflow on `main` with the tag and `existing_release` enabled. This
explicit option allows updating an existing release; versions already in the
BCR remain protected. For a manual tag without a GitHub release, leave
`existing_release` disabled.
