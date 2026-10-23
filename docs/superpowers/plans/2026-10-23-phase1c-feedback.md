# 1-bosqich C — Foydalanuvchi fikrlari Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 1B ilovasiga 7 ta talabni qo'shish: Esc bilan belgilarni olish, Copy To…/Move To… dialogi (New Folder bilan), yashirin fayllarni xira ko'rsatish, drag & drop manzilini ko'rsatish va spring-loading (qatorlar, "↑" chizig'i, breadcrumbs, tablar), ishga tushgandagi papkalar, bitta panel rejimi, `⇧⌘⌫` butunlay o'chirish, `⌥Space` papka hajmi.

**Architecture:** 1B arxitekturasi saqlanadi: mantiq `CommanderController` da (`swift test` bilan TDD), AppKit tomoni faqat ko'rsatadi. Yangi buyruqlar Core'dagi `Command` + `KeyBindings` orqali; yangi yon ta'sirlar `WindowEffects` protokoli orqali (testda `RecordingEffects`). Papka hajmi FileSystem'dagi yangi `FolderSize` bilan, `listingExecutor` da.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing, AppKit, SwiftUI (Copy To dialogi, Settings), XcodeGen, XCUITest.

**Spec:** `docs/superpowers/specs/2026-10-23-phase1c-feedback-design.md` (asos: `docs/superpowers/specs/2026-10-21-phase1-core-design.md`)

## Global Constraints

- 1B plan'ining Global Constraints'i to'liq amal qiladi (`docs/superpowers/plans/2026-10-22-phase1b-app-ui.md`): Core/FileSystem/Controller AppKit import qilmaydi; har harakat `Command` → `WindowModel.perform`; fayl ishlari `OperationExecutor` da; UI matnlari inglizcha.
- Branch: `phase1c-feedback`, `phase1b-app-ui` uchidan (1B hali `main` ga merge qilinmagan).
- Default tugmalar: Unmark All `escape`; Copy To… `opt+f5`; Move To… `opt+f6`; Delete Immediately… `cmd+shift+backspace`; Calculate Size `opt+space`; Single Pane `cmd+\`. Mavjud default'lar o'zgarmaydi.
- Spring-loading kechikishi 0,7 s. Recent manzillar — 10 ta.
- Test buyruqlari: `swift test --package-path Packages/CommanderKit` (hammasi yashil qolishi kerak); App: `xcodegen generate && xcodebuild test -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64'`.
- Foydalanuvchining clipboard'iga tegadigan avtomatik test yozilmaydi.

## Review Focus

1. **Matn maydonida `Esc`** (path field, rename, Copy To dialogi) — belgilarni olib tashlamasligi, faqat tahrirni bekor qilishi kerak. → Task 2 `escapeInTextFieldDoesNotUnmark`.
2. **Hajm hisoblash paytida papkadan chiqib ketish yoki ⌘R** — kechikkan natija boshqa papka elementlariga yozilmasligi, footer'dagi hisob to'xtashi kerak. → Task 3 `navigatingAwayCancelsAndClearsSizes`.
3. **Copy To'da manzil manbaning o'zi yoki ichida** (`/a` → `/a/sub`) — amal boshlanmasligi, beep. → Task 4 `copyToIntoItselfIsRefused`.
4. **Bitta panel rejimida F5** — yashirin o'ng panelga emas, dialog orqali ko'chirishi kerak. → Task 5 `singlePaneF5AsksForDestination`.
5. **Spring-loading bilan sudralayotgan papkaning o'ziga kirish** — manba papkaga kirib unga o'zini tashlash `.none` bo'lishi kerak. → Task 6 `dropIntoDraggedFolderAfterSpringLoadIsNone`.

---

## Fayl tuzilmasi

