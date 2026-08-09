# Releasing

Releases require a signed SemVer tag and explicit approval through the protected `public-release` GitHub environment.

Before approval:

1. Complete every organizational gate in `PROVENANCE.md`.
2. Run `make check` and `make verify` on amd64.
3. Run the full scenario on Colima/Apple Silicon before claiming arm64 runtime support.
4. Confirm secret, forbidden-marker, vulnerability, license, and source-similarity scans.
5. Review `CHANGELOG.md` and immutable dependency digests.

The workflow publishes only `vX.Y.Z` and commit-SHA image tags, never `latest`. It creates a digest-pinned Compose artifact, SPDX SBOM, checksums, build provenance, and a keyless Cosign signature.

Creating a public remote, changing visibility, pushing the first commit, publishing the first package, and creating the first release each require the user's explicit approval at execution time. The workflow definition does not grant that approval.

GitHub Actions are pinned to reviewed major versions. Dependency automation proposes updates; maintainers must inspect the resolved action SHA and upstream release notes before merging supply-chain changes.
