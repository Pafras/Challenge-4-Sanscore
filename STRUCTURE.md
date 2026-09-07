# Sanscore — Team Structure

iOS + watchOS app. One Xcode project, three targets (iOS app, Watch app, Shared).

## Ownership

| Folder            | Target        | Owner        |
|-------------------|---------------|--------------|
| `SanscoreiOS/`    | iOS app       | Coder A (me) |
| `Shared/`         | both          | Coder A (me) |
| `SanscoreWatch/`  | watchOS app   | Coder B + C  |
| `Design/`         | assets        | Designer     |

**Rule: own your folder.** No editing another owner's folder without asking. Cuts `project.pbxproj` merge conflicts.

`Shared/` is the contract. Coder A owns the data structs phone↔watch pass. B+C build watch UI against them, never invent their own. Need a model change? Tell A → A changes `Shared/` → pull `dev`.

## Folder map

```
SanscoreiOS/     iOS app        App/ Views/ ViewModels/ Resources/
SanscoreWatch/   watchOS app    App/ Views/ ViewModels/ Resources/
Shared/          both targets   Models/ Connectivity/ Services/ Extensions/
Design/          designer       exports/
```

Shared files: in Xcode File Inspector → Target Membership → check **both** iOS + Watch.

## Branch flow

```
main   protected. release only. merge via PR, 1 approval.
 └ dev  integration. branch off here, merge back here.
    ├ feat/ios-*      Coder A
    ├ feat/shared-*   Coder A
    ├ feat/watch-*    Coder B / C
    └ design/*        Designer
```

Per task:
```
git checkout dev && git pull
git checkout -b feat/ios-login
# work, commit
git push -u origin feat/ios-login
# open PR -> dev, teammate reviews, merge
```

## Conflict rules

- Pull `dev` often. Small PRs, merge daily. Stale branch = worse `.pbxproj` conflict.
- `.pbxproj` conflict: keep both sides, reopen Xcode, verify build. Never hand-delete lines.
- One screen = one file. Big files = merge pain.
- B + C: never edit same file same time. Split by folder or pair-program one branch.
- Asset / color / SF Symbol names: designer defines, coders use exact names. No solo rename.