```
Packages/CommanderKit/Sources/
  CommanderCore/Command.swift              # + unmarkAll, copyTo, moveTo, deleteImmediately, calculateSize, toggleSinglePane
  CommanderCore/KeyBindings.swift          # + default'lar
  CommanderCore/Session.swift              # + recentDestinations, singlePane, addRecentDestination
  CommanderCore/Settings.swift             # + BehaviorSettings.launchLeftFolder / launchRightFolder
  CommanderFileSystem/FolderSize.swift     # yangi: papka hajmini o'lchash (cancel bilan)
  CommanderController/Command+Title.swift  # + yangi nomlar
  CommanderController/Environment.swift    # WindowEffects: askDestination → chooseDestination(DestinationRequest), + confirmDeleteImmediately
  CommanderController/WindowModel+Sizes.swift        # yangi: calculateSizes, folderSize(_:_:), sizeProgress, cancelSizeCalculation
  CommanderController/WindowModel+Destinations.swift # yangi: DestinationRequest, copyTo/moveTo oqimi, createFolder(in:), createDirectory(at:)
  CommanderController/WindowModel+DragTargets.swift  # yangi: springLoad, openFolder, drop(_:to:), Breadcrumbs
  CommanderController/WindowModel+Commands.swift / +Files.swift / +Mouse.swift / WindowModel.swift / Texts.swift / Bootstrap.swift
App/
  Dialogs/CopyToView.swift                 # yangi: SwiftUI sheet
  Dialogs/AlertPrompts.swift               # + chooseDestination, confirmDeleteImmediately
  Pane/BreadcrumbBar.swift                 # yangi: segmentlar + drop/spring
  Pane/SpringLoader.swift                  # yangi: 0,7 s hover taymeri
  Pane/ParentDropStrip.swift               # yangi: "↑ Enclosing folder"
  Pane/PaneViewController.swift, FileTableController.swift, FileRowView.swift, TabBarView.swift
  PanesViewController.swift, Window/SelectionBarView.swift, Window/FooterView.swift, MainMenu.swift, System/AppKitEffects.swift
  Settings/BehaviorView.swift, Settings/AppearanceView.swift
AppUITests/SmokeTests.swift
```

---

### Task 1: Core — yangi buyruqlar, tugmalar, session va settings maydonlari

**Files:**
- Modify: `Sources/CommanderCore/Command.swift`, `KeyBindings.swift`, `Session.swift`, `Settings.swift`; `Sources/CommanderController/Command+Title.swift`
- Test: `Tests/CommanderCoreTests/KeyBindingsTests.swift`, `SettingsCodingTests.swift` (mavjud fayllarga qo'shiladi); `Tests/CommanderControllerTests/KeyChordDisplayTests.swift` (`everyCommandHasTitle` yangi case'larni avtomatik qamraydi)

**Interfaces:**
- Produces:
  ```swift
  // Command: yangi case'lar
  case unmarkAll, copyTo, moveTo, deleteImmediately, calculateSize, toggleSinglePane
  // isAllowedInTextField: toggleSinglePane → true; qolgan yangilari → false
  // Session
  public var recentDestinations: [URL] = []      // eng yangisi birinchi, 10 ta
  public var singlePane = false
  public mutating func addRecentDestination(_ url: URL)   // standardized yo'l bo'yicha takrorsiz
  // BehaviorSettings (restoreTabsOnLaunch == false bo'lganda ishlatiladi; nil = Home)
  public var launchLeftFolder: URL? = nil
  public var launchRightFolder: URL? = nil
  ```
- Titles: unmarkAll "Unmark All" · copyTo "Copy To…" · moveTo "Move To…" · deleteImmediately "Delete Immediately…" · calculateSize "Calculate Size" · toggleSinglePane "Single Pane".

- [ ] **Step 1: Failing testlar**

