# 1-bosqich B — App UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CommanderKit ustiga to'liq ishlaydigan ikki panelli macOS ilovasini qurish: oyna, sidebar, panellar, klaviatura/mouse, kontekst menyu, drag & drop, clipboard, dialoglar, SMB ulanish, Settings, session tiklash — spec'ning 2–9-bo'limlari.

**Architecture:** Mantiqning asosiy qismi CommanderKit'dagi yangi `CommanderController` target'ida (`@MainActor`, AppKit'siz, `swift test` bilan TDD): `WindowModel` (buyruqlar, yuklash, kuzatish, mouse qoidalari, kontekst menyu modeli), `OperationCenter` (fondagi amallar, alohida executor'da), `SidebarModel`, `SettingsPersistence`, `ShortcutEditor`/`SettingsViewModel`. AppKit tomoni (`App/`) faqat ko'rsatadi va hodisalarni modelga uzatadi; yon ta'sirlar (`NSWorkspace`, `NSPasteboard`, `NSAlert`, NetFS) `WindowEffects` / `FilePasteboard` / `OperationPrompts` / `ServerMounting` protokollari orqali ulanadi — testda fake. Xcode loyihasi XcodeGen `project.yml` dan generatsiya qilinadi.

**Tech Stack:** Swift 6 (strict concurrency), SwiftPM, Swift Testing, AppKit, SwiftUI (faqat Settings va Connect to Server), Observation, NetFS, XcodeGen, XCUITest, Instruments.

**Spec:** `docs/superpowers/specs/2026-10-21-phase1-core-design.md`

## Global Constraints

- macOS 15.0+, x86_64 (Intel MacBook Pro, macOS 15.7.9); Xcode 26.3. Sandbox yo'q, hardened runtime o'chiq, App Store yo'q.
- `CommanderCore`, `CommanderFileSystem`, `CommanderController` **AppKit/SwiftUI import qilmaydi** (Controller: Foundation, Observation, Synchronization, os, Core, FileSystem).
- AppKit asosiy; SwiftUI faqat Settings oynasi va Connect to Server dialogi (`NSHostingController`).
- Har foydalanuvchi harakati `Command` orqali `WindowModel.perform` ga keladi (klaviatura, menyu, selection bar, kontekst menyu). Drag & drop `WindowModel.drop` orqali o'sha amal oqimiga tushadi.
- Fayl amallari va papka o'qish **cooperative pool'da emas**, `OperationExecutor` (o'z `DispatchQueue` sidagi `TaskExecutor`) da ishlaydi.
- UI matnlari **inglizcha**, maketdagi (`docs/design/prototype/index.html`) yozuvlar bo'yicha.
- Ranglar (maketdan): light — accent `#3f77d2`, cursor foni `#e9f1ff`, marked foni `#eef4ff`, mark belgisi `#5b8bd6`; dark — accent `#8bb4fb`, cursor `#334662`, marked `#2d3b51`.
- Debounce: FSEvents 150 ms, Settings/session saqlash 0,5 s, type-ahead reset 1 s. `⌘K` tarixi — 10 ta.
- Fayllar: `~/Library/Application Support/Commander/settings.json`, `session.json`; oyna frame — `NSWindow` autosave `"MainWindow"`.
- 1-bosqichdan tashqaridagi buyruqlar (Open With, Quick Look, Compress, Share, Get Info, F3/F4…) menyuda ham, tugmada ham **ko'rsatilmaydi**.
- Controller testlari: `swift test --package-path Packages/CommanderKit --filter <Suite>`; testlar faqat vaqtinchalik papkada, haqiqiy Trash'ga hech narsa yuborilmaydi.
- Commit xabarlari — inglizcha, buyruq maylida, attribution qatorsiz.

## Review Focus

1. **Sekin papkadan tez chiqib ketish** (SMB papka hali o'qilayotganda boshqa papkaga o'tish) — kechikkan natija yangi papka ro'yxatini bosib ketmasligi kerak. → Task 4 `staleListingIsDropped`.
2. **Matn maydonida yozish** (path field, rename) — `⌫`, `Space`, `⌘⌫`, `⌘D` fayllarga tegmasligi, menyu key equivalent'i orqali ham. → Task 5 `fileCommandsAreDisabledInTextField`, Task 18 `testPathFieldEditingDoesNotTouchFiles`.
3. **Ochiq papka yo'qoladi** (o'chirildi yoki disk eject qilindi) va `stop()` dan keyin kechikkan FSEvents hodisasi — panel eng yaqin ota papkaga o'tadi, eski watcher hodisasi e'tiborsiz. → Task 4 `deletedFolderFallsBackToNearestParent`, `lateWatcherEventAfterStopIsIgnored`.
4. **Copy ketayotganda ilovadan chiqish** — tasdiq so'raladi, amallar cancel qilinadi (chala fayllar o'chadi), Settings/session sinxron yoziladi. → Task 3 `cancelAllStopsEveryOperation`, Task 9 `flushWritesSynchronously`, Task 17 qo'lda tekshiruv.
5. **Bir nechta parallel SMB copy, ikkalasida bir vaqtda konflikt** — ilova qotmaydi, dialoglar birma-bir chiqadi. → Task 1 `doesNotCapThreadsAtCoreCount`, Task 3 `promptsAreShownOneAtATime`.

## Spec'dan aniqlashtirilgan qarorlar (plan darajasida)

