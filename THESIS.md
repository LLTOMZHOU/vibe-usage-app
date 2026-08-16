# Product thesis

## Private by default, useful by choice

AI usage history is behavioral telemetry. It can reveal what tools someone
uses, when they work, which projects occupy their attention, and how their
workflow changes over time. A useful dashboard should not require people to
publish that history or silently widen who can see it.

This fork begins with security hardening, but it is not meant to stop there. It
is a foundation for an independent product whose usefulness can grow without
making privacy progressively harder to understand.

## Principles

1. **Local value comes first.** The dashboard must work from data already on the
   user's Mac without an account. Cloud features must earn the data they require.
2. **Every disclosure is a separate choice.** Sync, public ranking, project
   names, session metadata, and credential-backed probes are not one bundle of
   consent.
3. **Defaults should survive inattention.** A user who clicks through nothing
   should not publish data, expose project names, or grant new credential
   access.
4. **The boundary must be inspectable.** Network destinations, child processes,
   collector source, persistence, and release provenance belong in public code
   and mechanical checks.
5. **Failure is private.** If the app cannot verify a privacy-sensitive server
   setting, it does not upload and hope for the best.
6. **Upstream is a source, not an authority.** Good fixes can be ported after
   review; compatibility never outranks this fork's promises.
7. **Users own the exit.** New work should move toward export, deletion,
   portability, and eventually user-controlled or self-hosted sync.

## Product direction

Security and privacy are phase one. The first original feature is now the
account-free local dashboard. Natural next additions include local price tables
with visible provenance, richer local analysis, data previews before upload,
user-owned exports and backups, selective or self-hosted sync, and original
insights that do not require a public identity. Social or comparative features
can exist, but only as explicit opt-ins with a clear account-level state.

The test for a new feature is not merely “is it convenient?” It is: does it add
real value while keeping the user's data flow understandable and reversible?
