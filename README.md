# Loop

Study timer for iOS and iPadOS 26 · SwiftUI

[**Case study**](https://juliusgrimm.dev/projects/loop) ·
[Contributing](CONTRIBUTING.md) ·
[Building](#building-and-testing)

---

Loop is not a timer with forty screens and an onboarding flow. It is a number
and a button.

Somewhere along the way study timers turned into wellness products. You get
streaks, badges, a forest that dies when you check your messages, a weekly
report on your "focus score", and a subscription so the forest keeps growing.
None of that measures time. Loop shows the time and fills a rectangle. When the
rectangle is full, the block is over. That is the entire product.

Everything lives on the device. No backend, no account, no login, no network
code at all. There is nothing to sync, so there is nothing to leak.

|  |  |
|---|---|
| **Engine** | `Date`-based, `nonisolated`, no SwiftUI import, no ticks counted |
| **Storage** | On device, no backend, no account, no network code |
| **Tests** | Swift Testing, not XCTest. Engine coverage is coming, not counted yet. |
| **Language** | English, string catalog maintained by hand |
| **License** | Source-available — read, build, run. No distribution, bar a source-only fork. |

How it came about, why it looks the way it does and what got cut is in the
**[case study](https://juliusgrimm.dev/projects/loop)**.

## Features

Five full-screen pages, swiped horizontally. No tab bar, no title bar, no
buttons to switch modes — five dots at the bottom and that is the navigation.

1. **Clock** — the current time, seconds optional, weekday and date underneath.
2. **Count-up** — a stopwatch. Idle, running, paused. No fill, because there is
   no total duration and therefore no progress to show.
3. **Countdown** — one duration, set on a scale from 0 to 60 minutes, counted
   down.
4. **Interval** — focus and break blocks over a number of rounds, with a status
   pill that says which block you are in and which round of how many.
5. **Settings** — the seconds toggle and four accents: Petrol, Amber, Lilac,
   Graphite. One hue each; light and dark use two lightnesses of it, never two
   different colours.

### One progress indicator

There is exactly **one** progress indicator in this app: a solid area that rises
from the bottom edge, its height proportional to elapsed time over the duration
of the *current* block. No rings, no bars, no dots, no segments, no second
opinion. Interval uses the same fill for focus and for break — only the status
pill and the round counter change.

Anything crossing the fill edge — the time, the labels, the buttons, the
navigation dots — is **two-toned**: ink above the edge, the on-fill tone below
it. The on-fill tone is not a lookup table but a rule, so it stays correct for
an accent nobody has added yet.

Two behaviours that are decisions, not omissions:

- **Interval has no break after the last round.** Focus, break, focus, break,
  and after the final focus block it goes straight to the finished screen.
  A break you are not going to take is not a break.
- **Skip only works during a break.** During a focus block the button is
  visible but disabled — it does not disappear, so the layout stays still. A
  focus block is not skippable. That is the point of a focus block.

## Architecture

Four rules hold this project up, and each one exists because the obvious
alternative went wrong somewhere else first.

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
else: plain `Sendable` values and pure functions over them. No `@Observable`,
no `Color`, no `View`, no `import SwiftUI`. That is what makes the timer
testable in milliseconds without a simulator, and it stays that way.

**Time comes from `Date`, never from counting ticks.** A running timer stores
the instant it will end — or the one it started at — and every frame derives the
displayed value from `Date.now`. A display timer that increments a counter
drifts, stalls in the background and lies after a device sleep. State survives a
restart because the stored instant survives, not because something kept
counting.

**Colour, size and motion come only from the design layer.** `LoopPalette`
resolves every token for light and dark and for all four accents, `LoopMetrics`
holds spacings and radii, `LoopTypography` the type scale, `LoopMotion` the
curves. No `.padding(17)` and no `Color(red:...)` in a feature file. *Reduce
Motion* is handled centrally in `LoopMotion` — spread over a hundred call sites
it would be forgotten at ninety of them.

**The fill is one component.** Countdown and Interval are the two screens with a
total duration and therefore the only two with a progress to show, and they do
not each grow their own copy of the rising area and the two-tone text. There is
one implementation and the screens hand it a fraction.

Loop has no dependencies, and that is a feature.

## Building and testing

You need **Xcode 26**. `xcode-select` points at the CommandLineTools on many
machines, and those cannot build an iOS project. Either switch it permanently
(`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`) or prefix
each call:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Loop.xcodeproj -scheme Loop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO build
```

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project Loop.xcodeproj -scheme Loop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

`CODE_SIGNING_ALLOWED=NO` means **you do not need a developer team** to build
Loop. There are no entitlements, no capabilities and no container hanging off
someone's App Store access, so nothing has to be signed to run in the simulator.
`DEVELOPMENT_TEAM` stays out of every diff.

### Building to a device

The repository is public, so no development team is stored in the project at
all. Nothing above needs one. Running Loop on a physical iPhone or iPad does,
and Xcode would otherwise write the team you pick straight back into
`project.pbxproj`. So it lives outside the project instead: copy
`Local.xcconfig.example` to `Local.xcconfig`, put your own Team ID in, and
build. `Local.xcconfig` is ignored by git and cannot end up in a commit.

The project uses synchronized folders — new files under `Loop/` and
`LoopTests/` join the target on their own, and
`Loop.xcodeproj/project.pbxproj` does not have to be touched for that.

## Contributing

How a contribution should look, what a useful issue contains, what the commits
have to look like and what `design/` being the source of truth means in
practice: **[CONTRIBUTING.md](CONTRIBUTING.md)**.

Short version: small single commits, tests with the fix, and every value taken
from the design export rather than from taste.

## Credits

**Creator and maintainer**

[**Julius Grimm**](https://github.com/justthatrandomcoder) — idea, design,
engine. [Levo Studio](https://levo-studio.com)

**Contributors**

<!-- Please append new rows at the bottom, alphabetical by name.
     Format: | Name | @github | What | PR | -->

| Name | GitHub | Contribution | PR |
|---|---|---|---|
| _nobody yet — be the first row_ | | | |

Once your PR is merged you may add yourself here. There are rules for that, and
they are not negotiable:

- **One row, one contribution.** No paragraphs, no logos, no banners, no
  company links.
- **The entry goes in the same PR as the contribution**, not as a separate
  "add me" PR.
- **Only what is actually in.** The contribution is described in one line, not
  in an essay: "interval skip", "fix in the fill fraction", "accessibility of
  the nav dots".
- **GitHub handle instead of an email address.** No private contact details,
  neither yours nor anyone else's.
- **Not an advertising slot.** No links to your own products, agencies,
  services or crypto projects. A link to your GitHub profile is the link you
  get.
- **No other people's names.** You add yourself, nobody else.

An entry that ignores this gets removed without comment. Otherwise: whoever is
listed here contributed something that people use on their devices. That is the
point.

## License

Source-available, and stricter than it looks. Read the code, clone it, change
it, build it and run it on devices you own. That is the whole of it.

**No distribution, with one narrow exception.** Not the App Store, not any other
store, not TestFlight — not even your own — not sideloading to somebody else,
not handing a compiled build to a friend. No sale and no transfer for money. No
presenting yourself as the author or provider of Loop, and no use of the name
"Loop", the Levo Studio mark, the logo, the app icon or the visual design for
your own product. Loop is and stays a product of Levo Studio.

The exception is the one contributing needs: a **source-only public fork** on a
code-hosting platform, with the notices left intact, for preparing a
contribution or for your own use. Source code, not builds — a compiled binary
still goes to nobody. The conditions are in section 3 of the license.

None of that binds Levo Studio, which holds the rights and keeps them: if Loop
is ever released, it is released by Levo Studio. Anyone contributing by pull
request grants Levo Studio the rights to use the contribution in the project and
in any such release — but keeps their authorship and is named in the
[credits](#credits).

The full text is in [`LICENSE`](LICENSE). Read section 3 before you suggest
anything involving a store, TestFlight or sideloading.

© 2026 Levo Studio