- **SMB mount — NetFS** (`NetFSMountURLAsync`, login oynasi macOS'niki). Spec "`NSWorkspace` orqali" deydi, lekin `NSWorkspace.open(smb://…)` Finder oynasini ochadi va mount nuqtasini qaytarmaydi; NetFS spec maqsadini (macOS mount qiladi, login macOS'niki, `/Volumes/<share>` faol panelda ochiladi) aniq bajaradi.
- Status qatori: `"12 items · 3 marked · 4.8 MB"` — hajm belgilanganlar bo'lsa ularniki, bo'lmasa ro'yxatdagi barcha fayllarniki; belgilanmagan bo'lsa "marked" qismi yo'q.
- `⌘`+click qatorni belgilaydi/olib tashlaydi **va** kursorni o'sha qatorga qo'yadi (keyingi `⇧`+click diapazoni shu yerdan boshlanadi, Finder kabi).
- `Return`/double-click va `F2` faqat **kursordagi** elementga ishlaydi (belgilanganlar bo'lsa ham).
- Amal boshlanganda manba tabidagi belgilar tozalanadi.
- Maketdagidek, kursor faqat **faol** panelda ko'rinadi.

---

## Fayl tuzilmasi

```
project.yml                               # XcodeGen
Packages/CommanderKit/
  Package.swift                           # + CommanderController target/product, CommanderControllerTests
  Sources/CommanderController/
    OperationExecutor.swift               # TaskExecutor + run(_:)
    KeyChordMapper.swift                  # keyCode/belgi → KeyChord
    KeyChord+Display.swift                # "⇧⌘." ko'rinishi
    Command+Title.swift                   # buyruq nomlari
    Texts.swift                           # status, footer, selection, amal, xato, rename matnlari
    OperationCenter.swift                 # OperationRequest, OperationPrompts, bridge delegate
    Environment.swift                     # WindowEnvironment, protokollar, PaneBanner, AlertMessage, StateChange
    WindowModel.swift                     # init, restore, yuklash, watcher, banner, waitUntilIdle
    WindowModel+Commands.swift            # perform, handleKey, isEnabled, typeAhead, goToPath
    WindowModel+Mouse.swift               # click, sort, contextMenu; SlowClick
    WindowModel+Files.swift               # F5/F6, trash, new folder, rename, clipboard, drop; DropPolicy, RenameSelection
    SidebarModel.swift                    # favorites, volumes, capacity matni
    WindowModel+Places.swift              # openPlace, eject, connect
    SettingsPersistence.swift
    ShortcutEditor.swift
    SettingsViewModel.swift               # @Observable
    Bootstrap.swift                       # LaunchOptions, AppBootstrap
  Tests/CommanderControllerTests/
    TestSupport.swift                     # TempDir, eventually, item(...)
    Fakes.swift                           # RecordingEffects, FakePasteboard, FakeLister, GatedLister, FakeWatcherFactory, FakeMounter, FakePrompts, FakeTrasher
    *Tests.swift                          # har manba fayliga mos
App/
  AppDelegate.swift                       # @main, bootstrap, terminate
  MainMenu.swift                          # menyu, KeyEquivalent
  KeyRouter.swift                         # NSEvent monitor → KeyChord → model
  MainWindowController.swift              # NSSplitViewController (sidebar | panes)
  PanesViewController.swift               # 2 panel + selection bar + footer
  Pane/PaneViewController.swift           # tab bar, path field, banner, jadval, status
  Pane/TabBarView.swift
  Pane/FileTableView.swift                # mouse, drag, menyu
  Pane/FileTableController.swift          # data source/delegate, hujayralar, drop
  Pane/FileRowView.swift                  # cursor va marked chizish
  Pane/RenameEditor.swift
  Pane/AccessBannerView.swift
  Window/SelectionBarView.swift
  Window/FooterView.swift
  Sidebar/SidebarViewController.swift
  Dialogs/AlertPrompts.swift              # OperationPrompts + destination + alert
  Dialogs/ConnectToServerView.swift       # SwiftUI
  System/AppKitEffects.swift              # WindowEffects
  System/SystemPasteboard.swift           # FilePasteboard
  System/NetFSMounter.swift               # ServerMounting
  System/IconCache.swift
  Settings/SettingsWindowController.swift
  Settings/AppearanceView.swift, BehaviorView.swift, ShortcutsView.swift, ShortcutRecorder.swift
AppUITests/SmokeTests.swift
```

---

### Task 1: `CommanderController` target va `OperationExecutor`

**Files:**
- Modify: `Packages/CommanderKit/Package.swift` — `.library(name: "CommanderController", targets: ["CommanderController"])`, `.target(name: "CommanderController", dependencies: ["CommanderCore", "CommanderFileSystem"])`, `.testTarget(name: "CommanderControllerTests", dependencies: ["CommanderController", "CommanderCore", "CommanderFileSystem"])`
- Create: `Sources/CommanderController/OperationExecutor.swift`, `Tests/CommanderControllerTests/OperationExecutorTests.swift`, `Tests/CommanderControllerTests/TestSupport.swift`

**Interfaces:**
- Produces:
  ```swift
  public final class OperationExecutor: TaskExecutor, Sendable {
      public static let operations: OperationExecutor    // label "Commander.operations"
      public static let listing: OperationExecutor       // label "Commander.listing"
      public init(label: String)                         // DispatchQueue(label:, qos: .userInitiated, attributes: .concurrent)
      public func enqueue(_ job: consuming ExecutorJob)
      public func run<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T   // bloklovchi ishni shu executor'da bajaradi
  }
  // TestSupport
  struct TempDir { let url: URL; init() throws; func file(_ name: String, bytes: Int = 0) throws -> URL; func dir(_ name: String) throws -> URL; func remove() }
  func eventually(timeout: Duration = .seconds(2), _ condition: @MainActor () -> Bool) async -> Bool   // 10 ms oraliqda tekshiradi
  func item(_ name: String, _ kind: FileItem.Kind = .file, size: Int64? = 0, in dir: URL = URL(fileURLWithPath: "/root")) -> FileItem
  ```
- `enqueue`: `let job = UnownedJob(job); queue.async { job.runSynchronously(on: self.asUnownedTaskExecutor()) }`. Custom concurrent queue overcommit — bloklangan ishlar yadro soniga cheklanmaydi; buni test tasdiqlaydi.
- `run`: `Task(executorPreference: self) { try body() }.value`. Test body main thread'da ishlayotganini ko'rsatsa, body'ni `nonisolated` async yordamchi funksiya ichida chaqiring.

- [ ] **Step 1: Failing testlar**

```swift
@Test func runExecutesOffMainThreadOnItsQueue()   // @MainActor'dan; body ichida Thread.isMainThread == false va String(cString: __dispatch_queue_get_label(nil)) == label
@Test func runRethrowsBodyError()
@Test func doesNotCapThreadsAtCoreCount()         // n = activeProcessorCount + 4 ta run, har biri DispatchGroup barrier'da kutadi; 5 s ichida n tasi ham kirgan
@Test func cooperativePoolStaysResponsiveWhileBlocked()   // n ta bloklangan run paytida oddiy Task { } 1 s ichida tugaydi; oxirida barrier ochiladi
```

- [ ] **Step 2: Run** `swift test --package-path Packages/CommanderKit --filter OperationExecutorTests` → FAIL (target/tur yo'q).
- [ ] **Step 3: `Package.swift` va `OperationExecutor.swift` ni implement qilish.**
- [ ] **Step 4: Run** → PASS; to'liq `swift test --package-path Packages/CommanderKit` → 122 + yangi testlar PASS.
- [ ] **Step 5: Commit** — `Add CommanderController target with dedicated operation executor`

---

### Task 2: `KeyChordMapper`, shortcut ko'rinishi, buyruq nomlari

**Files:**
- Create: `Sources/CommanderController/KeyChordMapper.swift`, `KeyChord+Display.swift`, `Command+Title.swift`, `Tests/CommanderControllerTests/KeyChordMapperTests.swift`, `KeyChordDisplayTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum KeyChordMapper {
      /// baseCharacters — App'da `event.characters(byApplyingModifiers: [])` (shift ham qo'llanmagan), shuning uchun shift+. "." bo'lib qoladi.
      public static func chord(keyCode: UInt16, baseCharacters: String?, modifiers: KeyChord.Modifiers) -> KeyChord?
  }
  extension KeyChord { public var displayString: String }
  extension Command { public var title: String }
  ```
- keyCode jadvali (nomli tugmalar belgidan oldin tekshiriladi): 126 up · 125 down · 123 left · 124 right · 115 home · 119 end · 116 pageUp · 121 pageDown · 36 va 76 return · 48 tab · 49 space · 51 backspace · 117 forwardDelete · 53 escape · F1–F12: 122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111. Qolganlari — `baseCharacters` ning yagona belgisi, kichik harfga; bo'sh yoki bir nechta belgi → `nil`.
- `displayString`: modifikatorlar `⌃⌥⇧⌘` tartibida, keyin tugma: up `↑` down `↓` left `←` right `→` home `↖` end `↘` pageUp `⇞` pageDown `⇟` space `Space` return `↩` tab `Tab` backspace `⌫` forwardDelete `⌦` escape `Esc` fN `FN`, harflar katta (`T`), qolgan belgilar o'zicha.
- `title` jadvali: moveUp "Move Up" · moveDown "Move Down" · moveToStart "Go to First Item" · moveToEnd "Go to Last Item" · pageUp "Page Up" · pageDown "Page Down" · markUp "Mark and Move Up" · markDown "Mark and Move Down" · toggleMark "Mark / Unmark" · markAll "Mark All" · open "Open" · goUp "Enclosing Folder" · goBack "Back" · goForward "Forward" · switchPane "Switch Pane" · newTab "New Tab" · closeTab "Close Tab" · nextTab "Next Tab" · previousTab "Previous Tab" · focusPathField "Go to Path…" · reload "Reload" · toggleHiddenFiles "Show / Hide Hidden Files" · copyToClipboard "Copy" · cutToClipboard "Cut" · paste "Paste" · duplicate "Duplicate" · copyToOtherPane "Copy to Other Pane" · moveToOtherPane "Move to Other Pane" · newFolder "New Folder" · rename "Rename" · moveToTrash "Move to Trash" · connectToServer "Connect to Server…" · openSettings "Settings…" · copyPath "Copy Path" · copyName "Copy Name" · showPackageContents "Show Package Contents" · revealInFinder "Reveal in Finder" · openInTerminal "Open in Terminal".

- [ ] **Step 1: Failing testlar**

```swift
// KeyChordMapperTests
@Test func shiftDotStaysDot()            // (47, ".", [.shift, .command]) == KeyChord(string: "cmd+shift+.")
@Test func namedKeysUseKeyCode()         // 126 → "up", 51 → "backspace", 117 → "forwardDelete", 96 → "f5", 76 → "return", 49 (" ") → "space", 53 → "escape"
@Test func controlShiftTab()             // (48, "\t", [.control, .shift]) → "ctrl+shift+tab"
@Test func optionLetterUsesBaseCharacter()   // (0, "a", [.option]) → "opt+a"
@Test func uppercaseBaseIsLowered()      // (17, "T", [.command]) → "cmd+t"
@Test func emptyOrMultiCharacterGivesNil()
// KeyChordDisplayTests
@Test func displayStrings()              // "cmd+shift+." → "⇧⌘."; "ctrl+shift+tab" → "⌃⇧Tab"; "f5" → "F5"; "cmd+backspace" → "⌘⌫"; "space" → "Space"; "up" → "↑"; "cmd+," → "⌘,"; "opt+a" → "⌥A"
@Test func everyCommandHasTitle()        // Command.allCases: title bo'sh emas, hammasi har xil
```

- [ ] **Step 2: Run** `--filter "KeyChordMapperTests|KeyChordDisplayTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Map key events to chords and add shortcut display strings`

---

### Task 3: `OperationCenter`

**Files:**
- Create: `Sources/CommanderController/OperationCenter.swift`, `Texts.swift` (bu task'da `OperationText`, `FailureText`), `Tests/CommanderControllerTests/OperationCenterTests.swift`, `OperationTextTests.swift`, `Fakes.swift` (`FakePrompts`, `FakeTrasher`)

**Interfaces:**
- Consumes: `OperationExecutor` (Task 1); CommanderKit: `CopyOperation`, `MoveOperation`, `TrashOperation`, `DeleteOperation`, `OperationDelegate`, `OperationState`, `Trasher`
- Produces:
  ```swift
  @MainActor public protocol OperationPrompts: AnyObject {
      func resolve(_ conflict: Conflict) async -> ConflictResolution
      func decide(_ failure: OperationFailure) async -> ErrorDecision
      func confirmPermanentDelete(_ urls: [URL]) async -> Bool
  }
  public enum OperationRequest: Equatable, Sendable {
      case copy(sources: [URL], destination: URL)
      case move(sources: [URL], destination: URL)
      case trash([URL])
      case delete([URL])
  }
  @MainActor public final class OperationCenter {
      public init(executor: OperationExecutor = .operations, prompts: any OperationPrompts, trasher: any Trasher = SystemTrasher())
      public private(set) var operations: [OperationState]      // ishlayotgan va kutayotganlar, boshlanish tartibida; tugaganlar olib tashlanadi
      public var onChange: (() -> Void)?
      public var onFinish: ((_ affectedDirectories: [URL]) -> Void)?
      @discardableResult public func start(_ request: OperationRequest) -> UUID
      public func cancel(_ id: UUID)
      public func cancelAll()
      public var isIdle: Bool { get }
      public func waitUntilIdle() async
  }
  public enum OperationText { public static func summary(_ state: OperationState) -> String }
  public enum FailureText { public static func message(_ failure: OperationFailure) -> String }
  ```
- `start`: `Task(executorPreference: executor) { … }` — operatsiyaning `run()` shu executor'da; handle `id` bo'yicha saqlanadi (`cancel` → `task.cancel()`).
- Delegate ko'prigi (`final class`, `Sendable`): `progress` → 100 ms dan tez emas (`Mutex<ContinuousClock.Instant?>`) `Task { @MainActor }` bilan holatga yoziladi. `resolve`/`decide` → status `.waitingForUser`, prompt **navbat bilan** (oldingi prompt tugashini kutadi), keyin `.running`.
- Trash: natijada `unsupported` bo'sh bo'lmasa → `confirmPermanentDelete(unsupported)` → `true` bo'lsa shu id ostida `DeleteOperation`.
- `affectedDirectories`: copy → `[destination]`; move → `[destination] + manbalarning ota papkalari`; trash/delete → ota papkalar (takrorsiz).
- `OperationText.summary` (B = `ByteCountFormatter.string(fromByteCount:countStyle: .file)`): copy `"Copying 3 of 10 files · B(12_000_000) of B(40_000_000)"`, move `"Moving …"` (xuddi shu shakl), trash `"Moving to Trash 1 of 4 items"`, delete `"Deleting 1 of 4 items"`; `.waitingForUser` → `"Copying — waiting for your decision"` (kind so'zi mos).
- `FailureText.message` (`N` = `url.lastPathComponent`): permissionDenied `"You don't have permission to access “N”."` · fileBusy `"“N” is in use."` · diskFull `"There isn't enough space for “N”."` · destinationInsideSource `"“N” can't be copied into itself."` · targetContainsSource `"“N” can't be replaced because it contains the item being copied."` · other(m) `"Couldn't process “N”: m"`.

- [ ] **Step 1: Failing testlar** (vaqtinchalik papkada; `FakePrompts` — oldindan berilgan javoblar, chaqiruvlar va bir vaqtdagi faol promptlar maksimumi (`maxConcurrent`); javobni test qo'lda beradigan `held` rejimi bor)

```swift
@Test func copyCompletesAndReportsAffectedDirectory()   // start(.copy) → waitUntilIdle → fayl manzilda, operations bo'sh, onFinish([dest])
@Test func waitingStatusWhileConflictPromptOpen()       // held prompt → eventually status == .waitingForUser → javob → operations bo'sh
@Test func promptsAreShownOneAtATime()                  // ikki copy, ikkalasida konflikt → maxConcurrent == 1, ikkalasi tugaydi
@Test func cancelStopsOperation()                       // 200 MB fayl; progress > 0 bo'lgach cancel(id) → manzilda chala fayl yo'q, operations bo'sh
@Test func cancelAllStopsEveryOperation()               // ikki katta copy → cancelAll → waitUntilIdle → ikkalasi ham to'xtagan
@Test func unsupportedTrashAsksThenDeletes()            // FakeTrasher(unsupported: [x]) → confirmPermanentDelete([x]) → true → x yo'q
@Test func declinedPermanentDeleteKeepsFile()
@Test func operationBodyRunsOnOperationExecutor()       // FakeTrasher trash() ichida Thread.isMainThread == false yozib qo'yadi
// OperationTextTests
@Test func summaries()                                  // to'rt tur + waiting; kutilgan bayt matni testda ham ByteCountFormatter bilan hisoblanadi
@Test func failureMessages()
```

- [ ] **Step 2: Run** `--filter "OperationCenterTests|OperationTextTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS (beqarorlikni tekshirish uchun 3 marta).
- [ ] **Step 5: Commit** — `Add OperationCenter running file operations off the cooperative pool`

---

### Task 4: `WindowModel` yadrosi — tiklash, yuklash, kuzatish, banner

**Files:**
- Create: `Sources/CommanderController/Environment.swift`, `WindowModel.swift`, `Tests/CommanderControllerTests/WindowModelLoadingTests.swift`, `RestoreTests.swift`, `PaneTextTests.swift`
- Modify: `Texts.swift` (+ `PaneText.status`), `Fakes.swift` (+ `RecordingEffects`, `FakePasteboard`, `FakeLister`, `GatedLister`, `FakeWatcherFactory`, `FakeMounter`, `WindowEnvironment.test(...)`)

**Interfaces:**
- Consumes: `OperationCenter` (Task 3), `OperationExecutor`, CommanderKit `WindowState`, `TabState`, `KeyBindings`, `AppSettings`, `Session`, `DirectoryReader`, `DirectoryWatcher`, `VolumeInfo`
- Produces:
  ```swift
  public protocol DirectoryListing: Sendable {
      func list(_ directory: URL) throws(ListingError) -> [FileItem]
      func nearestExistingDirectory(from url: URL) -> URL
  }
  extension DirectoryReader: DirectoryListing {}
  public protocol DirectoryWatching: AnyObject, Sendable { func start(); func stop() }
  extension DirectoryWatcher: DirectoryWatching {}
  public protocol ServerMounting: Sendable { func mount(_ url: URL) async throws -> URL }   // foydalanuvchi bekor qilsa CancellationError
  @MainActor public protocol FilePasteboard: AnyObject {
      func writeFiles(_ urls: [URL], cut: Bool)
      func writeString(_ string: String)
      func readFiles() -> (urls: [URL], isCut: Bool)?
      func clearCut()
  }
  public enum PaneBanner: Equatable, Sendable { case noAccess, unreadable(String) }
  public struct AlertMessage: Equatable, Sendable { public let title: String; public let detail: String?; public init(title: String, detail: String?) }
  public enum StateChange: Equatable, Sendable { case pane(PaneSide), window, sidebar, operations, settings }
  @MainActor public protocol WindowEffects: AnyObject {
      func stateDidChange(_ change: StateChange)
      func focusPathField(_ side: PaneSide)
      func beginRename(_ side: PaneSide, name: String)
      func open(_ url: URL)
      func revealInFinder(_ urls: [URL])
      func openInTerminal(_ directory: URL)
      func showSettings()
      func showConnectToServer()
      func askDestination(default url: URL, kind: OperationKind, count: Int) async -> URL?
      func showAlert(_ alert: AlertMessage)
      func beep()
  }
  public struct WindowEnvironment: Sendable {
      public var lister: any DirectoryListing
      public var makeWatcher: @Sendable (URL, @escaping @Sendable () -> Void) -> any DirectoryWatching
      public var listingExecutor: OperationExecutor
      public var isNetworkPath: @Sendable (URL) -> Bool          // live: volumeIsLocalKey == false
      public var sameVolume: @Sendable (URL, URL) -> Bool        // live: volumeIdentifierKey teng
      public var volumes: @Sendable () -> [VolumeInfo]           // live: Volumes.mounted
      public var ejectVolume: @Sendable (URL) async throws -> Void
      public var mounter: any ServerMounting
      public var now: @Sendable () -> ContinuousClock.Instant
      public static func live(mounter: any ServerMounting) -> WindowEnvironment
  }
  extension WindowState {
      public static func restored(from session: Session, behavior: BehaviorSettings, lister: any DirectoryListing) -> WindowState
  }
  @MainActor public final class WindowModel {
      public init(state: WindowState, settings: AppSettings, session: Session, environment: WindowEnvironment,
                  effects: any WindowEffects, pasteboard: any FilePasteboard, operations: OperationCenter)
      public private(set) var state: WindowState
      public private(set) var settings: AppSettings
      public private(set) var bindings: KeyBindings
      public let operations: OperationCenter
      public var onSessionChange: ((Session) -> Void)?             // faqat snapshot o'zgarganda
      public func start()                                          // ikkala panelning faol tabini yuklaydi va kuzatadi
      public func tab(_ side: PaneSide) -> TabState
      public func banner(_ side: PaneSide) -> PaneBanner?
      public func listingVersion(_ side: PaneSide) -> Int          // har apply(listing:) da +1 (UI reloadData qarori uchun)
      public func reload(_ side: PaneSide)
      public func activate(_ side: PaneSide)                       // boshqa panel faollashsa va u tarmoqda bo'lsa — qayta o'qiladi
      public func appDidBecomeActive()                             // tarmoq papkasidagi panellarni qayta o'qiydi
      public func sessionSnapshot() -> Session
      public func waitUntilIdle() async                            // kutilayotgan yuklash va buyruq task'lari + operations.waitUntilIdle()
  }
  public enum PaneText { public static func status(_ tab: TabState) -> String }
  ```
- `restored`: `restoreTabsOnLaunch == false` → har panelda bitta Home tab, `activeSide = .left`; aks holda har yo'l `lister.nearestExistingDirectory(from:)`, `activeTab` chegaraga keltiriladi. Hamma yangi `TabState` — `showHidden: behavior.showHiddenByDefault`.
- Yuklash: har panel uchun `generation` hisoblagichi; `listingExecutor.run { try lister.list(path) }` natijasi faqat generation va yo'l hali o'sha bo'lsa qo'llanadi. `.notFound`/`.notADirectory` → `navigate(to: nearestExistingDirectory)` va qayta yuklash; `.permissionDenied` → banner `.noAccess`, ro'yxat bo'sh; `.other(m)` → `.unreadable(m)`; muvaffaqiyat → banner `nil`. Har o'zgarishdan keyin `effects.stateDidChange(.pane(side))` (faol panel o'zgarsa `.window`) va `onSessionChange`.
- Kuzatish: har panelning faol tab yo'li bitta watcher bilan; yo'l yoki faol tab o'zgarsa eski `stop()`, yangisi `start()`. onChange → `Task { @MainActor }` → watcher **token**i joriy bo'lsagina `reload` (stop'dan keyingi ortiqcha hodisa e'tiborsiz — CommanderKit review talabi).
- `PaneText.status`: `"N items"` (1 → `"1 item"`) + belgilanganlar bo'lsa `" · M marked"` + `" · " + B(hajm)`; hajm — belgilangan fayllar yoki barcha ko'rinadigan fayllar `size` yig'indisi (nil = 0).

- [ ] **Step 1: Failing testlar**

```swift
// RestoreTests
@Test func restoresTabsAndActiveSide()
@Test func restoreFallsBackForMissingPaths()        // TempDir/a/b yo'q → TempDir/a
@Test func restoreDisabledOpensHomeOnce()
@Test func newTabsUseShowHiddenDefault()
// WindowModelLoadingTests (@MainActor; FakeLister /root → [a(dir), b.txt, c.txt])
@Test func startLoadsBothPanes()                    // waitUntilIdle → tab(.left).items nomlari ["a","b.txt","c.txt"], cursor "a"
@Test func staleListingIsDropped()                  // GatedLister: /slow bloklangan → navigate /slow, keyin /fast → /fast qo'llanadi → /slow ochiladi → path /fast, items fast'niki
@Test func deletedFolderFallsBackToNearestParent()  // haqiqiy DirectoryReader: TempDir/a ochiq → a o'chiriladi → reload → path == TempDir
@Test func permissionDeniedShowsBannerUntilSuccess()
@Test func otherErrorShowsUnreadableBanner()
@Test func activeTabIsWatched()                     // FakeWatcherFactory: ikki started watcher, yo'llari panellarniki
@Test func navigationSwapsWatcher()                 // eski stopped, yangi started
@Test func watcherEventReloadsKeepingCursor()       // FakeLister ro'yxatini o'zgartirish → fire → eventually items yangilangan, cursor nomi o'sha
@Test func lateWatcherEventAfterStopIsIgnored()     // navigate → eski watcher fire → lister'ga yangi chaqiruv yo'q, crash yo'q
@Test func networkPanesReloadOnFocus()              // isNetworkPath faqat right uchun true → appDidBecomeActive va activate(.right) faqat right'ni qayta o'qiydi
@Test func sessionSnapshotFollowsState()            // navigate → onSessionChange oxirgi qiymati left.tabPaths == [yangi]
// PaneTextTests
@Test func statusTexts()                            // 3 fayl (1_000, 2_000, 3_000) → "3 items · B(6_000)"; bittasi belgilangan (2_000) → "3 items · 1 marked · B(2_000)"; bo'sh → "0 items · B(0)"; bitta → "1 item · …"
```

- [ ] **Step 2: Run** `--filter "RestoreTests|WindowModelLoadingTests|PaneTextTests"` → FAIL.
- [ ] **Step 3: Implement qilish.** `bindings = KeyBindings(defaults: .defaults(for: settings.behavior), overrides: settings.shortcutOverrides)`. `operations.onFinish` → faol yo'li `affectedDirectories` dan biriga teng panellar `reload`; `operations.onChange` → `stateDidChange(.operations)`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add WindowModel loading, watching and session restore`

---

### Task 5: Buyruqlar va klaviatura

**Files:**
- Create: `Sources/CommanderController/WindowModel+Commands.swift`, `Tests/CommanderControllerTests/CommandTests.swift`, `KeyHandlingTests.swift`, `FooterHintsTests.swift`
- Modify: `Texts.swift` (+ `FooterHints`, `PaneText.selectionSummary`)

**Interfaces:**
- Consumes: Task 4 `WindowModel`, `TypeAhead`, `KeyBindings.command(for:in:)`, `Command.isAllowedInTextField`
- Produces:
  ```swift
  public enum CommandScope: Sendable { case targets, folder }     // folder = joriy papkaning o'zi (bo'sh joy menyusi)
  extension WindowModel {
      public func perform(_ command: Command, scope: CommandScope = .targets)
      @discardableResult public func handleKey(_ chord: KeyChord, context: FocusContext) -> Bool
      public func isEnabled(_ command: Command, context: FocusContext) -> Bool
      public func typeAhead(_ character: Character)                // faol panel; vaqt environment.now()
      public func setPageSize(_ side: PaneSide, rows: Int)
      @discardableResult public func goToPath(_ side: PaneSide, _ text: String) -> Bool
      public func selectTab(_ side: PaneSide, at index: Int)
      public func closeTab(_ side: PaneSide, at index: Int)        // selectTab(at:) + closeActiveTab()
  }
  public struct FooterHint: Equatable, Sendable { public let keys: String; public let title: String }
  public enum FooterHints { public static func items(bindings: KeyBindings, behavior: BehaviorSettings) -> [FooterHint] }
  extension PaneText { public static func selectionSummary(_ tab: TabState, side: PaneSide) -> String? }   // "3 marked in left pane"; belgisiz → nil
  ```
- Bu task'da `perform` quyidagilarni bajaradi (fayl buyruqlari Task 7, joylar Task 8): moveUp/Down (`moveCursor(by: ∓1)`), moveToStart/End, pageUp/Down (`max(pageSize - 1, 1)` qator; default pageSize 20), markUp/Down, toggleMark (`advance: behavior.spaceAdvances`), markAll, open (kursordagi: navigable → `navigate(to: item.url)`; fayl va package → `effects.open`), goUp, goBack, goForward, switchPane, newTab (yangi tab yuklanadi va kuzatiladi), closeTab, nextTab, previousTab, focusPathField (`effects.focusPathField`), reload, toggleHiddenFiles, openSettings, connectToServer (`effects.showConnectToServer`).
- `handleKey`: `bindings.command(for:in:)` → topilsa va `isEnabled` bo'lsa `perform`, `true`; aks holda `false`.
- `isEnabled`: `.textField` da `!isAllowedInTextField` → `false`. `.table` da target talab qiluvchilar (copyToOtherPane, moveToOtherPane, duplicate, moveToTrash, copyToClipboard, cutToClipboard, copyPath, copyName, revealInFinder) — `targets` bo'sh bo'lsa `false`; rename — `cursorItem` bo'lmasa `false`; showPackageContents — `cursorItem?.kind == .package`; paste — `pasteboard.readFiles() != nil`; qolganlari `true`.
- `goToPath`: trim, `~` → home (`NSString.expandingTildeInPath`); mavjud papka → navigate; mavjud fayl → ota papkaga, yuklangach kursor fayl nomida; aks holda `effects.beep()`, `false`.
- `FooterHints.items` tartibi: toggleMark (`"Mark & next"`, `spaceAdvances == false` → `"Mark"`), switchPane `"Switch pane"`, backspace egasi (goUp → `"Parent folder"`, goBack → `"Back"`), copyToOtherPane `"Copy"`, moveToOtherPane `"Move"`, newFolder `"New folder"`, rename `"Rename"`, moveToTrash `"Trash"`. `keys` — buyruqning birinchi chord'i `displayString`; chord'siz buyruq tushib qoladi.

- [ ] **Step 1: Failing testlar** (FakeLister `/root` 30 element, `/root/a` papka)

```swift
// KeyHandlingTests
@Test func arrowMovesCursorAndReturnsTrue()          // handleKey(KeyChord("down"), .table) == true, cursor 2-element
@Test func unknownChordReturnsFalse()
@Test func fileCommandsAreDisabledInTextField()      // .textField: backspace, space, cmd+backspace, cmd+d → false, holat o'zgarmagan; isEnabled(.duplicate, .textField) == false
@Test func whitelistedCommandWorksInTextField()      // cmd+t .textField → yangi tab
@Test func pageDownUsesPageSize()                    // setPageSize(10) → cursor indeks 9
@Test func typeAheadJumpsAndResets()                 // fake now(): "b" → "b…" ga; 1.1 s keyin "c" → prefiks "c"
// CommandTests
@Test func openFolderNavigatesAndLoads()
@Test func openFileAndPackageUseEffects()            // effects.opened == [url]
@Test func goUpPutsCursorOnLeftFolder()
@Test func backspaceFollowsHistoryBackBehavior()
@Test func spaceRespectsSpaceAdvances()
@Test func switchPaneAndTabs()                       // switchPane → activeSide .right; newTab → 2 tab, yangi watcher; closeTab → 1; oxirgisi yopilmaydi; closeTab(at:)
@Test func toggleHiddenAndReload()
@Test func focusPathFieldUsesEffects()
@Test func goToPathHandlesTildeFileAndMissing()      // "~" → home; ".../b.txt" → ota papka, cursor "b.txt"; yo'q yo'l → false, effects.beeps == 1
@Test func targetCommandsDisabledOnEmptyFolder()
// FooterHintsTests
@Test func defaultHints()                            // [("Space","Mark & next"),("Tab","Switch pane"),("⌫","Parent folder"),("F5","Copy"),("F6","Move"),("F7","New folder"),("F2","Rename"),("⌘⌫","Trash")]
@Test func hintsFollowBehaviorAndOverrides()         // historyBack → ("⌫","Back"); copyToOtherPane override [] → "Copy" yo'q
@Test func selectionSummary()                        // 3 belgilangan, .left → "3 marked in left pane"; 0 → nil
```

- [ ] **Step 2: Run** `--filter "KeyHandlingTests|CommandTests|FooterHintsTests"` → FAIL.
- [ ] **Step 3: Implement qilish.** Har `perform` oxirida o'zgargan panel uchun `stateDidChange`, `onSessionChange`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Dispatch commands and keys through WindowModel`

---

### Task 6: Mouse qoidalari, saralash, kontekst menyu modeli

**Files:**
- Create: `Sources/CommanderController/WindowModel+Mouse.swift`, `Tests/CommanderControllerTests/MouseTests.swift`, `ContextMenuTests.swift`

**Interfaces:**
- Consumes: Task 5 `perform`, `CommandScope`, `isEnabled`; Task 2 `Command.title`, `KeyChord.displayString`
- Produces:
  ```swift
  extension WindowModel {
      public func click(_ side: PaneSide, row name: String?, modifiers: KeyChord.Modifiers)   // name nil = bo'sh joy
      public func doubleClick(_ side: PaneSide, row name: String)
      public func sortColumnClicked(_ side: PaneSide, _ column: SortColumn)
      public func contextMenu(_ side: PaneSide, row name: String?) -> [MenuItemModel]
  }
  public struct MenuEntry: Equatable, Sendable { public let command: Command; public let title: String; public let shortcut: String?; public let scope: CommandScope }
  public enum MenuItemModel: Equatable, Sendable { case entry(MenuEntry), separator }
  public enum SlowClick {
      public static func shouldBeginRename(row name: String, clickCount: Int, cursorBefore: String?, paneWasActive: Bool, onNameText: Bool, modifiers: KeyChord.Modifiers) -> Bool
  }
  ```
- `click`: avval `activate(side)`; modifikatorsiz → `setCursor`; `.command` → `toggleMark(name:)` + `setCursor`; `.shift` → `markRange(toName:)`.
- `doubleClick` → `setCursor` + `perform(.open)`.
- `sortColumnClicked`: shu ustun → `ascending` teskari; boshqa ustun → `ascending = true`.
- `contextMenu` (row bor): nom belgilangan bo'lsa — belgilar o'zgarmaydi (menyu ular uchun); belgilanmagan → `setCursor(name)` (menyu faqat unga). Tarkib: Open · — · Copy to Other Pane · Move to Other Pane · — · Rename · Duplicate · Move to Trash · — · Copy Path · Copy Name · — · Show Package Contents (faqat targets bitta va `.package`) · Reveal in Finder · Open in Terminal. Bo'sh joy: New Folder · Paste (faqat `isEnabled(.paste)`) · Show Hidden Files / Hide Hidden Files (holatga qarab) · — · Open in Terminal (`scope: .folder`). `shortcut` — birinchi chord `displayString` yoki `nil`; `title` — `Command.title` (hidden toggle bundan mustasno).
- `SlowClick`: `clickCount == 1 && paneWasActive && cursorBefore == name && onNameText && modifiers.isEmpty`. Taymer (`NSEvent.doubleClickInterval`) App'da.

- [ ] **Step 1: Failing testlar**

```swift
// MouseTests
@Test func clickSetsCursorKeepsMarks()
@Test func clickActivatesPane()                      // .right ga click → activeSide .right
@Test func commandClickTogglesAndMovesCursor()
@Test func shiftClickMarksRangeFromCursor()
@Test func doubleClickOpens()
@Test func clickOnEmptyAreaOnlyActivates()
@Test func sortHeaderTogglesDirection()              // name → name: ascending false; size → size, ascending true
@Test func slowClickRules()                          // true holati va har shart alohida buzilganda false (clickCount 2, boshqa qator, faol emas, nom tashqarisi, ⌘)
// ContextMenuTests
@Test func menuOnUnmarkedRowMovesCursor()            // marked {"a"}, menyu "b" ustida → cursor "b", targets ["b"]
@Test func menuOnMarkedRowKeepsMarks()
@Test func fileMenuEntries()                         // buyruqlar va separatorlar yuqoridagi tartibda; shortcut'lar "F5","F6","F2","⌘D","⌘⌫"
@Test func packageContentsOnlyForSinglePackage()
@Test func emptySpaceMenu()                          // newFolder, (paste), toggleHiddenFiles, separator, openInTerminal(.folder); title "Show Hidden Files" → toggle'dan keyin "Hide Hidden Files"
```

- [ ] **Step 2: Run** `--filter "MouseTests|ContextMenuTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add mouse rules, column sorting and context menu model`

---

### Task 7: Fayl buyruqlari, rename, clipboard, drop

**Files:**
- Create: `Sources/CommanderController/WindowModel+Files.swift`, `Tests/CommanderControllerTests/FileCommandTests.swift`, `RenameTests.swift`, `ClipboardTests.swift`, `DropPolicyTests.swift`
- Modify: `Texts.swift` (+ `RenameText`)

**Interfaces:**
- Consumes: `OperationCenter.start`, `FileActions.createFolder`, `FileActions.rename`, `RenameError`, `FilePasteboard`, `WindowEffects`
- Produces:
  ```swift
  extension WindowModel {
      public func commitRename(_ side: PaneSide, from oldName: String, to newName: String) async -> RenameError?
      public func dropOperation(_ urls: [URL], on side: PaneSide, intoFolder name: String?, forceCopy: Bool) -> DropOperation
      @discardableResult public func drop(_ urls: [URL], on side: PaneSide, intoFolder name: String?, forceCopy: Bool) -> Bool
  }
  public enum DropOperation: Equatable, Sendable { case copy, move, none }
  public enum DropPolicy {
      public static func operation(sources: [URL], destination: URL, forceCopy: Bool, sameVolume: (URL, URL) -> Bool) -> DropOperation
  }
  public enum RenameSelection { public static func editableLength(of name: String, kind: FileItem.Kind) -> Int }   // UTF-16 uzunlik
  public enum RenameText { public static func message(_ error: RenameError, newName: String) -> String }
  ```
- `perform` ga qo'shiladi:
  - copyToOtherPane / moveToOtherPane: manbalar `targets` URL'lari, manzil boshqa panel yo'li; `askDestinationForCopyMove` → `await effects.askDestination(default:kind:count:)`, `nil` → hech narsa. `operations.start(.copy/.move)`, manba tabidagi belgilar tozalanadi.
  - duplicate → `.copy(sources:, destination: joriy papka)` (CommanderKit bir papkada "copy" nomini o'zi beradi).
  - moveToTrash → `.trash(targets)`.
  - newFolder → `listingExecutor.run { try FileActions.createFolder(in:) }` → reload → kursor yangi nomda → `effects.beginRename(side, name:)`; xato → `effects.showAlert(AlertMessage(title: "Couldn't create a folder", detail: error.localizedDescription))`.
  - rename → `effects.beginRename(side, name: cursorItem.name)`.
  - copyToClipboard / cutToClipboard → `pasteboard.writeFiles(urls, cut:)`; paste → `readFiles()`: `isCut` → `.move` joriy papkaga va `clearCut()`, aks holda `.copy`.
  - copyPath / copyName → `writeString` (bir nechta bo'lsa `"\n"` bilan).
  - revealInFinder → `effects.revealInFinder(urls)`; openInTerminal → `.folder` yoki kursor navigable emas → joriy papka, navigable → o'sha papka; showPackageContents → `navigate(to:)` package ichiga.
- `commitRename`: nom o'zgarmagan → `nil`; `FileActions.rename` executor'da; muvaffaqiyat → reload, kursor yangi nomda, `nil`; xato → `RenameError`.
- `DropPolicy` qoidalari ketma-ket: manbalar bo'sh → `.none`; manzil biror manbaning o'zi yoki ichida (standartlashtirilgan yo'l komponentlari bo'yicha) → `.none`; hamma manbaning ota papkasi manzil → `.none`; `forceCopy` → `.copy`; hammasi `sameVolume` → `.move`; aks holda `.copy`.
- `drop` manzili: `name` navigable qator bo'lsa uning URL'i, aks holda panel yo'li; `.none` → `false`; aks holda `operations.start`, `true`.
- `RenameSelection`: papka va `.symlink(toDirectory: true)` → butun nom; fayl/package → oxirgi nuqtagacha (boshidagi nuqta hisoblanmaydi).
- `RenameText`: empty `"The name can't be empty."` · invalidCharacter `"Names can't contain “/” or “:”."` · alreadyExists `"The name “X” is already taken. Please choose a different name."` (X = newName) · failed(m) → m.

- [ ] **Step 1: Failing testlar** (haqiqiy TempDir, `DirectoryReader`, `FakePasteboard`, `RecordingEffects`)

```swift
// FileCommandTests
@Test func f5CopiesTargetsToOtherPane()               // waitUntilIdle → manzilda fayl; manba belgilari tozalangan
@Test func f6MovesTargets()
@Test func askDestinationUsesAnswer()                 // askDestinationForCopyMove = true; effects javobi boshqa papka → o'sha yerga; nil → hech narsa
@Test func duplicateCreatesCopyName()                 // "a.txt" → "a copy.txt"
@Test func trashUsesOperationCenter()                 // FakeTrasher (Task 3) trashed == [url]
@Test func newFolderCreatesThenBeginsRename()         // effects.renames == [(.left, "untitled folder")], cursor shu nomda
@Test func openInTerminalFolderScope()
// RenameTests
@Test func commitRenameMovesCursorToNewName()
@Test func commitRenameReturnsValidationError()       // "a/b" → .invalidCharacter, fayl joyida
@Test func unchangedNameIsNoOp()
@Test func editableLength()                           // "a.txt" → 1; "archive.tar.gz" → 11; ".bashrc" → 7; "dir"(.directory) → 3; "X.app"(.package) → 1; "📁x.txt" → 3
@Test func renameMessages()
// ClipboardTests
@Test func copyThenPasteCopies()
@Test func cutThenPasteMovesAndClearsCut()
@Test func copyPathAndNameJoinLines()                 // ikki target → "p1\np2"
// DropPolicyTests
@Test func sameVolumeMoves_otherVolumeCopies_optionCopies()
@Test func dropIntoSelfOrOwnFolderIsNone()            // /a → /a/sub → .none; /x/f → /x → .none
@Test func dropOntoFolderRowTargetsThatFolder()       // model.drop(..., intoFolder: "sub") → fayl sub ichida
```

- [ ] **Step 2: Run** `--filter "FileCommandTests|RenameTests|ClipboardTests|DropPolicyTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add file commands, rename, clipboard and drop handling`

---

### Task 8: Sidebar modeli, eject, Connect to Server

**Files:**
- Create: `Sources/CommanderController/SidebarModel.swift`, `WindowModel+Places.swift`, `Tests/CommanderControllerTests/SidebarModelTests.swift`, `PlacesTests.swift`
- Modify: `WindowModel.swift` — `public let sidebar: SidebarModel` init ichida `session.favorites`, `environment.volumes`, `environment.listingExecutor` dan yaratiladi (init imzosi o'zgarmaydi); `sessionSnapshot()` `favorites` ni sidebar'dan oladi; `sidebar.onChange` → `stateDidChange(.sidebar)` va `onSessionChange`

**Interfaces:**
- Consumes: `VolumeInfo`, `SMBAddress.normalize`, `Session.addRecentServer`, `ServerMounting`
- Produces:
  ```swift
  @MainActor public final class SidebarModel {
      public init(favorites: [URL], volumes: @escaping @Sendable () -> [VolumeInfo], executor: OperationExecutor)
      public private(set) var favorites: [URL]
      public private(set) var volumes: [VolumeInfo]
      public var onChange: (() -> Void)?
      public func refreshVolumes() async                    // volumes() executor'da (o'lik SMB bloklashi mumkin)
      @discardableResult public func addFavorite(_ url: URL, at index: Int? = nil) -> Bool   // faqat papka; standardized yo'l bo'yicha takror → false
      public func removeFavorite(at index: Int)
      public static func capacityText(_ volume: VolumeInfo) -> String?   // "B(avail) available of B(total)"; biri nil → nil
  }
  extension WindowModel {
      public var recentServers: [String] { get }
      public func setSidebarWidth(_ width: Double)
      public func openPlace(_ url: URL)                      // faol panelning faol tabi
      public func eject(_ volume: VolumeInfo) async
      public func connect(to address: String) async
  }
  ```
- `eject`: `environment.ejectVolume`; xato → `showAlert(AlertMessage(title: "Couldn't eject “name”", detail: localizedDescription))`; muvaffaqiyat → `refreshVolumes()` va shu volume ichidagi panellar `reload` (`.notFound` → eng yaqin ota papka, Task 4).
- `connect`: `SMBAddress.normalize` `nil` → `showAlert(AlertMessage(title: "Invalid server address", detail: "Enter an address like smb://server/share."))`; mount muvaffaqiyatli → `addRecentServer(url.absoluteString)`, `openPlace(mountPoint)`, `refreshVolumes()`, `onSessionChange`; `CancellationError` → jim; boshqa xato → `showAlert(AlertMessage(title: "Couldn't connect to “host”", detail: localizedDescription))`.

- [ ] **Step 1: Failing testlar**

```swift
// SidebarModelTests
@Test func addFavoriteOnlyFoldersNoDuplicates()      // papka → true; fayl → false; o'sha papka "/x/../x" ko'rinishida → false
@Test func addFavoriteAtIndexAndRemove()
@Test func refreshVolumesPublishes()                 // fake volumes → volumes, onChange chaqirilgan
@Test func capacityText()                            // avail 182e9, total 500e9 → "B(182e9) available of B(500e9)"; nil → nil
// PlacesTests
@Test func openPlaceNavigatesActiveTab()
@Test func connectMountsOpensAndRemembers()          // FakeMounter → TempDir; path == TempDir; recentServers.first == "smb://nas/share"
@Test func connectInvalidAddressAlerts()
@Test func connectCancelledIsSilent()                // FakeMounter CancellationError → alerts bo'sh
@Test func connectFailureAlertsWithMessage()
@Test func ejectFailureAlerts()
@Test func sessionIncludesFavoritesWidthAndServers()
```

- [ ] **Step 2: Run** `--filter "SidebarModelTests|PlacesTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add sidebar model, eject and Connect to Server flow`

---

### Task 9: Settings saqlash, shortcut muharriri, Settings view model, ishga tushirish

**Files:**
- Create: `Sources/CommanderController/SettingsPersistence.swift`, `ShortcutEditor.swift`, `SettingsViewModel.swift`, `Bootstrap.swift`, `Tests/CommanderControllerTests/SettingsPersistenceTests.swift`, `ShortcutEditorTests.swift`, `SettingsViewModelTests.swift`, `BootstrapTests.swift`
- Modify: `WindowModel.swift` — `updateSettings(_:)`, `onSettingsChange`

**Interfaces:**
- Consumes: `SettingsStore`, `DebouncedWriter`, `KeyBindings`, `WindowState.restored` (Task 4)
- Produces:
  ```swift
  public final class SettingsPersistence: Sendable {
      public init(store: SettingsStore, interval: Duration = .milliseconds(500))
      public func update(_ settings: AppSettings)
      public func update(_ session: Session)
      public func flushSynchronously()             // applicationWillTerminate'dan; kutayotgan snapshot'ni shu thread'da yozadi
  }
  public struct ShortcutRow: Equatable, Sendable { public let command: Command; public let title: String; public let chords: [KeyChord]; public let isCustom: Bool }
  public struct ShortcutEditor: Sendable {
      public init(behavior: BehaviorSettings, overrides: [Command: [KeyChord]])
      public private(set) var overrides: [Command: [KeyChord]]
      public var bindings: KeyBindings { get }
      public func rows(matching query: String) -> [ShortcutRow]      // Command.allCases tartibi; title yoki displayString bo'yicha, katta-kichik farqsiz; "" → hammasi
      public func conflicts(assigning chord: KeyChord, to command: Command) -> [Command]
      public mutating func assign(_ chord: KeyChord, to command: Command)   // overrides[command] = [chord]; chord boshqa override ro'yxatlaridan olib tashlanadi
      public mutating func clear(_ command: Command)                         // overrides[command] = []
      public mutating func restoreDefault(_ command: Command)
      public mutating func restoreAllDefaults()
      public mutating func setBehavior(_ behavior: BehaviorSettings)
  }
  public struct PendingConflict: Equatable, Sendable { public let chord: KeyChord; public let command: Command; public let owners: [Command]; public let message: String }
  @MainActor @Observable public final class SettingsViewModel {
      public init(settings: AppSettings, onChange: @escaping (AppSettings) -> Void)
      public var appearance: AppearanceSettings                // didSet → onChange
      public var behavior: BehaviorSettings                    // didSet → editor.setBehavior, onChange
      public var shortcutQuery: String                         // didSet → rows
      public private(set) var rows: [ShortcutRow]
      public private(set) var recording: Command?
      public private(set) var pendingConflict: PendingConflict?
      public func startRecording(_ command: Command)
      public func record(_ chord: KeyChord)                    // konfliktsiz → assign, onChange; konflikt → pendingConflict
      public func cancelRecording()
      public func confirmPendingAssignment()
      public func cancelPendingAssignment()
      public func restoreShortcutDefaults()
  }
  extension WindowModel {
      public func updateSettings(_ settings: AppSettings)
      public var onSettingsChange: ((AppSettings) -> Void)? { get set }   // WindowModel.swift ichidagi stored property
  }
  public struct LaunchOptions: Equatable, Sendable {
      public init(arguments: [String])                          // "-CKSettingsDirectory <p>" "-CKLeftPath <p>" "-CKRightPath <p>"
      public var settingsDirectory: URL?; public var leftPath: URL?; public var rightPath: URL?
  }
  public struct BootstrapResult: Sendable { public let settings: AppSettings; public let session: Session; public let state: WindowState; public let store: SettingsStore; public let warnings: [AlertMessage] }
  public enum AppBootstrap { public static func load(_ options: LaunchOptions, lister: any DirectoryListing) -> BootstrapResult }
  ```
- `SettingsPersistence`: kutayotgan `settings`/`session` snapshot'lari `Mutex` ichida; `update` snapshot'ni almashtiradi va `Task { await writer.schedule { self.writePending() } }`. `writePending` lock'ni **yozish tugaguncha** ushlab turadi, snapshot'larni oladi va `nil` qiladi; `flushSynchronously` = `writePending()`. Shu tufayli hech bir snapshot ikki marta yoki eskisi yangisidan keyin yozilmaydi va `DebouncedWriter.flush` (async) ga ehtiyoj yo'q. Yozish xatosi `os.Logger` ga, crash yo'q.
- `pendingConflict.message`: `"⌘D is already used by Duplicate."` (bir nechta egasi bo'lsa nomlar `", "` bilan).
- `updateSettings`: `bindings` qayta quriladi; `stateDidChange(.settings)` va `.window` (footer); `onSettingsChange`. `showHiddenByDefault` faqat yangi tablarga ta'sir qiladi.
- `AppBootstrap.load`: `store = SettingsStore(directory: options.settingsDirectory ?? SettingsStore.defaultDirectory)`; settings/session yuklanadi; har `corruptFileBackup` uchun warning `AlertMessage(title: "Settings were reset", detail: "The damaged file was saved as <backup path>.")`; `state = WindowState.restored(...)`; `leftPath`/`rightPath` berilgan bo'lsa o'sha panel bitta shu tab bilan ochiladi.

- [ ] **Step 1: Failing testlar**

```swift
// SettingsPersistenceTests (TempDir)
@Test func flushWritesSynchronously()          // update(settings) → flushSynchronously() → darhol loadSettings().value == settings
@Test func debouncedUpdateWritesAfterInterval() // interval 50 ms → eventually(1 s) fayl bor
@Test func latestSnapshotWins()                // A, B → flush → B
@Test func flushAfterDebouncedWriteNeverRegresses()   // A yozilgach B → flush → 200 ms kutish → hali B
// ShortcutEditorTests
@Test func rowsFilterByTitleAndChord()         // "trash" → [.moveToTrash]; "⌘D" → [.duplicate]
@Test func assignReportsAndStealsConflict()    // conflicts(cmd+d, .reload) == [.duplicate]; assign → cmd+d reload, duplicate'da cmd+d yo'q
@Test func assignRemovesChordFromOtherOverrides()   // newTab [cmd+n], keyin reload'ga cmd+n → newTab override bo'sh
@Test func restoreDefaultAndAll()
@Test func behaviorChangesBackspaceDefault()   // historyBack → goBack qatori chords ichida "backspace"
// SettingsViewModelTests
@Test func appearanceChangeCallsOnChangeImmediately()
@Test func recordWithoutConflictAssigns()
@Test func recordWithConflictWaitsForConfirmation()   // message == "⌘D is already used by Duplicate."; cancel → o'zgarmagan; confirm → tayinlangan
@Test func restoreShortcutDefaultsClearsOverrides()
// BootstrapTests
@Test func parsesLaunchOptions()
@Test func launchPathsOverrideSession()
@Test func corruptSettingsProduceOneWarning()
@Test func updateSettingsRebuildsBindings()    // WindowModel: override newTab [cmd+n] → handleKey(cmd+n) yangi tab ochadi, onSettingsChange chaqirilgan
```

- [ ] **Step 2: Run** `--filter "SettingsPersistenceTests|ShortcutEditorTests|SettingsViewModelTests|BootstrapTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS; to'liq `swift test --package-path Packages/CommanderKit` → hammasi PASS.
- [ ] **Step 5: Commit** — `Add settings persistence, shortcut editor and launch bootstrap`

---

### Task 10: XcodeGen loyihasi, App skeleti, UI test target

**Files:**
- Create: `project.yml`, `App/AppDelegate.swift`, `App/MainWindowController.swift` (hozircha bo'sh oyna), `AppUITests/SmokeTests.swift` (`testLaunchShowsMainWindow`)
- Modify: `.gitignore` (`Commander.xcodeproj/`, `App/Info.plist`, `build/`), `AGENTS.md` → "Build va test"

**Interfaces:**
- Consumes: `AppBootstrap`, `LaunchOptions`, `WindowModel`, `OperationCenter`, `SettingsPersistence`, `WindowEnvironment.live`
- Produces: `Commander.app` (bundle id `local.sanjar.commander`), scheme `Commander` (test action — `CommanderUITests`); `AppDelegate` `model`, `operations`, `persistence` ni ushlab turadi.

`project.yml` asosiy qiymatlari:
```yaml
name: Commander
options: { deploymentTarget: { macOS: "15.0" }, createIntermediateGroups: true }
packages: { CommanderKit: { path: Packages/CommanderKit } }
settings: { base: { SWIFT_VERSION: "6.0", ARCHS: x86_64, MACOSX_DEPLOYMENT_TARGET: "15.0" } }
targets:
  Commander:
    type: application
    platform: macOS
    sources: [App]
    dependencies:
      - { package: CommanderKit, product: CommanderController }
      - { package: CommanderKit, product: CommanderCore }
      - { package: CommanderKit, product: CommanderFileSystem }
    info: { path: App/Info.plist, properties: { CFBundleDisplayName: Commander, NSPrincipalClass: NSApplication, LSApplicationCategoryType: public.app-category.utilities } }
    settings: { base: { PRODUCT_BUNDLE_IDENTIFIER: local.sanjar.commander, CODE_SIGN_IDENTITY: "-", ENABLE_HARDENED_RUNTIME: NO, ENABLE_APP_SANDBOX: NO } }
  CommanderUITests:
    type: bundle.ui-testing
    platform: macOS
    sources: [AppUITests]
    dependencies: [{ target: Commander }]
schemes:
  Commander:
    build: { targets: { Commander: all, CommanderUITests: [test] } }
    test: { targets: [CommanderUITests] }
```

- [ ] **Step 1: XcodeGen o'rnatish** — `brew install xcodegen`; tekshiruv: `xcodegen --version` versiya chiqaradi.
- [ ] **Step 2: Failing UI test `testLaunchShowsMainWindow`** — `XCUIApplication().launchArguments = ["-CKSettingsDirectory", tmp, "-CKLeftPath", tmpA, "-CKRightPath", tmpB]`; `app.windows["Commander"]` 5 s ichida mavjud.
- [ ] **Step 3: Run** `xcodegen generate && xcodebuild test -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64'` → FAIL (App kodi yo'q).
- [ ] **Step 4: `project.yml`, `AppDelegate`, bo'sh `MainWindowController` ni yozish.** `AppDelegate` — `@main`, `static func main()` (NSApplication, delegate, `run()`). `applicationDidFinishLaunching`: `LaunchOptions(arguments: ProcessInfo.processInfo.arguments)` → `AppBootstrap.load` → `SettingsPersistence(store:)` → `OperationCenter` → `WindowModel` → `onSessionChange`/`onSettingsChange` → `persistence.update` → `model.start()`. Oyna sarlavhasi "Commander", `setFrameAutosaveName("MainWindow")`, default 1100×700, min 800×480; `applicationShouldTerminateAfterLastWindowClosed` → `true`. `bootstrap.warnings` → oyna ochilgach alert.
- [ ] **Step 5: Run** Step 3 buyrug'i → `testLaunchShowsMainWindow` PASS. Birinchi ishga tushishda macOS test runner'ga Accessibility/Automation ruxsatini so'raydi — foydalanuvchi beradi.
- [ ] **Step 6: `AGENTS.md` "Build va test" ga qo'shish** (va "App target hali yaratilmagan" qatorini olib tashlash):
  ```
  Xcode loyihasini generatsiya qilish: xcodegen generate
  App build: xcodebuild -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64' build
  UI smoke testlar: xcodebuild test -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64'
  Eslatma: ad-hoc imzo har build'da o'zgaradi — Full Disk Access ruxsatini qayta berish kerak bo'lishi mumkin.
  ```
- [ ] **Step 7: Commit** — `git add project.yml App AppUITests .gitignore AGENTS.md` → `Add XcodeGen project, app skeleton and UI test target`

---

### Task 11: Asosiy oyna, panellar va jadvalni chizish

**Files:**
- Create: `App/PanesViewController.swift`, `App/Pane/PaneViewController.swift`, `TabBarView.swift`, `FileTableView.swift` (hozircha faqat subclass), `FileTableController.swift`, `FileRowView.swift`, `App/System/IconCache.swift`, `App/System/AppKitEffects.swift`
- Modify: `App/MainWindowController.swift`, `App/AppDelegate.swift`

**Interfaces:**
- Consumes: `WindowModel.tab(_:)`, `listingVersion(_:)`, `banner(_:)`, `state.activeSide`, `activate`, `selectTab`, `closeTab`, `perform(.newTab)`, `setPageSize`, `PaneText.status`, `WindowEffects`
- Produces: `MainWindowController.pane(_ side: PaneSide) -> PaneViewController`; `PaneViewController.render()`, `.table`, `.pathField`; `AppKitEffects: WindowEffects` — bu task'da `stateDidChange` (tegishli `render`), `open` (`NSWorkspace.shared.open`), `revealInFinder` (`activateFileViewerSelecting`), `openInTerminal` (`open([dir], withApplicationAt: /System/Applications/Utilities/Terminal.app, configuration:)`), `beep` (`NSSound.beep()`); qolganlari keyingi task'larda.

Qarorlar:
- Oyna: `NSSplitViewController` — sidebar item (`NSSplitViewItem(sidebarWithViewController:)`, bu task'da bo'sh placeholder, kenglik `session.sidebarWidth`) + `PanesViewController` (vertikal stack: gorizontal `NSSplitView` ichida ikki teng `PaneViewController`, keyin selection bar va footer joylari — Task 14).
- Panel: tab bar (35 pt; tab click → `selectTab`, "×" → `closeTab`, "+" → `perform(.newTab)`) · path qatori (`NSTextField`, monospace 11 pt, `tab.path.path`) · `AccessBannerView` joyi (yashirin) · `NSScrollView` + `FileTableView` · status qatori (27 pt, `PaneText.status`). Faol panel tepasida 2 pt accent chiziq. Panelning istalgan joyiga click (tab bar, path qatori, status) → `activate(side)` (event'ni yutmaydigan `NSClickGestureRecognizer`).
- Jadval: view-based, ustunlar `name` (moslashuvchan, min 160), `size` (80, o'ngga tekislangan, papka va package'da `"--"`, aks holda `ByteCountFormatter` `.file`), `modified` (150, `Date.FormatStyle(date: .abbreviated, time: .shortened)` — bitta keshlangan formatter); `selectionHighlightStyle = .none`, `allowsTypeSelect = false`, `tableView(_:shouldSelectRow:)` → `false`; qator balandligi, shrift, ikonka o'lchami — `settings.appearance`.
- `FileRowView`: marked → marked foni; faol paneldagi kursor → cursor foni + chap chekkada 2 pt accent chiziq; marked qatorda nom oldida to'ldirilgan check belgisi (`#5b8bd6`). Ranglar — Global Constraints'dagi qiymatlar, `NSColor(name:dynamicProvider:)` bilan light/dark.
- `render()`: `listingVersion` o'zgargan → `reloadData()`; aks holda faqat eski/yangi kursor qatorlari va eski/yangi `marked` simmetrik farqi `reloadData(forRowIndexes:columnIndexes:)`; so'ng `scrollRowToVisible(cursorIndex)`. Jadval o'lchami o'zgarganda `setPageSize(side, rows: Int(visibleRect.height / rowHeight))`.
- `IconCache`: papka — bitta `NSWorkspace.shared.icon(for: .folder)`; fayl — kengaytma bo'yicha `icon(for: UTType(filenameExtension:) ?? .data)`; package va symlink — `icon(forFile:)` yo'l bo'yicha; hammasi `NSCache` da.
- Accessibility identifier'lar: `pane.left/right` (accessibilityValue `"active"`/`"inactive"`), `table.left/right`, `path.left/right`, `status.left/right`; name hujayrasi textField'ining qiymati — fayl nomi.
- Performance belgisi: `os_signpost` interval `"Listing"` — `reload` boshlanishidan `reloadData` tugashigacha (Task 19 da o'lchanadi).

- [ ] **Step 1: Implement qilish** (yuqoridagi qarorlar bo'yicha).
- [ ] **Step 2: Build** `xcodegen generate && xcodebuild -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64' build` → BUILD SUCCEEDED.
- [ ] **Step 3: Qo'lda tekshirish** — ikki panel Home'ni ko'rsatadi, papkalar yuqorida, status `"N items · X"`; "+" yangi tab, "×" yopadi (oxirgisi yopilmaydi); Finder'da fayl yaratish 1 s ichida panelda paydo bo'ladi; Dark mode'da ranglar maketdagidek; `testLaunchShowsMainWindow` hali PASS.
- [ ] **Step 4: Commit** — `Render main window, panes, tabs and file tables`

---

### Task 12: Klaviatura yo'li, menyu, path field, inline rename

**Files:**
- Create: `App/KeyRouter.swift`, `App/MainMenu.swift`, `App/Pane/RenameEditor.swift`
- Modify: `App/Pane/PaneViewController.swift`, `FileTableView.swift`, `App/System/AppKitEffects.swift` (`focusPathField`, `beginRename`, `showSettings` vaqtincha bo'sh), `App/AppDelegate.swift`

**Interfaces:**
- Consumes: `KeyChordMapper.chord`, `WindowModel.handleKey`, `isEnabled`, `typeAhead`, `goToPath`, `commitRename`, `RenameSelection.editableLength`, `RenameText.message`, `bindings.chords(for:)`, `Command.title`
- Produces: `KeyRouter.currentContext: FocusContext`; `MainMenu.build(model:keyRouter:) -> NSMenu`, `MainMenu.refreshKeyEquivalents()`

Qarorlar:
- `KeyRouter`: `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`. Faqat `event.window` asosiy oyna va `attachedSheet == nil` bo'lsa ishlaydi, aks holda event o'zgarmay qaytadi. Kontekst: `window.firstResponder is NSText` (field editor) → `.textField`, aks holda `.table`. Chord: `KeyChordMapper.chord(keyCode: event.keyCode, baseCharacters: event.characters(byApplyingModifiers: []), modifiers:)` — `.function`, `.numericPad`, `.capsLock` flag'lari tashlanadi. `model.handleKey` `true` → `nil` (yutiladi). `.table` da `false` bo'lsa, `⌘⌃⌥` yo'q va `event.characters` yagona harf yoki raqam → `model.typeAhead(char)`, `nil`. Qolgan hollarda event qaytariladi (matn tahriri va standart Edit menyu ishlaydi).
- `MainMenu` (dasturiy): App (About, Settings… `openSettings`, Hide, Quit `⌘Q`) · File (New Tab, Close Tab, New Folder, Rename, Duplicate, Copy to Other Pane, Move to Other Pane, Move to Trash, —, Connect to Server…) · Edit (standart `undo:`, `redo:`, `cut:`, `copy:`, `paste:`, `selectAll:` + Copy Path, Copy Name) · View (Show / Hide Hidden Files, Reload) · Go (Back, Forward, Enclosing Folder, Go to Path…) · Window (Next Tab, Previous Tab, Switch Pane, Minimize). Buyruq bandlari: `action: #selector(performCommand(_:))`, `representedObject` = `Command`, key equivalent — `bindings.chords(for:).first` dan (`KeyEquivalent` jadvali: harf/belgi o'zi; strelkalar `NSUpArrowFunctionKey`…, home/end/pageUp/pageDown — mos `NS…FunctionKey`, backspace `"\u{8}"`, forwardDelete `NSDeleteFunctionKey`, return `"\r"`, tab `"\t"`, space `" "`, escape `"\u{1b}"`, fN `NSF1FunctionKey + N - 1`). `validateMenuItem` → `model.isEnabled(command, context: keyRouter.currentContext)` — matn maydonida taqiqlangan bandlar o'chiq, shuning uchun ularning key equivalent'i ham ishlamaydi. Settings o'zgarganda key equivalent'lar qayta o'rnatiladi.
- `FileTableView` `copy:`/`cut:`/`paste:`/`selectAll:` → `perform(.copyToClipboard/.cutToClipboard/.paste/.markAll)`; `undo:` amalga oshirilmaydi (jadvalda `⌘Z` o'chiq). `becomeFirstResponder` → `model.activate(side)`. Panel faollashganda shu jadval first responder qilinadi.
- Path field delegate: `insertNewline:` → `goToPath`; `true` → jadvalga fokus, `false` → fokus qoladi; `cancelOperation:` (Esc) → matn `tab.path.path` ga qaytadi, jadvalga fokus. Tahrir paytida `render()` field matnini almashtirmaydi. `focusPathField` → first responder + butun matn tanlanadi.
- `RenameEditor`: kursordagi qator name hujayrasi textField'ini editable qiladi, `selectedRange = NSRange(location: 0, length: editableLength)`; Return yoki fokus yo'qolishi → `await commitRename`; xato → `RenameText.message` bilan sheet alert, so'ng tahrir davom etadi; Esc → bekor, jadvalga fokus.

- [ ] **Step 1: Implement qilish.**
- [ ] **Step 2: Build** → BUILD SUCCEEDED.
- [ ] **Step 3: Qo'lda tekshirish** (spec 5-bo'lim jadvali bo'yicha har tugma): `↑↓ Home End PgUp PgDn`, `⇧↑/⇧↓`, `Space`, `⌘A`, `Return`/`⌘↓`, `⌫`/`⌘↑`, `⌘[`/`⌘]`, `Tab`, `⌘T`/`⌘W`, `⌃Tab`/`⌃⇧Tab`, `⌘L` + Return/Esc, `⌘R`, `⌘⇧.`, `F2`/`⇧F6` rename (nom stem'i tanlangan, Esc bekor qiladi), harf terish type-ahead. Path field'da `⌫`, `Space`, `⌘⌫`, `⌘D`, `⌘A`, `⌘Z` matnni tahrirlaydi, fayllarga tegmaydi; `⌘T` yangi tab ochadi.
- [ ] **Step 4: Commit** — `Route keys through KeyBindings and add menus, path field and inline rename`

---

### Task 13: Mouse, kontekst menyu, ustun bo'yicha saralash

**Files:**
- Modify: `App/Pane/FileTableView.swift`, `FileTableController.swift`

**Interfaces:**
- Consumes: `WindowModel.click`, `doubleClick`, `contextMenu`, `perform(_:scope:)`, `sortColumnClicked`, `SlowClick.shouldBeginRename`
- Produces: `FileTableView.onBeginDrag: ((_ row: Int, _ event: NSEvent) -> Void)?` (Task 15 ishlatadi)

Qarorlar:
- `mouseDown` `super` ni chaqirmaydi: `row(at:)` → nom (yoki bo'sh joy `nil`); `onNameText` — name hujayrasi textField frame'iga tushish; `paneWasActive` va `cursorBefore` click'dan oldin olinadi. `clickCount >= 2` → `doubleClick`; aks holda `click(side, row:, modifiers:)`, so'ng `SlowClick.shouldBeginRename` → `NSEvent.doubleClickInterval` dan keyin `perform(.rename)` taymeri. Taymer keyingi `mouseDown`, `keyDown`, `scrollWheel` yoki kursor o'zgarishida bekor qilinadi. Sudrash: `window.nextEvent(matching: [.leftMouseUp, .leftMouseDragged])` bilan kuzatiladi; 3 pt dan ko'p siljish → `onBeginDrag` (taymer bekor).
- `menu(for:)` → `contextMenu(side, row:)` → `NSMenu` (`.entry` → band: `title`, shortcut ko'rinishi uchun key equivalent, action → `perform(entry.command, scope: entry.scope)`; `.separator`).
- Ustun sarlavhasi: `tableView(_:didClick:)` → `sortColumnClicked`; joriy ustunda `NSAscendingSortIndicator`/`NSDescendingSortIndicator`; `sortDescriptorPrototype` ishlatilmaydi.

- [ ] **Step 1: Implement qilish.**
- [ ] **Step 2: Build** → BUILD SUCCEEDED.
- [ ] **Step 3: Qo'lda tekshirish** (spec 6-bo'lim): click kursor qo'yadi, belgilar qoladi; ikkinchi panelga click uni faol qiladi; `⌘`+click, `⇧`+click; double-click papka/fayl; kursordagi nomga pauzadan keyin click → rename, tez double-click → rename emas; o'ng tugma belgilangan va belgilanmagan qator ustida (spec 2.1 bandlari, Show Package Contents faqat `.app` da), bo'sh joyda; sarlavha click — saralash va yo'nalish.
- [ ] **Step 4: Commit** — `Add mouse handling, context menus and column sorting`

---

### Task 14: Selection bar, footer va progress, dialoglar, Full Disk Access banner

**Files:**
- Create: `App/Window/SelectionBarView.swift`, `App/Window/FooterView.swift`, `App/Dialogs/AlertPrompts.swift`, `App/Pane/AccessBannerView.swift`
- Modify: `App/PanesViewController.swift`, `App/Pane/PaneViewController.swift`, `App/System/AppKitEffects.swift` (`askDestination`, `showAlert`), `App/AppDelegate.swift` (`AlertPrompts` → `OperationCenter`)

**Interfaces:**
- Consumes: `PaneText.selectionSummary`, `FooterHints.items`, `OperationCenter.operations`, `cancel(_:)`, `OperationText.summary`, `FailureText.message`, `OperationPrompts`, `banner(_:)`
- Produces: `AlertPrompts: OperationPrompts` (asosiy oynaga sheet)

Qarorlar:
- Selection bar (42 pt) faqat faol tabda belgilanganlar bo'lsa: chapda `selectionSummary`; o'ngda Copy / Move / Trash tugmalari (yonida `bindings` dagi `F5`, `F6`, `⌘⌫`) → `perform(.copyToOtherPane/.moveToOtherPane/.moveToTrash)`.
- Footer (28 pt): amal yo'q → `FooterHints` (ramkali tugma belgisi + nom, markazda). Amallar bor → har biri qator (24 pt): determinate `NSProgressIndicator` (`completedBytes/totalBytes`, bayt 0 bo'lsa fayllar soni), `OperationText.summary`, "Cancel" → `cancel(id)`; ko'pi bilan 3 qator, qolgani `"+N more"`.
- `AlertPrompts` — `NSAlert.beginSheetModal` + `withCheckedContinuation`:
  - Konflikt: message `"An item named “N” already exists in this location."`, informative `"Do you want to replace it?"`, tugmalar Replace (default) · Keep Both · Skip, `showsSuppressionButton` sarlavhasi `"Apply to All"` → `ConflictResolution(decision:applyToAll:)`.
  - Xato: message `FailureText.message`, tugmalar Retry · Skip · Cancel All.
  - Butunlay o'chirish: message `"These items can't be moved to the Trash."`, informative `"They will be deleted immediately. You can't undo this action."` + birinchi 5 nom; tugmalar Delete (`hasDestructiveAction = true`) · Cancel (Esc).
- `askDestination`: NSAlert `"Copy N items to:"` / `"Move N items to:"`, accessory `NSTextField` (default yo'l); OK → mavjud papka bo'lsa URL, aks holda beep va dialog qayta; Cancel → `nil`.
- `showAlert` → oddiy sheet alert.
- `AccessBannerView` (jadval ustida): `.noAccess` → `"Commander can't read this folder."` + `"Grant Full Disk Access in System Settings → Privacy & Security."` + "Open Privacy Settings" tugmasi → `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`; `.unreadable(m)` → m, tugmasiz.

- [ ] **Step 1: Implement qilish.**
- [ ] **Step 2: Build** → BUILD SUCCEEDED.
- [ ] **Step 3: Qo'lda tekshirish**: belgilash → selection bar chiqadi, belgilar olinsa yo'qoladi; katta fayl `F5` → footer progress, Cancel → chala fayl o'chadi; ikki parallel copy footer'da ikki qator; konfliktda Replace / Skip / Keep both + Apply to All; ruxsatsiz fayl → Retry / Skip / Cancel All; Trash'siz volume (masalan FAT disk image) → butunlay o'chirish tasdig'i; FDA'siz `~/Library/Mail` → banner, tugma System Settings'ni ochadi; Behavior'da "Ask for destination" yoqilganda F5 dialogi (Task 17 dan keyin ham qayta tekshiriladi).
- [ ] **Step 4: Commit** — `Add selection bar, operation footer, dialogs and access banner`

---

### Task 15: Drag & drop va tizim clipboard'i

**Files:**
- Create: `App/System/SystemPasteboard.swift`
- Modify: `App/Pane/FileTableView.swift`, `FileTableController.swift`, `App/AppDelegate.swift`

**Interfaces:**
- Consumes: `FileTableView.onBeginDrag`, `WindowModel.dropOperation`, `drop`, `tab(_:).targets`, `FilePasteboard`
- Produces: `SystemPasteboard: FilePasteboard`

Qarorlar:
- Drag manbai: sudralgan qator belgilangan bo'lsa — barcha belgilanganlar, aks holda kursor shu qatorga qo'yiladi va faqat u; `beginDraggingSession(with: [NSDraggingItem(pasteboardWriter: url as NSURL)], event:, source:)`, rasm — ikonka + nom. `sourceOperationMaskFor`: `.outsideApplication` → `[.copy, .move, .link, .generic]`, ilova ichida → `[.copy, .move]`.
- Drop manzili: jadval `registerForDraggedTypes([.fileURL])`; `validateDrop` — papka qatori ustida `.on` (shu papkaga), boshqa joyda `setDropRow(-1, dropOperation: .on)` (panel papkasiga); `dropOperation(urls, side, intoFolder:, forceCopy: NSEvent.modifierFlags.contains(.option))` → `.copy`/`.move`/`[]`; `acceptDrop` → `drop(...)`. URL'lar `readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])`.
- `SystemPasteboard`: `writeFiles` → `clearContents()`, `writeObjects(urls as [NSURL])`; `cut == true` bo'lsa qo'shimcha `NSPasteboard.PasteboardType("local.sanjar.commander.cut")` va `changeCount` eslab qolinadi. `readFiles` → fayl URL'lari yo'q → `nil`; `isCut` faqat marker bor va `changeCount` o'zgarmagan bo'lsa. `clearCut` → eslangan `changeCount` tozalanadi. `writeString` → `clearContents()`, `setString(_:forType: .string)`.

- [ ] **Step 1: Implement qilish.**
- [ ] **Step 2: Build** → BUILD SUCCEEDED.
- [ ] **Step 3: Qo'lda tekshirish** (spec 6-bo'lim): panellar orasida bir volume'da move, boshqa volume'ga copy, `⌥` bilan doim copy; papka qatori ustiga tashlash; Finder'dan ichkariga va ichkaridan Finder'ga; Dock'dagi ilova ikonkasiga tashlash faylni ochadi; `⌘C` → Finder'da `⌘V`; Finder'da `⌘C` → panelda `⌘V`; `⌘X`, so'ng boshqa ilovada nimadir copy qilingach `⌘V` — move **emas**.
- [ ] **Step 4: Commit** — `Add drag and drop and system pasteboard`

---

### Task 16: Places sidebar, eject, Connect to Server (NetFS)

**Files:**
- Create: `App/Sidebar/SidebarViewController.swift`, `App/Dialogs/ConnectToServerView.swift`, `App/System/NetFSMounter.swift`
- Modify: `App/MainWindowController.swift`, `App/System/AppKitEffects.swift` (`showConnectToServer`), `App/AppDelegate.swift`

**Interfaces:**
- Consumes: `WindowModel.sidebar`, `SidebarModel.capacityText`, `addFavorite`, `removeFavorite`, `refreshVolumes`, `openPlace`, `eject`, `connect(to:)`, `recentServers`, `setSidebarWidth`, `appDidBecomeActive`
- Produces: `NetFSMounter: ServerMounting` (`WindowEnvironment.live(mounter:)` ga beriladi)

Qarorlar:
- Sidebar: `NSOutlineView` `.sourceList`, guruhlar "Favorites" va "Locations". Qator: ikonka (`NSWorkspace.icon(forFile:)`), nom (`FileManager.displayName(atPath:)`); volume qatorida ikkinchi qator `capacityText` va `isEjectable || isNetwork` bo'lsa eject tugmasi → `await eject`. Click → `openPlace(url)`. Favorite ustida o'ng tugma → "Remove from Sidebar". Favorites guruhiga papka tashlash → `addFavorite(_:at:)` (faqat papka bo'lsa drop qabul qilinadi). Split view kengligi o'zgarsa → `setSidebarWidth`.
- `NSWorkspace.shared.notificationCenter`: `didMountNotification`, `didUnmountNotification`, `didRenameVolumeNotification` → `await sidebar.refreshVolumes()`. `NSApplication.didBecomeActiveNotification` → `model.appDidBecomeActive()`.
- `ConnectToServerView` (SwiftUI, sheet): "Server Address" `TextField` (placeholder `smb://server/share`), "Recent Servers" ro'yxati (click → maydonga), Cancel / Connect (default) tugmalari; Connect → sheet yopiladi, `Task { await model.connect(to:) }`.
- `NetFSMounter.mount`: `NetFSMountURLAsync(url, nil, nil, nil, [kNAUIOptionKey: kNAUIOptionAllowUI], nil, &requestID, .main) { status, _, mountpoints in … }` → continuation. `status == 0` → birinchi mount nuqtasi URL; `ECANCELED` yoki `userCanceledErr` (-128) → `CancellationError`; boshqa → `NSError(domain: (1...ELAST).contains(status) ? NSPOSIXErrorDomain : NSOSStatusErrorDomain, code: Int(status))`.

- [ ] **Step 1: Implement qilish.**
- [ ] **Step 2: Build** → BUILD SUCCEEDED.
- [ ] **Step 3: Qo'lda tekshirish** (spec 7-bo'lim): Favorites — default 5 band; Favorites'ga papka sudrash va Remove; disk image ulash → Locations'da bo'sh joy bilan paydo bo'ladi, eject → yo'qoladi, shu diskdagi panel ota papkaga o'tadi; `⌘K` → `smb://<NAS>/<share>` → macOS login oynasi → `/Volumes/<share>` faol panelda va sidebar'da; noto'g'ri server → macOS xato matni bilan alert; login bekor → alert yo'q; `⌘K` oynasida oxirgi manzil turadi.
- [ ] **Step 4: Commit** — `Add Places sidebar, eject and Connect to Server via NetFS`

---

### Task 17: Settings oynasi, ko'rinish, chiqishda saqlash

**Files:**
- Create: `App/Settings/SettingsWindowController.swift`, `AppearanceView.swift`, `BehaviorView.swift`, `ShortcutsView.swift`, `ShortcutRecorder.swift`
- Modify: `App/AppDelegate.swift`, `App/System/AppKitEffects.swift` (`showSettings`, `.settings` holatini qo'llash), `App/Pane/PaneViewController.swift`, `App/MainMenu.swift`

**Interfaces:**
- Consumes: `SettingsViewModel`, `WindowModel.updateSettings`, `settings`, `KeyChordMapper`, `KeyChord.displayString`, `SettingsPersistence.flushSynchronously`, `OperationCenter.isIdle`, `cancelAll`, `waitUntilIdle`, `sessionSnapshot`
- Produces: `SettingsWindowController.show(model: WindowModel)` (bitta nusxa)

Qarorlar:
- Oyna: sarlavha "Settings", `NSHostingController(rootView: SettingsView(model:))`, SwiftUI `TabView`: Appearance · Behavior · Shortcuts. `SettingsViewModel(settings: model.settings, onChange: model.updateSettings)`.
- Appearance: Theme segmented (System / Light / Dark); "File name" shrift `Picker` (System + `NSFontManager.shared.availableFontFamilies`) va o'lcham slider 11–18; "Icon size" 12–32; "Row height" 18–36; pastda "LIVE PREVIEW" — 3 namunaviy qator. Asosiy oyna ham darhol yangilanadi.
- Behavior (maket yozuvlari): "Backspace" — Parent folder / Go back in history; "After marking a file" — Move to next row / Stay on the row; "Copy & move to other pane" — Start immediately / Ask for destination; "Also use Forward Delete" (izoh `"Fn + ⌫ or an external Delete key"`); "Show hidden files by default"; "Restore tabs on launch".
- Shortcuts: qidiruv maydoni (`shortcutQuery`), qatorlar (`title`, chord'lar `displayString`, `isCustom` belgisi); chord tugmasi click → `startRecording`; `ShortcutRecorder` (`NSViewRepresentable`, first responder bo'ladigan NSView): `keyDown` → `KeyChordMapper` → `record`, Esc → `cancelRecording`. Pastda status: `pendingConflict.message` + "Assign Anyway" / "Cancel"; bo'lmasa `"Duplicates are detected before a shortcut is assigned."`. "Restore defaults" → `restoreShortcutDefaults`. (KeyRouter faqat asosiy oynada ishlagani uchun yozib olish paytida tugmalar buyruqqa aylanmaydi.)
- `.settings` holati: `NSApp.appearance` (`nil` / `.aqua` / `.darkAqua`); panellar qator balandligi, shrift, ikonka o'lchami bilan `reloadData`; `MainMenu.refreshKeyEquivalents()`.
- Chiqish: `applicationShouldTerminate` — `operations.isIdle == false` → alert `"N operations are still running."` / `"Quitting will cancel them."` (Quit · Cancel); Quit → `cancelAll()`, `Task { await waitUntilIdle()` (ko'pi bilan 5 s) `; NSApp.reply(toApplicationShouldTerminate: true) }`, `.terminateLater`. `applicationWillTerminate` → `persistence.update(model.sessionSnapshot())`, `persistence.update(model.settings)`, `persistence.flushSynchronously()`.

- [ ] **Step 1: Implement qilish.**
- [ ] **Step 2: Build** → BUILD SUCCEEDED.
- [ ] **Step 3: Qo'lda tekshirish** (spec 9-bo'lim): `⌘,` oynani ochadi; theme, shrift, qator balandligi darhol ko'rinadi; Backspace = history back ishlaydi va footer'da "Back"; `newTab` ga `⌘D` yozish → "⌘D is already used by Duplicate." → Assign Anyway → `⌘D` yangi tab ochadi va menyuda ko'rinadi; Restore defaults; ilovani yopib ochish → tablar, papkalar, faol panel, sidebar kengligi, favorites, oyna frame va Settings o'zgarishlari tiklanadi; "Restore tabs on launch" o'chiq → Home; `settings.json` ga `{not json` yozib ochish → bir marta ogohlantirish, `settings.broken-*.json` paydo bo'ladi; katta copy paytida `⌘Q` → tasdiq, chala fayl qolmaydi, session saqlangan.
- [ ] **Step 4: Commit** — `Add SwiftUI Settings window, appearance and quit-time persistence`

---

### Task 18: XCUITest smoke testlar

**Files:**
- Modify: `AppUITests/SmokeTests.swift`

**Interfaces:**
- Consumes: Task 11 accessibility identifier'lari, `LaunchOptions` argumentlari

Har test o'z vaqtinchalik papkasini yaratadi (`FileManager.default.temporaryDirectory/<UUID>`): `left/alpha.txt` (3 bayt), `right/`, `nested/sub/`, `settings/`; `launchArguments = ["-CKSettingsDirectory", settings, "-CKLeftPath", <yo'l>, "-CKRightPath", right]`. Kutishlar — `waitForExistence(timeout: 5)` / `XCTNSPredicateExpectation`.

- [ ] **Step 1: Testlarni yozish**

```swift
func testLaunchShowsBothPanes()                 // CKLeftPath = left → path.left value == left yo'li; table.left ichida "alpha.txt"
func testTabSwitchesActivePane()                // pane.left value "active" → typeKey(.tab, modifierFlags: []) → pane.right "active"
func testBackspaceGoesUp()                      // CKLeftPath = nested/sub → typeKey(.delete, modifierFlags: []) → path.left == nested
func testF5CopiesToOtherPane()                  // CKLeftPath = left (kursor alpha.txt da) → typeKey(.F5, modifierFlags: []) → 5 s ichida right/alpha.txt mavjud va table.right'da "alpha.txt"
func testPathFieldEditingDoesNotTouchFiles()    // typeKey("l", modifierFlags: .command) → typeText("x") → typeKey(.delete, modifierFlags: .command) → left/alpha.txt hali bor, path.left hali fokusda
```

- [ ] **Step 2: Run** `xcodebuild test -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64'` → 6 test PASS (`testLaunchShowsMainWindow` bilan). FAIL bo'lsa — App xatosi, `superpowers:systematic-debugging` bilan tuzatiladi.
- [ ] **Step 3: Commit** — `Add XCUITest smoke tests`

---

### Task 19: Performance o'lchovi va hujjatlar

**Files:**
- Modify: `AGENTS.md` ("Joriy holat"), `docs/brainstorm/2026-10-21-commander-decisions.md` ("Ochiq savollar"), `docs/superpowers/specs/2026-10-21-phase1-core-design.md` (3-qator: B plan yo'li; 7-bo'lim SMB qatori: "NetFS orqali")

- [ ] **Step 1: Release build** — `xcodebuild -project Commander.xcodeproj -scheme Commander -configuration Release -destination 'platform=macOS,arch=x86_64' -derivedDataPath build build`.
- [ ] **Step 2: Cold start ≤ 1 s** — `sudo purge`, so'ng 3 marta `xcrun xctrace record --template 'App Launch' --output build/launch-N.trace --launch -- build/Build/Products/Release/Commander.app`; Instruments'da birinchi kadrgacha vaqt — 3 o'lchov medianasi ≤ 1 s.
- [ ] **Step 3: Bo'sh holat RAM ≤ 100 MB** — ilova ikki panelda Home bilan ochiladi, 30 s tegilmaydi; `footprint -p $(pgrep -x Commander)` → `phys_footprint` ≤ 100 MB.
- [ ] **Step 4: 5 000 faylli papka** — `mkdir -p /tmp/ck5000 && cd /tmp/ck5000 && touch f{1..5000}.txt`; panelda ochish; Instruments "os_signpost" bilan `"Listing"` interval ≤ 100 ms; `PgDn` bilan yurish silliq.
- [ ] **Step 5: Natijalar** — o'lchangan qiymatlar `AGENTS.md` "Joriy holat" ga va commit xabariga yoziladi. Maqsaddan oshsa — foydalanuvchiga xabar beriladi, tuzatish alohida task sifatida taklif qilinadi (bu plan doirasida optimizatsiya qilinmaydi).
- [ ] **Step 6: Hujjatlar** — `AGENTS.md`: "1-bosqich yakunlandi (A + B)", B plan yo'li; decisions faylida B bajarilgani va NetFS qarori; spec'dagi yuqoridagi ikki qator.
- [ ] **Step 7: Commit** — `Record phase 1 performance measurements and status`