```swift
// KeyBindingsTests
@Test func phase1cDefaults()     // escape → .unmarkAll; opt+f5 → .copyTo; opt+f6 → .moveTo; cmd+shift+backspace → .deleteImmediately; opt+space → .calculateSize; "cmd+\\" → .toggleSinglePane; cmd+a → .markAll, cmd+backspace → .moveToTrash (o'zgarmagan)
@Test func escapeIsNotATextFieldCommand()   // command(for: escape, in: .textField) == nil; cmd+\ in .textField == .toggleSinglePane
// SettingsCodingTests
@Test func sessionRecentDestinationsAndSinglePaneRoundTrip()   // encode/decode; eski JSON (maydonlarsiz) → [] va false
@Test func addRecentDestinationDedupesAndCaps()  // 12 ta qo'shish → 10 ta, eng yangisi birinchi; "/x/../y" va "/y" bitta
@Test func launchFoldersDecodeLeniently()        // eski behavior JSON → nil, nil; URL bilan round-trip
```

- [ ] **Step 2: Run** `swift test --package-path Packages/CommanderKit --filter "KeyBindingsTests|SettingsCodingTests|KeyChordDisplayTests"` → FAIL.
- [ ] **Step 3: Implement qilish** (yangi maydonlar mavjud `c.value(_:default:)` uslubida dekodlanadi).
- [ ] **Step 4: Run** → PASS; to'liq `swift test` → PASS.
- [ ] **Step 5: Commit** — `Add phase 1C commands, default keys and session fields`

---

### Task 2: Unmark All (Esc) va Delete Immediately (⇧⌘⌫)

**Files:**
- Modify: `Sources/CommanderController/Environment.swift`, `WindowModel+Commands.swift`, `WindowModel+Files.swift`, `WindowModel+Mouse.swift`; `Tests/CommanderControllerTests/Fakes.swift`
- Test: `Tests/CommanderControllerTests/Phase1CCommandTests.swift`

**Interfaces:**
- Produces:
  ```swift
  // WindowEffects (protokolga qo'shiladi)
  func confirmDeleteImmediately(_ urls: [URL]) async -> Bool
  ```
- `perform(.unmarkAll)` → faol tab `clearMarks()`. `isEnabled(.unmarkAll)` → `!marked.isEmpty`.
- `perform(.deleteImmediately)` → targets bo'sh bo'lmasa `track { if await effects.confirmDeleteImmediately(urls) { operations.start(.delete(urls)); clearMarks } }`. `isEnabled` — targets bo'sh emas.
- Kontekst menyu (fayl ustida): `Move to Trash` dan keyin `Delete Immediately…`. `RecordingEffects`: `deleteAnswer: Bool`, `deleteRequests: [[URL]]`.

- [ ] **Step 1: Failing testlar**

```swift
@Test func escapeUnmarksAll()                     // 2 ta belgilangan → handleKey(escape, .table) == true → marked bo'sh
@Test func escapeWithNothingMarkedIsNotHandled()  // handleKey(escape, .table) == false
@Test func escapeInTextFieldDoesNotUnmark()       // handleKey(escape, .textField) == false, belgilar saqlangan
@Test func deleteImmediatelyAsksThenDeletes()     // FileHarness: deleteAnswer true → fayl yo'q, trasher.trashed bo'sh, deleteRequests == [[url]]
@Test func declinedDeleteImmediatelyKeepsFiles()
@Test func contextMenuListsDeleteImmediately()    // moveToTrash'dan keyin, shortcut "⇧⌘⌫"
```

- [ ] **Step 2: Run** `--filter Phase1CCommandTests` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS; to'liq `swift test` → PASS.
- [ ] **Step 5: Commit** — `Add Esc to unmark all and Delete Immediately`

---

### Task 3: Papka hajmi (Calculate Size)

