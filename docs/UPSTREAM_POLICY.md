# Upstream update policy

`origin` is the public hardened fork. `upstream` is
`https://github.com/vibe-cafe/vibe-usage-app.git` and should be fetch-only.

A scheduled Codex task may fetch upstream and open a review pull request. It
must never merge, tag, publish a release, enable a parser, rotate a key, or copy
an updated collector without human approval.

Every proposed update must:

1. summarize upstream commits and security-relevant diffs;
2. preserve every invariant in `SECURITY.md`;
3. treat changes to process execution, parsers, network destinations,
   credential access, persistence, and packaging as high-risk;
4. update `ORIGIN.md` when intentionally updating the collector snapshot;
5. run `scripts/verify-hardening.sh`, `swift test`, and a package build;
6. open a draft pull request with unresolved risks and test evidence.

No GitHub Actions workflow or repository secret existed in the upstream app at
the fork baseline. In general, workflow files are copied by GitHub forks, but
scheduled workflows are disabled until explicitly enabled and Actions secrets
are never copied.
