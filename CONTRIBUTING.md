# Contributing

Thanks for taking a look. This project moves fast because it is tightly coupled to Spotify's internals, so the biggest help you can give is **small, targeted contributions that say exactly what Spotify version they were tested on**.

## Before you open an issue

Please use the issue templates.

- **Bug reports** go through the bug report template. It will ask for:
  - installation type (jailbreak / TrollStore / sideloaded IPA, etc.)
  - Spotify version
  - EeveeSpotify version
  - iOS / iPadOS version
  - affected area
  - a debug log from the tweak settings if relevant
- **Feature requests** go through the feature request template.
- Before filing anything, check [common_issues.md](common_issues.md) and the **Restrictions** section of the README. Features that are server-sided are not something this tweak can fix.

If you are reporting a crash or a feature regression, include the Spotify build number when you can. Version matters a lot here.

## Building locally

If you want to test a change yourself, there are a few paths already in the repo:

- `setup-build-ipa.sh` / `build-ipa-local.sh` for IPA-style builds
- `make package` for building a `.deb`

Some builds also need a locally built `EeveeSwiftProtobuf.framework`. The Makefile documents that with the `build-eeveeswiftprotobuf` target, and the CI workflows do the same thing before packaging.

If you are just tweaking logic and do not need a full IPA right away, the most important thing is still that you can build cleanly and that the change does not obviously break compilation for the version family you care about.

## Version sensitivity

EeveeSpotify hooks private classes, selectors, and response shapes that can change between Spotify releases. That means:

- A change that works on one Spotify version may not be safe on another.
- When you contribute something that touches hooking, patching, or response parsing, say which Spotify version(s) you tested on.
- If you are relying on a specific class or selector being present, note that assumption in the PR description.

The more explicit you are about the target version, the easier it is to review and merge without silently breaking another build.

## Translations

Translations are welcome. The translation workflow is described in [TRANSLATING.md](TRANSLATING.md), and there is a checker in `Tools/l10n_lint.py` that validates translations before they are submitted.

If you are contributing or updating a localization, run the checker and include its result in the PR. That saves review time and prevents obvious issues from landing.

## Pull requests

A good PR here is usually:

- small and focused on one thing
- clearly described in the PR body
- tied to a specific behavior or issue when possible
- honest about what was and was not tested

For code changes, please include:

- what the change does
- why it is needed
- which Spotify version(s) you tested on
- any version-specific assumptions it depends on

If a change is experimental or only relevant to a narrow version range, say so directly. That helps maintainers decide how to handle it.

## Nice-to-haves

- Keep PRs scoped. If you have two unrelated fixes, split them.
- If you are adding logging, do not log anything sensitive.
- If you are touching something version-dependent, do not assume it is safe everywhere unless you tested it or the code explicitly guards for it.