**Files:**
- Create: `Sources/CommanderFileSystem/FolderSize.swift`, `Sources/CommanderController/WindowModel+Sizes.swift`, `Tests/CommanderFileSystemTests/FolderSizeTests.swift`, `Tests/CommanderControllerTests/SizeTests.swift`
- Modify: `CopyOperation.swift` (`CopyRun.totals` o'rniga `FolderSize`), `WindowModel.swift` (stored: `folderSizes: [String: Int64]`, `sizeTask`, `sizeProgressState`; `locationChanged` va `reload` shu panel natijalarini tozalaydi va hisobni bekor qiladi), `Texts.swift`, `WindowModel+Commands.swift`, `WindowModel+Mouse.swift` (kontekst menyu: `Copy Name` dan keyin `Calculate Size`)

**Interfaces:**
- Produces:
  ```swift
  public enum FolderSize {
      /// Fayllar va baytlar, symlink'lar kuzatilmaydi; isCancelled true bo'lsa nil.
      public static func measure(_ url: URL, isCancelled: () -> Bool) -> (files: Int, bytes: Int64)?
  }
  public struct SizeProgress: Equatable, Sendable { public let done: Int; public let total: Int }
  extension WindowModel {
      public func folderSize(_ side: PaneSide, _ item: FileItem) -> Int64?   // hisoblangan bo'lsa
      public var sizeProgress: SizeProgress? { get }                         // hisob ketayotganda
      public func cancelSizeCalculation()
  }
  extension PaneText { public static func status(_ tab: TabState, folderSizes: [String: Int64]) -> String }  // eski status(_:) = folderSizes: [:]
  public enum SizeText { public static func progress(_ p: SizeProgress) -> String }   // "Calculating size… 2 of 5 folders"
  ```
- `perform(.calculateSize)`: maqsad — belgilangan navigable/package elementlar, bo'lmasa kursordagi (navigable yoki package bo'lsa); bo'sh → beep. Har papka `listingExecutor.run` da, `Task.isCancelled` orqali to'xtaydi; har natijadan keyin `stateDidChange(.pane(side))` va `.operations` (footer). Kalit — `url.standardizedFileURL.path`; natija faqat hisob boshlangan papka hali o'sha panelda ochiq bo'lsa yoziladi.
- `isEnabled(.calculateSize)` — targets ichida navigable/package bor.

- [ ] **Step 1: Failing testlar**

```swift
// FolderSizeTests (TempDir)
@Test func measuresNestedFilesWithoutFollowingSymlinks()  // a/1(3 B), a/b/2(5 B), a/link → /usr → (2, 8)
@Test func cancelledMeasurementReturnsNil()
// SizeTests (FileHarness: "dir/" ichida 2 fayl × 3 B)
@Test func calculateSizeFillsFolderSize()            // perform(.calculateSize), kursor "dir" → waitUntilIdle → folderSize == 6; sizeProgress == nil
@Test func statusIncludesCalculatedFolders()          // dir belgilangan → status "… · 1 marked · B(6)"
@Test func progressText()                             // SizeText.progress(SizeProgress(done: 2, total: 5)) == "Calculating size… 2 of 5 folders"
@Test func navigatingAwayCancelsAndClearsSizes()      // hisobdan keyin navigate → qaytish → folderSize nil; hisob paytida navigate → sizeProgress nil, natija yozilmagan
@Test func calculateSizeOnFileOnlyBeeps()             // kursor fayl, belgisiz → effects.beeps == 1
```

