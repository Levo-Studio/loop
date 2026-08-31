# Contributing

Loop is a study timer for iOS and iPadOS: five full-screen pages, swiped
horizontally, and exactly one progress indicator — an area that rises from the
bottom edge. Everything lives on the device. No backend, no account, no login,
no network code at all.

Contributions are welcome across the whole thing: bug fixes, features, UI work,
refactorings, documentation, tests. If an animation feels too hectic to you, a
hit area too small, a label unclear — those are good PRs.

## Why I would like this to become more than a one-person app

Loop exists because I wanted a timer that shows me a number and gets out of the
way, and every app I tried wanted an account first and a subscription second.
So I built the small one. Small is the point, and small is also the risk: it is
very easy for a project like this to stay a thing one person uses on one phone
and nobody ever looks at again.

I would rather it did not. A timer is a piece of software that gets used every
day, and things that get used every day are exactly where somebody else notices
what I stopped seeing after the third week — the button that is two points off,
the state that survives backgrounding on the iPhone and does not on the iPad,
the label that made sense to me and to nobody else. I cannot review my own
blind spots. That is what other people are for.

## Setup

You need **Xcode 26**. The project builds against **iOS/iPadOS 26.2** and uses
**Swift 6** with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — types are bound
to the main actor by default, and anything that should not be is explicitly
`nonisolated`. The engine is `nonisolated`, deliberately.

Clone it, open `Loop.xcodeproj`, build. That is the whole setup; there are no
dependencies to fetch, no package resolution, no generated files.

From the command line, `xcode-select` points at the CommandLineTools on many
machines, and those cannot build an iOS project. Either switch it permanently
or prefix each call:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Loop.xcodeproj -scheme Loop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO build
```

### Working without your own developer team

You need **none**. Loop has no entitlements, no capabilities and no container —
nothing that hangs off an App Store account. `CODE_SIGNING_ALLOWED=NO` builds
and runs the whole app in the simulator, and there is no feature that is missing
without a signature.

That also means `DEVELOPMENT_TEAM` and the bundle identifier
(`apps.levo-studio.Loop`) never belong in a diff. If Xcode writes them into
`Loop.xcodeproj` behind your back — it does that — take them back out before you
push.

## Project structure

```
Loop/
  Engine/        the timer core
  Core/Design/   LoopPalette, LoopTypography, LoopMetrics, LoopMotion
  Core/          settings, formatting, persistence
  Features/      one folder per screen, plus the shell
  Resources/     IBM Plex Mono, Localizable.xcstrings
