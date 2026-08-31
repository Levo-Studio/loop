# CLAUDE.md — Working instructions for Loop

This file describes **Loop** and nothing else. No infrastructure, no servers, no
deployment, no other projects. What is written here applies to work in this
repository.

## Read first

Four things in the repo apply alongside this file. Read them before you touch
anything:

- `design/` — the design export. **This is the single source of truth for every
  colour, size, spacing value and state.** See "Design fidelity" below. Not
  optional, not a suggestion.
- `CONTRIBUTING.md` — the same content as here, in full prose and written for
  humans. In case of doubt, what it says wins.
- `README.md` — what Loop is and how it is built.
- `LICENSE` — source-available, **no redistribution of any kind**. Stricter than
  it looks at first glance. Read section 3 before you suggest anything involving
  TestFlight, sideloading or a store.

## Language

**Everything in this repository is English.** App interface, string catalog,
code, comments, commit messages, branch names, documentation, issues, pull
requests. There is no German in Loop, not even in a comment. This is the one
place where Loop deliberately differs from its sibling project Score.

## What Loop is

Loop is a study timer for iOS and iPadOS 26, written in SwiftUI. Five
full-screen pages, swiped horizontally, no chrome:

1. **Clock** — the current time, seconds optional
2. **Count-up** — a stopwatch
3. **Countdown** — one duration, counted down
4. **Interval** — focus and break blocks over a number of rounds
5. **Settings** — seconds toggle and accent colour

Everything lives on the device. No backend, no account, no login, no network
code at all. There is nothing to sync, so there is nothing to leak.

## Design fidelity — the hard rule

`design/` contains the design export: `Loop Design Notes.md` (the written spec,
complete and authoritative) and the `.dc.html` prototypes with every state in
light and dark, portrait and landscape, for all four accents.

**Every writer and every reviewer reads `design/` before the first line of code
or the first line of a review. No exceptions, including for a one-line change.**

- No colour, size, spacing, radius, opacity, letter-spacing or line-height value
  is invented, rounded, or implemented "close enough". The HTML sizes are design
  points and transfer 1:1 to SwiftUI points.
- If a value you need is not in the export, that is a question for the owner,
  not a gap you fill with taste.
- The German labels in the export (`Uhr`, `bereit`, `Fokus · Runde 02 / 04`) are
  translated to English (`Clock`, `ready`, `Focus · Round 02 / 04`). **Only the
  words change. Geometry, weight, letter-spacing, casing and colour do not.**

Two known facts about the export, so nobody rediscovers them the hard way:

- `Loop iPhone Screens.dc.html` and `Loop iPad Screens.dc.html` were cut off at
  256 KiB by the export tool. The portrait states are complete; the tail
  (landscape and accent variants) is missing. `Loop Design Notes.md` covers what
  is missing and is authoritative where the HTML stops.
- Where the two disagree, **the HTML wins for pixel values** — it is what was
  actually drawn. Concretely: the notes say landscape padding is `32/28/24`, the
  HTML renders landscape at `32/40/24`. Use `32/40/24`.

## The non-negotiable design idea

There is exactly **one** progress indicator in this app: a solid area that
rises from the bottom edge, its height proportional to elapsed time over the
duration of the *current* block. No bars, no rings, no dots, no segments, no
second opinion. Interval uses the same fill for focus and for break — only the
status pill and the round counter change.

**The fill is a progress indicator, never a decoration.** It exists only while a
block is running, and its height is `1 − remaining / blockDuration` for the
*current* block. Clock, Count-up and every setup, idle and stopped state have no
total duration to measure against, so they show **no area at all** — not a
sliver, not a resting height, not a tint. An area on screen while nothing is
counting is a bug, and it is the kind that reads as a design choice, so nobody
reports it.

Rounds, focus length and break length belong to **Interval only**. Countdown has
exactly one control: the duration. That difference is the whole reason the two
screens exist separately.

Anything crossing the fill edge — the time, labels, buttons, the navigation
dots — is **two-toned**: ink above the edge, the on-fill tone below it. In the
prototype this is the same content rendered twice with `clip-path`. In SwiftUI
it is a second layer masked to the fill rectangle.

The on-fill tone is not a lookup table. It is a rule: fill lightness above
`0.62` means `#141414`, otherwise `#f6fbfb`. Implement the rule so it stays
correct for an accent nobody has added yet.

## Toolchain and commands

- **Xcode 26**, target **iOS/iPadOS 26.2** (`IPHONEOS_DEPLOYMENT_TARGET = 26.2`)
- **Swift 6** (`SWIFT_VERSION = 6.0`) with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: types are on the main actor by
  default. Anything that should not be — the engine, everything meant to run in
  tests without a simulator — is explicitly `nonisolated`.
- Bundle ID `apps.levo-studio.Loop`. No entitlements, no capabilities, no
  iCloud container.
- No linter, no formatter, no `.editorconfig`. Four spaces, no tabs,
  `// MARK: -` for structure, otherwise match the file you are editing.