- [ ] **Step 2: Run** `--filter "FolderSizeTests|SizeTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS; to'liq `swift test` → PASS.
- [ ] **Step 5: Commit** — `Calculate folder sizes on demand in the background`

---

### Task 4: Copy To… / Move To… (Controller)

**Files:**
- Create: `Sources/CommanderController/WindowModel+Destinations.swift`, `Tests/CommanderControllerTests/DestinationTests.swift`
- Modify: `Environment.swift` (`askDestination` o'rniga `chooseDestination`), `WindowModel+Files.swift` (F5/F6 "Ask for destination" shu oqimdan), `WindowModel+Commands.swift`, `WindowModel+Mouse.swift` (kontekst menyu: `Move to Other Pane` dan keyin `Copy To…`, `Move To…`), `Fakes.swift`, mavjud `FileCommandTests.askDestinationUsesAnswer` yangi API'ga

**Interfaces:**
- Produces:
  ```swift
  public struct DestinationRequest: Equatable, Sendable {
      public let kind: OperationKind          // .copy / .move
      public let count: Int
      public let suggested: URL               // ikki panelda — boshqa panel; bitta panelda — recent.first ?? joriy papka
      public let recent: [URL]
      public let tabs: [URL]                  // ikkala panel tablari, takrorsiz, manbaning joriy papkasi bundan mustasno
      public let favorites: [URL]
  }
  // WindowEffects
  func chooseDestination(_ request: DestinationRequest) async -> URL?
  extension WindowModel {
      public func createFolder(in directory: URL) async throws -> URL          // FileActions.createFolder, listingExecutor'da
      public func createDirectory(at url: URL) async throws                    // oraliq papkalari bilan
      public func folderSuggestions(for text: String) -> [String]              // autocomplete: ota papkadagi prefiks bilan boshlanuvchi papkalar, 10 tagacha, katta-kichik farqsiz
  }
  ```
- Oqim: `perform(.copyTo/.moveTo)` → targets bo'sh → beep; `track { url = await effects.chooseDestination(req) }` → `nil` → hech narsa; manzil biror manbaning o'zi yoki ichida bo'lsa → beep, amal yo'q; aks holda `operations.start`, `session.addRecentDestination(url)`, `publishSession()`, belgilar tozalanadi.
- Yo'q papka uchun "Create & …" savoli App dialogida; App `createDirectory(at:)` ni chaqirib, so'ng URL'ni qaytaradi (Controller mavjud papkani kutadi).

- [ ] **Step 1: Failing testlar**

```swift
@Test func copyToUsesChosenFolderAndRemembersIt()   // destinationAnswer = other → right'ga emas, other'ga; recentDestinations.first == other
@Test func moveToMovesAndClearsMarks()
@Test func cancelledChoiceDoesNothing()
@Test func requestListsRecentTabsFavorites()        // ikki tab + favorites → request.tabs takrorsiz, manba papkasi yo'q; suggested == right
@Test func copyToIntoItselfIsRefused()              // "sub/" ni sub/inner ga → beeps == 1, operations bo'sh
@Test func createFolderInDestination()              // createFolder(in: other) → "untitled folder", mavjud
@Test func createDirectoryMakesIntermediates()      // a/b/c
@Test func folderSuggestionsMatchPrefix()           // "…/left/s" → ["sub"]
@Test func askDestinationSettingUsesSameDialog()    // askDestinationForCopyMove + F5 → chooseDestination chaqirilgan, kind .copy
```

- [ ] **Step 2: Run** `--filter "DestinationTests|FileCommandTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS; to'liq `swift test` → PASS.
- [ ] **Step 5: Commit** — `Add Copy To and Move To with recent destinations`

---

### Task 5: Bitta panel rejimi va ishga tushgandagi papkalar (Controller)

**Files:**
- Modify: `WindowModel.swift` (`public var isSinglePane: Bool { session.singlePane }`), `WindowModel+Commands.swift`, `WindowModel+Files.swift`, `Environment.swift` (`WindowState.restored`), `Bootstrap.swift`
- Test: `Tests/CommanderControllerTests/SinglePaneTests.swift`, `RestoreTests.swift`

**Interfaces:**
- `perform(.toggleSinglePane)`: `session.singlePane.toggle()`; yoqilganda `activate(.left)`; `stateDidChange(.window)`, `publishSession()`.
- Bitta panelda: `isEnabled(.switchPane) == false`; `perform(.copyToOtherPane)` → `.copyTo` oqimi, `.moveToOtherPane` → `.moveTo`; `activate(.right)` e'tiborsiz.
- `WindowState.restored`: `restoreTabsOnLaunch == false` → chap = `launchLeftFolder ?? home`, o'ng = `launchRightFolder ?? home`, har biri `nearestExistingDirectory` orqali.

- [ ] **Step 1: Failing testlar**

```swift
// SinglePaneTests
@Test func toggleSinglePaneActivatesLeftAndPersists()  // right faol → toggle → activeSide .left, sessionSnapshot().singlePane == true
@Test func tabDoesNothingInSinglePane()                // handleKey(tab) == false
@Test func singlePaneF5AsksForDestination()            // F5 → chooseDestination chaqirilgan; javob nil → right'ga hech narsa ko'chmagan
@Test func toggleIsAllowedInTextField()                // handleKey(cmd+\, .textField) == true
// RestoreTests
@Test func launchFoldersUsedWhenNotRestoring()          // left = TempDir/a, right = nil → right == home
@Test func missingLaunchFolderFallsBackToParent()
```