LoopTests/       Swift Testing
design/          the design export — read-only
```

**`Loop/Engine/`** is the timer core: plain `Sendable` values and pure functions
over them, `nonisolated`, `import Foundation` and nothing else. No
`@Observable`, no `Color`, no `View`, no `import SwiftUI`. That is what makes it
testable in milliseconds without a simulator, and it stays that way. Time comes
from `Date` — a running timer stores the instant it ends and derives the rest.
Nothing in here counts ticks; a tick counter drifts, stalls in the background
and lies after a device sleep.

**`Loop/Core/Design/`** is the only source for colour, size and motion.
`LoopPalette` resolves every token for light and dark and all four accents,
`LoopMetrics` holds spacings and radii, `LoopTypography` the type scale,
`LoopMotion` the curves — including the central handling of *Reduce Motion*. A
value that is missing goes in here, not into the call site.

**`Loop/Core/`** holds settings, formatting and persistence. Persistence means
the stored instant and the user's choices, nothing more.

**`Loop/Features/`** is one folder per screen plus the shell that pages between
them. Feature files compose; they do not define values. The rising fill is one
component used by several screens — Countdown and Interval do not each grow
their own copy.

**`Loop/Resources/`** holds IBM Plex Mono and `Localizable.xcstrings`. Every
visible string lives in the catalog, which is maintained by hand
(`extractionState: manual`). No visible string sits as a literal in a view, and
there is no second language.

**`LoopTests/`** is Swift Testing. **`design/`** is read-only — see below.

The project uses synchronized folders: new files under `Loop/` and `LoopTests/`
join the target on their own. `Loop.xcodeproj/project.pbxproj` does not have to
be touched for that, and a diff that touches it without a build-setting reason
is a mistake.

## Design fidelity

This is the rule people break first, so it gets its own section.

**`design/` is the source of truth for every colour, size, spacing value, radius,
opacity, letter-spacing, line-height and state.** Not a mood board, not a
starting point. The export contains `Loop Design Notes.md` — the written spec —
and the `.dc.html` prototypes with every state in light and dark, portrait and
landscape, for all four accents. The HTML sizes are design points and transfer
1:1 to SwiftUI points.

Read it before the first line of code. Yes, also for a one-line change.

- Nothing is invented, rounded, or implemented "close enough". If the spec says
  a status pill is 11 pt with `.14em` letter-spacing and 8 % background, that is
  what it is.
- **If a value you need is not in the export, that is a question, not a gap to
  fill with taste.** Ask. I would much rather answer an email than review a
  screen built on a guess.
- `design/` is never edited to match the code. If the code and the design
  disagree, the code is wrong.

Two facts about the export, so nobody rediscovers them the hard way:

- `Loop iPhone Screens.dc.html` and `Loop iPad Screens.dc.html` were **cut off
  at 256 KiB** by the export tool. The portrait states are complete; the tail —
  landscape and the accent variants — is missing. `Loop Design Notes.md` covers
  what is missing and is authoritative where the HTML stops.
- Where the two disagree, **the HTML wins for pixel values**, because it is what
  was actually drawn. Concretely: the notes say landscape padding is `32/28/24`,
  the HTML renders landscape at `32/40/24`. Use **`32/40/24`**.

The export was written in German. The labels are translated to English —
`Uhr` → `Clock`, `bereit` → `ready`, `Fokus · Runde 02 / 04` →
`Focus · Round 02 / 04`. **Only the words change.** Geometry, weight,
letter-spacing, casing and colour do not move because the English word is longer.

## How a change happens

**Larger feature or restructuring:** open an issue first, then build. Not because
I like process, but because I would hate to tell you after two weeks of work
that I had pictured it differently.

**Small fix, typo, obvious bug:** straight to a PR, no issue needed.

A useful bug issue contains what happened and what you expected, both in one
sentence; step by step how to get there; the iOS version and device or simulator
model; whether it happens on iPhone, iPad or both; and a screenshot if it is
something you can see. "Doesn't work" is not reproducible, and I cannot fix what
I cannot reproduce.

From there: branch, small commits, PR, review, merge. I read every PR myself and
comment. Everything I raise gets closed before the merge — including the small
things, and including the ones where you talk me out of my position. Then I
merge to `main`.

## Branches

You work in your fork, but the same rule applies there: **not on `main`.** Keep
it clean so you can branch off it at any time without your own work in the way.

Pull once before every new branch, otherwise your PR sits on the state of the
day before yesterday and you rebase afterwards:

```bash
git fetch --all --prune
```

The name carries a prefix that says what it is about. Lowercase, hyphens,
specific. `feat/interval-skip-during-break` says something, `feat/timer` says
nothing.

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

No prefix named after the tool you used — no `claude/`, no `codex/`. **The
branch is named after the work, not after the hammer.** A branch name is read by
the next person trying to find where something happened, and "which editor was
open" is not what they are looking for.

One branch, one topic. If a larger piece turns up mid-way that stands on its
own, open a branch for it. Two topics in one PR mean I have to accept or reject
both together.

## Commits

**Conventional Commits, description in English:** `type(scope): description`.
Scope optional but welcome. Types in use here: `fix`, `feat`, `test`,
`refactor`, `chore`, `design`, `docs`, `build`, `perf`, `security`, `revert`.

The description says **what now holds**, not what you did. Anything non-obvious
gets its reason in the body.

**One commit = one logical change.** No collection commits, no "fix stuff", and
formatting never in the same commit as logic. If you straighten an indentation
while reading a file: separate commit.

**No tool trailers.** No `Co-Authored-By`, no "Generated with", no session IDs,
no mention of any tool — not in commits, not in PR titles or bodies, not in code
comments, not anywhere in this repository. If something helped you write it:
good, that is your business and it does not belong in the history.

Rebased on current `main`, no merge commits in the PR.

## Tests

They live in `LoopTests/` and use **Swift Testing** (`@Test`, `@Suite`,
`#expect`), not XCTest.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Loop.xcodeproj -scheme Loop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

**The engine is where the tests live.** It is pure, `Date`-based and injectable,
so there is no excuse. Things worth testing, concretely:

- block transitions in Interval — focus to break, break to the next focus
- **no break after the last round**, and the finished state that follows it
- **skip is legal only during a break**, and does nothing during focus
- a resume after two hours in the background, where a tick counter would lie
- the fill fraction at a block boundary — it lands on 1, then starts again at 0
- countdown reaching zero exactly, and not one frame past it

**Every fix ships with a test that fails without it**, and the counter-check is
mandatory: pull the fix out, watch the test go red, put it back, watch it go
green. A regression test nobody has ever seen fail is decoration.

A red run does not get merged, not even when the red test "was already weird
before". If a test is genuinely wrong, fix it in its own commit and write down
why it was wrong.

**Views are not unit-tested.** They are checked by hand in the simulator against
`design/`: light and dark, iPhone and iPad, portrait and landscape. All four,
every time a screen changes. For a pure spacing change a screenshot in the PR is
enough.

## Code style

**Nothing enforces style** — no SwiftLint, no SwiftFormat, no `.editorconfig`.
So match the file you are editing.

- **Four spaces**, no tabs.
- `// MARK: -` in any file with more than one type or more than a handful of
  functions.
- **No numeric or colour literals outside the design layer.** No `.padding(17)`,
  no `Color(red:...)`, no hand-rolled `timingCurve` in a feature file. A missing
  value goes into `LoopMetrics`, `LoopPalette`, `LoopTypography` or `LoopMotion`.
- No `print`, no `debugPrint`, no commented-out leftovers, no `TODO` without a
  name and a reason beside it. Preferably no `TODO` at all.