- **Synchronized folders**: new files under `Loop/` and `LoopTests/` join the
  target on their own. `Loop.xcodeproj/project.pbxproj` is **not** touched for
  that, and a diff that touches it without a build-setting reason is a mistake.

`xcode-select` points at the CommandLineTools on many machines, and those cannot
build an iOS project. Hence the `DEVELOPER_DIR` prefix.

Build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Loop.xcodeproj -scheme Loop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO build
```

Test:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Loop.xcodeproj -scheme Loop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

`CODE_SIGNING_ALLOWED=NO` means you do not need a developer team to build Loop.
`DEVELOPMENT_TEAM` stays out of every diff.

## Architecture rules — not negotiable

```
Loop/
  Engine/        timer core — nonisolated, Date-based, no SwiftUI import
  Core/Design/   LoopPalette, LoopTypography, LoopMetrics, LoopMotion
  Core/          settings, formatting, persistence
  Features/      one folder per screen, plus the shell
  Resources/     IBM Plex Mono, Localizable.xcstrings
LoopTests/       Swift Testing
design/          the design export — read-only, never edited to match the code
```

**The engine knows no view.** `Loop/Engine/` imports `Foundation` and nothing
else. It holds plain `Sendable` values and pure functions over them. No
`@Observable`, no `Color`, no `View`, no `import SwiftUI`. That is what makes
the timer testable in milliseconds without a simulator, and it stays that way.

**Time comes from `Date`, never from counting ticks.** A running timer stores
the instant it will end (or started), and every frame derives the remaining
value from `Date.now`. A display timer that increments a counter drifts, stops
in the background, and lies after a device sleep. State survives app restart
and backgrounding because the stored instant survives, not because something
kept counting.

**Colour, size and motion come only from the design layer.** `LoopPalette`
resolves every token for light and dark and for the four accents,
`LoopMetrics` holds spacings and radii, `LoopTypography` the type scale,
`LoopMotion` the curves. No numeric or colour literals in feature files: no
`.padding(17)`, no `Color(red:...)`, no hand-rolled `timingCurve`. If a value is
missing it goes into the design layer, not into the call site.
`LoopMotion.resolve(_:reduceMotion:)` handles *Reduce Motion* centrally — at a
hundred call sites it would be forgotten at ninety of them.

**The fill is one component, used four times.** Countdown and Interval do not
each grow their own copy of the rising area and the two-tone text. There is one
implementation in the design layer and the screens hand it a fraction.

**Visible text belongs in `Loop/Resources/Localizable.xcstrings`.** The catalog
is maintained by hand (`extractionState: manual`); Xcode's automatic extraction
adds nothing useful here. English only — do not add a second language. No
visible string sits as a literal in a view.

## Code style

- **Four spaces**, no tabs.
- `// MARK: -` in any file with more than one type or more than a handful of
  functions.
- **No numeric or colour literals in feature files.** See above.
- **Nothing enforces style** — no SwiftLint, no SwiftFormat. So match the file
  you are editing.
- Never change formatting in the same commit as logic. If an indentation bothers
  you while reading: separate commit, or not at all.
- No `print`, no `debugPrint`, no commented-out code, no `TODO` without a name
  and a reason next to it. Preferably no `TODO` at all.

## Comments

Comments explain the **why**, not the what. A comment describing what the line
below it does is wasted. One explaining why it is not the obvious approach saves
the next person half a day. Whole paragraphs above a single constant are
deliberate here, not an exception.

**A comment that promises something the code does not do is worse than no
comment.** If you change behaviour, pull the comments above it along — including
the ones in neighbouring files that repeat the same promise.

## Tests

`LoopTests/`, **Swift Testing** (`@Test`, `@Suite`, `#expect`) — not XCTest. A
red run is not delivered; if a test is genuinely wrong it gets fixed in its own
commit, with a reason.

The engine is where the tests live. It is pure, `Date`-based and injectable, so
there is no excuse: block transitions, the last round having no break, skip
being legal only during a break, a resume after two hours in the background,
the fill fraction at a block boundary. All of that is testable without a view.

Every fix ships with a test that fails **without** the fix. The counter-check is
mandatory: pull the fix, watch it go red, put the fix back, watch it go green. A
regression test nobody has seen fail is decoration.

Views are not unit-tested. They are checked by hand in the simulator, against
`design/`, in light and dark, on iPhone and iPad, portrait and landscape.

## The agent workflow

Loop is built with a writer/reviewer split, and the split is the point.

- One agent **writes** a feature in its own worktree.
- A **different** agent, with its own context, reviews the diff against
  `design/` and against this file. It does not write the fix.
- Before anything reaches `main`, a **main-gate** agent — independent again —
  sees the full diff against `main` plus the resulting state of `main` as a
  whole, and checks: clean build, no avoidable warnings, no dead code, no
  leftover debug output, design fidelity a second time, formatting consistent
  with the rest of the repo, no AI attribution anywhere.