- [ ] **Step 2: Run** `--filter "SinglePaneTests|RestoreTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS; to'liq `swift test` → PASS.
- [ ] **Step 5: Commit** — `Add single-pane mode and launch folders`

---

### Task 6: Drag manzillari — spring-loading va breadcrumbs (Controller)

**Files:**
- Create: `Sources/CommanderController/WindowModel+DragTargets.swift`, `Tests/CommanderControllerTests/DragTargetTests.swift`
- Modify: `WindowModel+Files.swift` (`dropOperation`/`drop` URL'li variantlari; eski `intoFolder:` variantlari ularga tayanadi)

**Interfaces:**
- Produces:
  ```swift
  public struct Breadcrumb: Equatable, Sendable { public let title: String; public let url: URL }
  public enum Breadcrumbs { public static func of(_ path: URL) -> [Breadcrumb] }   // "/" → [("/", /)]; /Users/s → [("/",/),("Users",/Users),("s",/Users/s)]
  extension WindowModel {
      public func openFolder(_ side: PaneSide, _ url: URL)                 // activate + navigate (breadcrumb click, spring-load)
      public func springLoad(_ side: PaneSide, into name: String)          // navigable qator bo'lsa openFolder
      public func springLoadParent(_ side: PaneSide)                       // activate + goUp
      public func springLoadTab(_ side: PaneSide, at index: Int)           // activate + selectTab
      public func dropOperation(_ urls: [URL], to destination: URL, forceCopy: Bool) -> DropOperation
      @discardableResult public func drop(_ urls: [URL], to destination: URL, forceCopy: Bool) -> Bool
      public func tabPath(_ side: PaneSide, at index: Int) -> URL?
  }
  ```

- [ ] **Step 1: Failing testlar**

```swift
@Test func breadcrumbsSplitPath()                       // yuqoridagi misollar
@Test func springLoadEntersFolderAndActivates()         // right faol → springLoad(.left, into: "a") → activeSide .left, path /root/a
@Test func springLoadOnFileDoesNothing()
@Test func springLoadParentGoesUp()                     // /root/a → /root, cursor "a"
@Test func springLoadTabSelectsTab()
@Test func dropToURLUsesPolicy()                        // FileHarness: drop([outside], to: right, forceCopy: false) → move (sameVolume true)
@Test func dropIntoDraggedFolderAfterSpringLoadIsNone() // dropOperation([left/sub], to: left/sub, …) == .none
```

- [ ] **Step 2: Run** `--filter DragTargetTests` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS; to'liq `swift test` → PASS.
- [ ] **Step 5: Commit** — `Add spring-loading targets and breadcrumbs to the model`

---

### Task 7: App — Esc/Clear, Delete Immediately dialogi, yashirin fayllar, hajm ko'rinishi

**Files:**
- Modify: `App/Window/SelectionBarView.swift` (Clear va Size tugmalari), `App/Dialogs/AlertPrompts.swift` + `App/System/AppKitEffects.swift` (`confirmDeleteImmediately`), `App/Pane/FileTableController.swift` (yashirin: nom va ikonka `alphaValue = 0.5`; Size ustunida `folderSize`), `App/Pane/PaneViewController.swift` (status `folderSizes` bilan), `App/Window/FooterView.swift` (hajm qatori: `SizeText.progress` + Cancel → `cancelSizeCalculation`), `App/MainMenu.swift` (File: Delete Immediately…, Copy To…, Move To…; View: Calculate Size, Single Pane; Edit: Unmark All)
- Test: `AppUITests/SmokeTests.swift`

Dialog matni (spec 2.7): bitta — `Delete “N” immediately?`; ko'p — `Delete N items immediately?`; informative `"You can't undo this action."` + birinchi 5 nom; Delete (`hasDestructiveAction`), Cancel (default, Esc).

- [ ] **Step 1: UI testlar**

```swift
func testEscapeUnmarks()                  // Space → "1 marked in left pane" bor → Esc → u yo'qoladi
func testCalculateSizeShowsFolderSize()   // nested/sub ichiga 3 B fayl; launch(left: "nested") → ⌥Space → table.left'da "3 bytes" paydo bo'ladi
```

- [ ] **Step 2: Run** `xcodebuild test … -only-testing:CommanderUITests/SmokeTests/testEscapeUnmarks -only-testing:CommanderUITests/SmokeTests/testCalculateSizeShowsFolderSize` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS; to'liq UI testlar → PASS.
- [ ] **Step 5: Qo'lda tekshirish** — `⇧⌘⌫` dialogi va Cancel; `⌘⇧.` dan keyin yashirin fayllar xira; Size ustuni va footer progress.
- [ ] **Step 6: Commit** — `Show Esc unmark, Delete Immediately, hidden dimming and folder sizes`

---

### Task 8: App — Copy To… dialogi

**Files:**
- Create: `App/Dialogs/CopyToView.swift`
- Modify: `App/Dialogs/AlertPrompts.swift` (`chooseDestination` → sheet), `App/System/AppKitEffects.swift`
- Test: `AppUITests/SmokeTests.swift`

Qarorlar:
- SwiftUI sheet (spec 2.2): sarlavha `"Copy N items to:"` / `"Move N items to:"` (bitta bo'lsa `item`); `TextField` (identifier `copyTo.path`) — ostida `model.folderSuggestions` ro'yxati; bo'limlar Recent / Tabs / Favorites (click → maydonga); tugmalar **Choose…** (`NSOpenPanel`, `canChooseDirectories = true`, `canChooseFiles = false`), **New Folder** (maydondagi mavjud papkada `createFolder(in:)` → maydon yangi papka yo'li bilan), Cancel, **Copy/Move** (default).
- Tasdiqlashda: `~` kengaytiriladi; papka mavjud → qaytariladi; fayl → beep; yo'q → `NSAlert` "Folder “X” doesn't exist. Create it and copy there?" / "…move there?" → **Create & Copy** / **Create & Move** → `createDirectory(at:)` → qaytariladi; xato → `showAlert`.
- KeyRouter sheet ochiq bo'lganda tugmalarni ushlamaydi (mavjud `attachedSheet` tekshiruvi).

- [ ] **Step 1: UI test**

```swift
func testCopyToChosenFolder()   // ⌥F5 → copyTo.path ga root/"picked/new" yoziladi → Return → "Create & Copy" → root/picked/new/alpha.txt mavjud
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4: Run** → PASS.
- [ ] **Step 5: Qo'lda tekshirish** — Recent'da oxirgi manzil; New Folder; Choose…; ⌥F6 move.
- [ ] **Step 6: Commit** — `Add Copy To and Move To dialog with New Folder`