- **Formatting is never in the same commit as logic.**

## Comments

Comments explain the **why**, not the what. A comment describing what the line
below it does is wasted. One explaining why it is not the obvious approach saves
the next person half a day — whole paragraphs above a single constant are
deliberate here, not an accident.

**A comment that promises something the code does not do is worse than no
comment**, because people believe it and stop reading the code underneath. If
you change behaviour, pull the comments along — including the ones in
neighbouring files that repeat the same promise.

## Documentation belongs to the change

Two files describe what Loop is. Whoever changes the behaviour changes them in
the **same PR**, not afterwards:

| File | When it is due |
|---|---|
| [`README.md`](README.md) | When something changes that the README states: a feature, the architecture rules, the build commands, numbers. |
| `CONTRIBUTING.md` | When how you contribute changes — a new dependency, a new test command, a new structure. |

Documentation nobody pulls along is worse than none after three months, because
by then people believe it. For pure bug fixes and refactorings usually nothing
is due. When in doubt, one line too many.

## How Claude is used here

Claude is a tool in this repository: code review, boilerplate, structure, a
second pair of eyes on a design spec. That is all it is, and I would rather say
so plainly than have you guess whether it is frowned upon here.

**It is not a substitute for understanding.** Every change is understood and
answered for before it is merged. If I cannot explain what a line does and why
it is there, it does not go in — no matter which tool produced it, including
when the tool is me at one in the morning. That is the difference between using
a tool and vibe-coding, and it is the same bar I hold your PRs to: you open it,
you stand behind it, you can explain every line in it — including the ones you
did not type yourself.

What I do not want are PRs that visibly nobody read. Half-fitting comments,
tests that assert nothing, code that happens to go green. The tool is not my
business; the result is.

There is a [`CLAUDE.md`](CLAUDE.md) in the repository with the project rules —
engine without a view, `Date` instead of ticks, the design layer as the only
source for colour, size and motion. If you work with a tool that reads it, point
it at `CLAUDE.md`, `CONTRIBUTING.md` and `README.md` before it touches anything.
That costs you one sentence and saves you the round where you straighten out
literals afterwards.

And: **nothing in this repository mentions the tool.** No attribution in
commits, in PR text, in comments or in files. See "Commits".

## Hard rules

> A PR that breaks these is closed without a discussion of its contents. Not out
> of pedantry: I read every PR myself, in my own time. A contribution where I
> first have to sort commits apart costs me more time than writing it myself.

1. **Small single commits.** One commit = one logical change. Formatting never
   together with logic.
2. **No tool trailers, no AI attribution**, anywhere in the repository.
3. **Conventional Commits, in English.** The description says what now holds.
4. **Values come from `design/`.** Nothing invented, nothing rounded, nothing
   "close enough".
5. **No numeric or colour literals outside the design layer.**
6. **A fix ships with a test that fails without it**, counter-checked.
7. **No red tests.** A run that is not green is not delivered.
8. **No dependency, no network code** — ask first, both of them are deliberate
   absences.
9. **No changes to `Loop.xcodeproj/project.pbxproj`** you did not intend, and
   never `DEVELOPMENT_TEAM` or the bundle identifier.
10. **Nothing in `design/` is edited.** The export is read-only.
11. **Documentation pulled along in the same PR.**
12. **Rebased on current `main`, no merge commits.**
13. **Review your own PR before I see it** — no commented-out remains, no
    `print`, no unused files, no formatting outside the scope.

## Credits

Once your PR is merged you add yourself to the [credits in the
README](README.md#credits) — **in the same PR as the contribution**, not as a
separate "add me" PR afterwards. The rules there are not negotiable:

- **One row, one contribution.** No paragraphs, no logos, no banners, no
  company links.
- **The entry goes in the same PR as the contribution.**
- **Only what is actually in.** One line, not an essay.
- **GitHub handle instead of an email address.** No private contact details,
  neither yours nor anyone else's.
- **Not an advertising slot.** No own products, agencies, services or crypto
  projects. A link to your GitHub profile is the link you get.
- **No other people's names.** You add yourself, nobody else.

An entry that ignores this gets removed without comment.

## License

Loop is **source-available and strict** (see [`LICENSE`](LICENSE)). Reading,
changing, building and running it on your own devices is allowed. **Distribution
is not — in any form.** Not the App Store, not any other store, not TestFlight
including your own, not sideloading to third parties, not handing a compiled
build to anyone. No sale and no transfer for money. No presenting yourself as
the author or provider of Loop, and no use of the name, the mark, the logo, the
app icon or the visual design for your own product. Loop is and stays a product
of Levo Studio.

With a PR you grant Levo Studio the right to use your contribution in the
project and in the published app, including future versions. Your authorship
stays yours and you are named in the [credits](README.md#credits). That is the
deal, and it holds in both directions.

Please do not propose a distribution path the license does not allow, and please
do not ask me to soften the text so one fits.

## Contact

Questions, ideas, or uncertainty about whether something is worth it:
**julius@levo-studio.com**

Better to ask once too often than to build two weeks in the wrong direction.