- Findings go **back to the writer**, never to the reviewer's own hands. The
  separation between writing and checking is the whole value; an agent that
  fixes what it just found has reviewed nothing.
- **Sub-agents never merge.** Only the owner merges to `main`.

Features that touch the same files are done **in sequence**, not in parallel.
Two agents in two worktrees editing `TimerEngine.swift` will silently overwrite
each other, and the loser is whoever pushes second. Check for file overlap
before parallelising anything.

## Commits

- Conventional Commits, description in **English**: `type(scope): description`.
  Scope optional but welcome.
- Types in use: `fix`, `feat`, `test`, `refactor`, `chore`, `design`, `docs`,
  `build`, `perf`, `security`, `revert`.
- The description says **what now holds**, not what was done. Anything
  non-obvious is justified in the body.
- **One commit = one logical change.** No collection commits, formatting never
  in the same commit as logic. Commit and push each small finished piece, not
  once at the end of a feature.
- **No tool trailers.** No `Co-Authored-By`, no "Generated with", no session
  IDs, no mention of AI tooling — not in commits, not in PR titles or bodies,
  not in code comments, not anywhere in the repo. This applies to every agent
  without exception.
- Rebased on current `main`, no merge commits in a PR.

## Branches

**Never commit directly to `main`** unless the owner says so explicitly.

Before every new branch:

```bash
git fetch --all --prune
```

If the base branch is behind its remote, pull first, then branch — otherwise the
PR sits on an old state and has to be rebased afterwards.

Branch names carry a prefix that says what it is about. Lowercase, hyphens,
specific: `feat/interval-skip-during-break`, not `feat/timer`.

| Prefix | For |
|---|---|
| `feat/` | New functionality |
| `fix/` | Bug fixes |
| `hotfix/` | Urgent fixes to a released version |
| `security/` | Security, hardening, permissions |
| `refactor/` | Restructuring without behaviour change |
| `perf/` | Runtime and memory |
| `design/` | Interface and styling |
| `feedback/` | Changes from review feedback |
| `ci/` | Automation, pipelines |
| `deps/` | Dependencies |
| `docs/` | Documentation only |
| `test/` | Tests only |
| `chore/` | Maintenance, tooling, configuration |
| `spike/` | Experiment, will be discarded |
| `release/` | Preparing a version |
| `revert/` | Undoing something |

**No `claude/` prefix** and no other prefix named after the tool being used. The
branch is named after the work, not after the hammer.

Each feature gets its own worktree, and **every worktree lives inside the
repository**, under `.worktrees/`:

```bash
git worktree add .worktrees/<feature-slug> -b feat/<feature-slug>
```

Never create a worktree as a sibling directory next to the repository. Nothing
belonging to this project is allowed to sit outside its folder — not a
worktree, not a scratch checkout, not a build directory. `.worktrees/` is in
`.gitignore`, so it never reaches a commit. Clean up with
`git worktree remove .worktrees/<feature-slug>` once the branch is merged, and
`git worktree list` should show only `main` when nothing is in flight.

Scratch files that are not a checkout go to `/tmp`, never into the repository.

**Push after every commit.** A branch that exists only on this machine is a
branch nobody can look at. The remote is the state of the work, not a place
things get uploaded to at the end.

## How Claude is used here

Claude is a tool in this repository: code review, boilerplate, structure,
a second pair of eyes on a design spec. It is not a substitute for
understanding. **Every change is understood and answered for before it is
merged** — if the owner cannot explain what a line does and why it is there, it
does not go in, no matter which tool produced it. That is the difference between
using a tool and vibe-coding, and it is the reason the reviewer is never the
writer.

Nothing in the repository mentions the tool. See "Commits".

## The repository is public

`github.com/levo-studio/loop` is public **now**, not later. Every commit that
lands on `main` is visible to everyone from that moment. There is no phase of
"quick and dirty first, tidy up later" — every change on `main` has to look like
it was always there.

## License context

Loop is source-available and **stricter than Score**: read, clone, build, run on
your own devices. **No distribution of any kind** — no App Store, no TestFlight,
no sideloading to third parties, no sale, no giving the build to anyone else.
Copyright stays with Levo Studio. Contributors keep authorship, grant Levo Studio
the usage rights, and are named in the credits.

Do not suggest a distribution path that the license does not allow, and do not
soften the license text to make one fit.

## None of this happens without asking

Ask first, then touch:

- **`DEVELOPMENT_TEAM` and the bundle identifier** in `Loop.xcodeproj`. Both
  hang off the owner's App Store access and never belong in a diff.
- **`Loop.xcodeproj/project.pbxproj`** for anything other than a deliberate
  build-setting change. Synchronized folders mean new files never need it.
- **Anything in `design/`.** The export is read-only. If the code and the design
  disagree, the code is wrong.
- **Adding a dependency.** Loop has none, and that is a feature.
- **Any network code.** There is none, on purpose.
- **Push to `main`.** Work happens on a branch, merging is the owner's call.