---

### Task 9: App — bitta panel rejimi va Settings qo'shimchalari

**Files:**
- Modify: `App/PanesViewController.swift` (o'ng panel `isHidden`, divider yo'q; `.window` holatida qayta qo'llanadi), `App/System/AppKitEffects.swift`, `App/Settings/BehaviorView.swift` (On launch: Picker "Restore last session" / "Open these folders" + Left/Right yo'l va Choose…), `App/Settings/AppearanceView.swift` + `App/Settings/SettingsWindowController.swift` (Toggle "Single pane" → `WindowModel.perform(.toggleSinglePane)`; SettingsViewModel session'ni bilmaydi, shuning uchun toggle WindowModel'ga to'g'ridan-to'g'ri ulanadi)
- Test: `AppUITests/SmokeTests.swift`

- [ ] **Step 1: UI test**

```swift
func testSinglePaneHidesRightPane()   // ⌘\ → pane.right yo'q (waitForNonExistence) → ⌘\ → yana bor
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4: Run** → PASS.
- [ ] **Step 5: Qo'lda tekshirish** — qayta ochganda rejim saqlangan; On launch papkalari ishlaydi.
- [ ] **Step 6: Commit** — `Add single-pane layout and launch folder settings`

---

### Task 10: App — breadcrumbs, drop manzilini ko'rsatish, spring-loading

**Files:**
- Create: `App/Pane/BreadcrumbBar.swift`, `App/Pane/SpringLoader.swift`, `App/Pane/ParentDropStrip.swift`
- Modify: `App/Pane/PaneViewController.swift`, `FileTableController.swift`, `FileRowView.swift` (`isDropTarget`: 2 pt accent ramka + cursor foni), `TabBarView.swift` (tab tugmalari drop qabul qiladi), `AppUITests/SmokeTests.swift`

Qarorlar:
- `SpringLoader`: `func hover(_ key: AnyHashable, action: @escaping () -> Void)` — kalit o'zgarsa taymer qayta 0,7 s; `func cancel()`. Bitta loader har panelga.
- Jadval: `validateDrop` papka qatorida — `isDropTarget` belgilaydi, `hover(qator nomi) { model.springLoad }`; bo'sh joyda — jadval atrofida accent ramka (scroll view layer border 2 pt), loader cancel; `draggingExited`/`concludeDragOperation` → belgilar tozalanadi.
- `ParentDropStrip` (28 pt, `"↑ Enclosing folder"`): faqat drag jadval ustida bo'lganda va yo'l `/` bo'lmaganda ko'rinadi; hover → `springLoadParent`; drop → `drop(urls, to: ota papka, …)`.
- `BreadcrumbBar`: `Breadcrumbs.of(path)` segment tugmalari (`›` ajratgich); click → `openFolder`; drag hover → `openFolder`; drop → `drop(urls, to: segment.url, …)`; bo'sh joyga click yoki `focusPathField` → bar yashiriladi, tahrir maydoni ko'rinadi; tahrir tugagach yana bar. Accessibility: bar `path.left` (value = to'liq yo'l), tahrir maydoni `pathEdit.left`.
- Tab tugmasi: drag hover → `springLoadTab`; drop → `drop(urls, to: tabPath, …)`.
- Mavjud UI testlar yangi identifier'larga moslanadi (`path.*` — bar qiymati; `testPathFieldEditingDoesNotTouchFiles` — `pathEdit.left` fokusda).

- [ ] **Step 1: UI testlar**

```swift
func testBreadcrumbClickGoesToAncestor()   // launch(left: "nested/sub") → path.left ichidagi "nested" segmenti click → path.left value == nested
func testDragHoverSpringsIntoFolder()      // right ichida "box/" → alpha.txt'ni right'dagi "box" ustiga olib borib 1,5 s ushlab qo'yib yuborish (press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)) → path.right == right/box va right/box/alpha.txt mavjud
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4: Run** → PASS; to'liq UI testlar → PASS.
- [ ] **Step 5: Qo'lda tekshirish** — ramkalar ko'rinadi; "↑" chizig'i bilan yuqoriga chiqib tashlash; tab ustiga tashlash; Esc drag'ni bekor qiladi.
- [ ] **Step 6: Commit** — `Add breadcrumbs, drop highlighting and spring-loaded folders`

---

### Task 11: Hujjatlar va yakuniy tekshiruv

**Files:**
- Modify: `AGENTS.md` ("Joriy holat"), `docs/brainstorm/2026-10-21-commander-decisions.md` ("Ochiq savollar": 1C bajarildi; "Calculate folder size" 3 → 1C), `docs/superpowers/specs/2026-10-21-phase1-core-design.md` (2-bo'lim jadvalidan "Calculate folder size" olib tashlanadi, 1C spec'iga havola), 1C spec holati "tasdiqlandi"

- [ ] **Step 1:** `swift test --package-path Packages/CommanderKit` → hammasi PASS; `xcodebuild test …` → hammasi PASS.
- [ ] **Step 2:** Hujjatlarni yangilash.
- [ ] **Step 3: Commit** — `Record phase 1C status`
