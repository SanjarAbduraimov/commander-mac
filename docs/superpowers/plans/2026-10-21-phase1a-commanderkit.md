# 1-bosqich A — CommanderKit (Core + FileSystem) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 1-bosqichning UI'siz qismini — holat modeli, buyruqlar, shortcut'lar, Settings saqlash, papka o'qish/kuzatish va fayl amallarini — `swift test` bilan to'liq test qilingan local Swift Package sifatida qurish.

**Architecture:** `Packages/CommanderKit` — ikki library target: `CommanderCore` (faqat Foundation; holat, `Command`, `KeyBindings`, Settings, amal turlari) va `CommanderFileSystem` (Core'ga bog'liq; o'qish, FSEvents, amallar, volume'lar). AppKit import qilinmaydi. App UI (1-bosqich B plan'i) shu package'ni ishlatadi va keyinroq alohida yoziladi.

**Tech Stack:** Swift 6 (language mode 6, strict concurrency), SwiftPM, Swift Testing (`import Testing`), Foundation, CoreServices (FSEvents), Darwin `copyfile(3)`, `Synchronization.Mutex`.

**Spec:** `docs/superpowers/specs/2026-10-21-phase1-core-design.md`

## Global Constraints

- macOS 15.0+ (`platforms: [.macOS(.v15)]`), asosiy qurilma x86_64 Intel, macOS 15.7.9.
- `CommanderCore` va `CommanderFileSystem` **AppKit/SwiftUI import qilmaydi**.
- Tashqi dependency yo'q (faqat Apple SDK).
- Package yo'li: `Packages/CommanderKit`. Barcha test buyruqlari repo ildizidan: `swift test --package-path Packages/CommanderKit ...`.
- Testlar faqat vaqtinchalik papkada ishlaydi (`FileManager.default.temporaryDirectory`), haqiqiy Trash'ga hech narsa yuborilmaydi.
- Settings fayllari: `~/Library/Application Support/Commander/settings.json`, `session.json`; ikkalasida `"version": 1`.
- Debounce qiymatlari: FSEvents — 150 ms, Settings saqlash — 0,5 s. Type-ahead reset — 1 s.
- Performance: 5 000 faylli papkani o'qish ≤ 100 ms (Intel Mac).
- Commit xabarlari — inglizcha, buyruq maylida ("Add …"), attribution qatorsiz.

## Prerequisite (foydalanuvchi bajaradi, Task 1'dan oldin)

Command Line Tools'da `Testing`/`XCTest` modullari yo'q (2026-10-21 tekshirildi). Xcode App Store'dan o'rnatiladi, keyin:

```bash
sudo xcode-select -s /Applications/Xcode.app
```

Tekshiruv: `xcodebuild -version` versiya chiqaradi.

## Review Focus

1. **Papkani o'zining ichiga nusxalash** (o'ng panel manba papka ichida turibdi, `F5`) — cheksiz rekursiya emas, `OperationFailure(.destinationInsideSource)` va hech narsa yozilmaydi. → Task 10 testi.
2. **Manba va manzil bir papka** (ikkala panel bir joyda, `F5`) — Replace manbani o'chirib yubormasligi kerak: avtomatik Finder "copy" nomi bilan dublikat. → Task 10 testi.
3. **Symlink'lar nusxalashda** — link o'zi nusxalanadi, ichiga kirilmaydi (sikl yo'q). → Task 10 testi.
4. **Bo'sh papka va hamma narsa yashirin papka** — kursor `nil`, `targets` bo'sh, hech qanday metod crash qilmaydi. → Task 2 va Task 3 testlari.
5. **Boshqa diskka move paytida xato yoki cancel** — manbalar o'chirilmaydi. → Task 11 testi.

---

## Fayl tuzilmasi

```
Packages/CommanderKit/
  Package.swift
  Sources/CommanderCore/
    FileItem.swift          # FileItem, FileSort
    TabState.swift          # navigatsiya, tarix, ro'yxatni qo'llash
    TabState+Cursor.swift   # kursor harakati va belgilash
    TypeAhead.swift
    PaneState.swift         # PaneState, WindowState, PaneSide
    Command.swift
    KeyChord.swift
    KeyBindings.swift
    Settings.swift          # AppSettings, AppearanceSettings, BehaviorSettings
    Session.swift
    SettingsStore.swift     # o'qish/yozish, migratsiya, buzilgan fayl
    DebouncedWriter.swift
    Operations.swift        # progress, konflikt, xato, OperationState
    UniqueName.swift
  Sources/CommanderFileSystem/
    DirectoryReader.swift
    DirectoryWatcher.swift
    CopyOperation.swift
    MoveOperation.swift
    Trash.swift             # Trasher, SystemTrasher, TrashOperation, DeleteOperation
    FileActions.swift       # createFolder, rename
    Volumes.swift           # VolumeInfo, Volumes, SMBAddress
  Tests/CommanderCoreTests/      # har manba fayliga mos *Tests.swift
  Tests/CommanderFileSystemTests/
    TempDir.swift, RecordingDelegate.swift, DiskImage.swift   # test helper'lar
```

---

### Task 1: Package skeleti, `FileItem` va saralash

**Files:**
- Create: `Packages/CommanderKit/Package.swift`, `Sources/CommanderCore/FileItem.swift`, `Tests/CommanderCoreTests/FileSortTests.swift`, `Sources/CommanderFileSystem/DirectoryReader.swift` (hozircha faqat `import CommanderCore` — target build bo'lishi uchun), `Tests/CommanderFileSystemTests/TempDir.swift`
- Create: `.gitignore` (`.build/`, `*.xcodeproj/`, `DerivedData/`, `.DS_Store`)
- Modify: `AGENTS.md` → "Build va test" bo'limi

**Interfaces:**
- Produces:
  ```swift
  public struct FileItem: Hashable, Sendable {
      public enum Kind: Hashable, Sendable { case file, directory, package, symlink(toDirectory: Bool) }
      public let name: String
      public let url: URL
      public let kind: Kind
      public let size: Int64?        // papkalar uchun nil
      public let modified: Date
      public let isHidden: Bool
      public var isNavigable: Bool { get }   // .directory yoki .symlink(toDirectory: true)
      public init(name:url:kind:size:modified:isHidden:)
  }
  public enum SortColumn: String, Codable, Sendable { case name, size, modified }
  public struct FileSort: Codable, Hashable, Sendable {
      public var column: SortColumn = .name
      public var ascending: Bool = true
      public func sorted(_ items: [FileItem]) -> [FileItem]
  }
  // test helper (CommanderFileSystemTests)
  struct TempDir { let url: URL; init() throws; func file(_ name: String, bytes: Int = 0) throws -> URL; func dir(_ name: String) throws -> URL; func remove() }
  ```

- [ ] **Step 1: `Package.swift` yozish** — `swift-tools-version:6.0`, `platforms: [.macOS(.v15)]`, targets: `CommanderCore`, `CommanderFileSystem` (deps: `CommanderCore`), `CommanderCoreTests`, `CommanderFileSystemTests`; `swiftLanguageModes: [.v6]`.

- [ ] **Step 2: Failing test `FileSortTests`**

```swift
@Test func navigableItemsAlwaysFirst()       // [b.txt, aDir, c.txt], name desc → aDir, c.txt, b.txt
@Test func nameUsesFinderOrder()             // ["file10", "file2", "File1"] → ["File1", "file2", "file10"]
@Test func sizeSortKeepsDirectoriesByName()  // size asc: dirs [b, a] → [a, b] yuqorida; fayllar 5, 1, 3 → 1, 3, 5
@Test func modifiedDescending()
@Test func symlinkToDirectoryCountsAsFolder_packageCountsAsFile()
```

- [ ] **Step 3: Run** `swift test --package-path Packages/CommanderKit --filter FileSortTests` → FAIL (`FileSort` yo'q).

- [ ] **Step 4: `FileItem.swift` ni implement qilish.** Teng qiymatlar nom bo'yicha (`localizedStandardCompare`) ajratiladi — tartib barqaror.

- [ ] **Step 5: Run** → PASS.

- [ ] **Step 6: `AGENTS.md` "Build va test" bo'limini yozish:**
  ```
  Core/FileSystem testlari: swift test --package-path Packages/CommanderKit
  Bitta suite: swift test --package-path Packages/CommanderKit --filter <SuiteName>
  Benchmark: CK_BENCHMARK=1 swift test --package-path Packages/CommanderKit -c release --filter DirectoryReaderBenchmark
  Talab: to'liq Xcode (Command Line Tools'da Testing yo'q).
  ```

- [ ] **Step 7: Commit** — `git add .gitignore AGENTS.md Packages/` → `Add CommanderKit package with FileItem and sorting`

---

### Task 2: `TabState` — navigatsiya, tarix, ro'yxatni qo'llash

**Files:**
- Create: `Sources/CommanderCore/TabState.swift`, `Tests/CommanderCoreTests/TabStateNavigationTests.swift`

**Interfaces:**
- Consumes: `FileItem`, `FileSort` (Task 1)
- Produces:
  ```swift
  public struct TabState: Sendable {
      public private(set) var path: URL
      public private(set) var backHistory: [URL]
      public private(set) var forwardHistory: [URL]
      public private(set) var items: [FileItem]      // ko'rinadigan, saralangan
      public internal(set) var cursor: String?       // nom
      public internal(set) var marked: Set<String>
      public private(set) var sort: FileSort
      public private(set) var showHidden: Bool
      public init(path: URL, sort: FileSort = .init(), showHidden: Bool = false)
      public mutating func navigate(to url: URL)
      @discardableResult public mutating func goUp() -> Bool
      @discardableResult public mutating func goBack() -> Bool
      @discardableResult public mutating func goForward() -> Bool
      public mutating func apply(listing: [FileItem])
      public mutating func setSort(_ sort: FileSort)
      public mutating func setShowHidden(_ show: Bool)
      public var cursorIndex: Int? { get }
      public var cursorItem: FileItem? { get }
      public var targets: [FileItem] { get }   // belgilanganlar ko'rinish tartibida; bo'lmasa [cursorItem]; bo'lmasa []
  }
  ```

**Ro'yxatni qayta qurish qoidasi** (`apply`, `setSort`, `setShowHidden` hammasi shuni ishlatadi): to'liq ro'yxat saqlanadi → `showHidden == false` bo'lsa yashirinlar chiqariladi → `sort.sorted` → kursor: `pendingCursor` (ro'yxatda bo'lsa) → eski `cursor` (bo'lsa) → eski indeks `min(oldIndex, count-1)` → birinchi element → bo'sh ro'yxatda `nil`. `pendingCursor` bir marta ishlatilib tozalanadi. `marked` ko'rinadigan nomlar bilan kesishtiriladi.

- [ ] **Step 1: Failing testlar**

```swift
@Test func navigateClearsMarksAndPushesHistory()   // marked {"a"} → navigate(/x) → marked == [], backHistory == [old], forwardHistory == []
@Test func navigateToSamePathIsNoOp()
@Test func goUpPlacesCursorOnFolderWeLeft()        // /a/b → goUp → apply([b, c]) → cursor == "b"
@Test func goUpAtRootReturnsFalse()                // "/" → goUp() == false
@Test func backAndForward()                         // /a → /b → goBack → /a, forward == [/b] → goForward → /b
@Test func reloadKeepsCursorAndMarksByName()       // cursor "c", marked {"a","c"} → apply("a"siz, boshqa tartibda) → cursor "c", marked {"c"}
@Test func cursorFallsBackToSameIndexWhenItemRemoved()  // [a,b,c] cursor b → apply([a,c]) → "c"; [a,b] cursor b → apply([a]) → "a"
@Test func hiddenFilesFilteredUntilShown()         // ".git" isHidden → items'da yo'q → setShowHidden(true) → bor
@Test func emptyListingHasNilCursorAndNoTargets()  // apply([]) → cursor nil, cursorIndex nil, targets []
@Test func allHiddenListingBehavesAsEmpty()
@Test func targetsPreferMarkedInDisplayOrder()     // marked {"c","a"} → targets nomlari ["a","c"]; marked bo'sh → [cursorItem]
```

- [ ] **Step 2: Run** `--filter TabStateNavigationTests` → FAIL.
- [ ] **Step 3: `TabState.swift` ni implement qilish.** `goUp` `navigate(to: parent)` ni chaqirib, `pendingCursor = path.lastPathComponent` qiladi. `navigate` `items` ni bo'shatadi; yangi ro'yxatni chaqiruvchi `apply` bilan beradi.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add TabState navigation and listing rules`

---

### Task 3: Kursor harakati, belgilash, type-ahead

**Files:**
- Create: `Sources/CommanderCore/TabState+Cursor.swift`, `Sources/CommanderCore/TypeAhead.swift`, `Tests/CommanderCoreTests/TabStateCursorTests.swift`, `Tests/CommanderCoreTests/TypeAheadTests.swift`

**Interfaces:**
- Consumes: `TabState` (Task 2)
- Produces:
  ```swift
  extension TabState {
      public mutating func moveCursor(by delta: Int)            // chegarada to'xtaydi
      public mutating func moveCursorToStart()
      public mutating func moveCursorToEnd()
      public mutating func setCursor(name: String)              // ro'yxatda bo'lmasa — o'zgarmaydi
      public mutating func toggleMark(advance: Bool)            // Space
      public mutating func moveCursorMarking(by delta: Int)     // ⇧↑/⇧↓
      public mutating func markRange(toName name: String)       // ⇧+click
      public mutating func toggleMark(name: String)             // ⌘+click
      public mutating func markAll()
      public mutating func clearMarks()
  }
  public struct TypeAhead: Sendable {
      public init(resetAfter: Duration = .seconds(1))
      public mutating func input(_ character: Character, at time: ContinuousClock.Instant, in items: [FileItem]) -> String?
  }
  ```

- [ ] **Step 1: Failing testlar**

```swift
@Test func moveCursorClampsAtEdges()                 // [a,b,c] cursor a → by: -1 → a; by: 10 → c
@Test func moveCursorKeepsMarks()
@Test func spaceTogglesAndAdvances()                 // cursor a → toggleMark(advance: true) → marked {a}, cursor b; a'ga qaytib yana → marked {}
@Test func spaceWithoutAdvanceStays()
@Test func spaceOnLastRowStaysOnLastRow()
@Test func shiftDownMarksPassedRows()                // cursor a → moveCursorMarking(by: 1) x2 → marked {a,b,c}, cursor c
@Test func shiftUpMarksPassedRows()                  // cursor c → by: -1 → marked {c,b}, cursor b
@Test func markRangeFromCursor()                     // [a..e] cursor b → markRange(toName: "d") → {b,c,d}, cursor d; teskari yo'nalishda ham
@Test func commandClickTogglesSingleRow()
@Test func markAllAndClear()
@Test func cursorOperationsOnEmptyListingDoNothing() // hech biri crash qilmaydi, cursor nil, marked []
// TypeAheadTests
@Test func jumpsToFirstPrefixMatchCaseInsensitive()  // ["Alpha","beta","Bravo"], "b" → "beta"; keyin "r" → "Bravo"
@Test func diacriticInsensitive()                    // ["Çay"], "c" → "Çay"
@Test func resetsAfterOneSecond()                    // "b" t0, "r" t0+1.1s → prefix "r"
@Test func noMatchReturnsNil()
```

- [ ] **Step 2: Run** `--filter "TabStateCursorTests|TypeAheadTests"` → FAIL.
- [ ] **Step 3: Implement qilish.** `moveCursorMarking` joriy qatorni belgilaydi, kursorni suradi va yangi qatorni ham belgilaydi (doim qo'shadi, toggle qilmaydi). `TypeAhead` — `compare(_:options: [.caseInsensitive, .diacriticInsensitive, .anchored])`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add cursor movement, marking and type-ahead`

---

### Task 4: `PaneState` va `WindowState`

**Files:**
- Create: `Sources/CommanderCore/PaneState.swift`, `Tests/CommanderCoreTests/PaneStateTests.swift`

**Interfaces:**
- Consumes: `TabState`
- Produces:
  ```swift
  public struct PaneState: Sendable {
      public private(set) var tabs: [TabState]
      public private(set) var activeTabIndex: Int
      public init(tabs: [TabState], activeTabIndex: Int = 0)   // tabs bo'sh bo'lmasligi kerak (precondition)
      public var activeTab: TabState { get set }
      public mutating func newTab()                // joriy papkada, faol tabdan keyin, faol bo'ladi
      @discardableResult public mutating func closeActiveTab() -> Bool   // oxirgi tab → false
      public mutating func selectNextTab()         // aylanma
      public mutating func selectPreviousTab()
      public mutating func selectTab(at index: Int)
  }
  public enum PaneSide: String, Codable, Sendable { case left, right }
  public struct WindowState: Sendable {
      public var left: PaneState
      public var right: PaneState
      public var activeSide: PaneSide
      public init(left: PaneState, right: PaneState, activeSide: PaneSide = .left)
      public var activePane: PaneState { get set }
      public var otherPane: PaneState { get set }
      public mutating func switchActiveSide()
  }
  ```

- [ ] **Step 1: Failing testlar**

```swift
@Test func newTabOpensCurrentPathAfterActive()     // [/a, /b], active 0 → newTab → [/a, /a, /b], active 1
@Test func newTabStartsWithoutMarks()
@Test func cannotCloseLastTab()
@Test func closeActivatesNeighbor()                // [a,b,c] active 2 → close → active 1; active 0 → close → active 0
@Test func nextAndPreviousWrapAround()
@Test func switchActiveSideSwapsActiveAndOther()
```

- [ ] **Step 2: Run** `--filter PaneStateTests` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add PaneState and WindowState`

---

### Task 5: `Command`, `KeyChord`, `KeyBindings`

**Files:**
- Create: `Sources/CommanderCore/Command.swift`, `KeyChord.swift`, `KeyBindings.swift`, `Settings.swift` (bu task'da faqat `BackspaceAction` va `BehaviorSettings`), `Tests/CommanderCoreTests/KeyChordTests.swift`, `KeyBindingsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum Command: String, CaseIterable, Codable, Sendable {
      case moveUp, moveDown, moveToStart, moveToEnd, pageUp, pageDown
      case markUp, markDown, toggleMark, markAll
      case open, goUp, goBack, goForward
      case switchPane, newTab, closeTab, nextTab, previousTab
      case focusPathField, reload, toggleHiddenFiles
      case copyToClipboard, cutToClipboard, paste, duplicate
      case copyToOtherPane, moveToOtherPane, newFolder, rename, moveToTrash
      case connectToServer, openSettings
      case copyPath, copyName, showPackageContents, revealInFinder, openInTerminal   // faqat menyu, default tugmasiz
      public var isAllowedInTextField: Bool { get }   // true faqat: openSettings, connectToServer, newTab, closeTab, nextTab, previousTab, focusPathField
  }
  public struct KeyChord: Hashable, Sendable, Codable, CustomStringConvertible {
      public struct Modifiers: OptionSet, Hashable, Sendable { command, shift, option, control }
      public let key: String          // "up","down","home","end","pageUp","pageDown","space","return","tab","backspace","forwardDelete","escape","f1"…"f12" yoki bitta kichik belgi: "t", "[", ".", ","
      public let modifiers: Modifiers
      public init(_ key: String, _ modifiers: Modifiers = [])
      public init?(string: String)    // "cmd+shift+." ; chiqishda tartib: ctrl+opt+shift+cmd
      public var description: String  // init(string:) bilan aylanma; Codable shu string orqali
  }
  public enum FocusContext: Sendable { case table, textField }
  public enum BackspaceAction: String, Codable, Sendable { case parent, historyBack }
  public struct BehaviorSettings: Codable, Equatable, Sendable {
      public var backspaceAction: BackspaceAction = .parent
      public var spaceAdvances = true
      public var askDestinationForCopyMove = false
      public var forwardDeleteTrashes = true
      public var showHiddenByDefault = false
      public var restoreTabsOnLaunch = true
  }
  public struct KeyBindings: Sendable {
      public static func defaults(for behavior: BehaviorSettings) -> [Command: [KeyChord]]
      public init(defaults: [Command: [KeyChord]], overrides: [Command: [KeyChord]])
      public func command(for chord: KeyChord, in context: FocusContext) -> Command?
      public func chords(for command: Command) -> [KeyChord]
      public func conflicts(assigning chord: KeyChord, to command: Command) -> [Command]
  }
  ```

**Default jadval** (spec 5-bo'lim): `up` moveUp · `down` moveDown · `home` moveToStart · `end` moveToEnd · `pageUp`/`pageDown` · `shift+up` markUp · `shift+down` markDown · `space` toggleMark · `cmd+a` markAll · `return`, `cmd+down` open · `backspace` goUp (`.historyBack` bo'lsa goBack) · `cmd+up` goUp · `cmd+[` goBack · `cmd+]` goForward · `tab` switchPane · `cmd+t` newTab · `cmd+w` closeTab · `ctrl+tab` nextTab · `ctrl+shift+tab` previousTab · `cmd+l` focusPathField · `cmd+r` reload · `cmd+shift+.` toggleHiddenFiles · `cmd+c` / `cmd+x` / `cmd+v` · `cmd+d` duplicate · `f5` copyToOtherPane · `f6` moveToOtherPane · `f7` newFolder · `f2`, `shift+f6` rename · `cmd+backspace` moveToTrash, `forwardDelete` ham (faqat `forwardDeleteTrashes == true` bo'lsa) · `cmd+k` connectToServer · `cmd+,` openSettings.

**Override qoidasi:** override buyruqning **butun** tugmalar ro'yxatini almashtiradi; override'dagi tugma boshqa buyruqning default'ida bo'lsa, u o'sha buyruqdan olib tashlanadi (override yutadi).

- [ ] **Step 1: Failing testlar**

```swift
// KeyChordTests
@Test func parsesAndPrintsRoundTrip()     // "cmd+shift+." ↔ KeyChord(".", [.command, .shift]); "ctrl+shift+tab"
@Test func rejectsUnknownModifierOrEmptyKey()   // "hyper+a" → nil, "cmd+" → nil
@Test func codableAsString()              // JSON "\"cmd+t\""
// KeyBindingsTests
@Test func everySpecDefaultResolves()     // jadvaldagi har juftlik, context .table
@Test func backspaceFollowsBehavior()     // .historyBack → backspace == goBack, cmd+up hali goUp
@Test func forwardDeleteCanBeDisabled()   // forwardDeleteTrashes = false → forwardDelete → nil
@Test func defaultsHaveNoDuplicateChords()
@Test func overrideReplacesCommandChords()          // newTab: [cmd+n] → cmd+t nil, cmd+n newTab
@Test func overrideStealsChordFromDefault()         // reload: [cmd+d] → cmd+d reload, duplicate'da cmd+d yo'q
@Test func textFieldOnlyAllowsWhitelisted()         // .textField: backspace nil, cmd+a nil, space nil, cmd+t newTab, cmd+, openSettings
@Test func conflictsListsOtherOwners()              // conflicts(assigning: cmd+d, to: .reload) == [.duplicate]; o'zining tugmasi → []
```

- [ ] **Step 2: Run** `--filter "KeyChordTests|KeyBindingsTests"` → FAIL.
- [ ] **Step 3: Implement qilish.** `[KeyChord: Command]` qidiruv lug'ati `init` da bir marta quriladi.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add Command, KeyChord and KeyBindings with defaults`

---

### Task 6: Settings va Session modellari, `SettingsStore`, `DebouncedWriter`

**Files:**
- Modify: `Sources/CommanderCore/Settings.swift`
- Create: `Sources/CommanderCore/Session.swift`, `SettingsStore.swift`, `DebouncedWriter.swift`, `Tests/CommanderCoreTests/SettingsCodingTests.swift`, `SettingsStoreTests.swift`, `DebouncedWriterTests.swift`

**Interfaces:**
- Consumes: `BehaviorSettings`, `Command`, `KeyChord`, `PaneSide`
- Produces:
  ```swift
  public enum Theme: String, Codable, Sendable { case system, light, dark }
  public struct AppearanceSettings: Codable, Equatable, Sendable {
      public var theme: Theme = .system
      public var fontName: String? = nil      // nil = system shrift
      public var fontSize: Double = 13
      public var iconSize: Double = 16
      public var rowHeight: Double = 22
  }
  public struct AppSettings: Codable, Equatable, Sendable {
      public static let currentVersion = 1
      public var version = currentVersion
      public var appearance = AppearanceSettings()
      public var behavior = BehaviorSettings()
      public var shortcutOverrides: [Command: [KeyChord]] = [:]   // JSON: {"newTab": ["cmd+n"]}; noma'lum buyruq nomi tashlab yuboriladi
  }
  public struct PaneSession: Codable, Equatable, Sendable { public var tabPaths: [URL]; public var activeTab: Int }
  public struct Session: Codable, Equatable, Sendable {
      public static let currentVersion = 1
      public var version = currentVersion
      public var left: PaneSession; public var right: PaneSession   // default: Home, bitta tab
      public var activeSide: PaneSide = .left
      public var sidebarWidth: Double = 200
      public var favorites: [URL]          // default: ~, ~/Desktop, ~/Documents, ~/Downloads, /Applications
      public var recentServers: [String] = []
      public mutating func addRecentServer(_ address: String)   // boshiga qo'yadi, takrorni olib tashlaydi, max 10
  }
  public struct LoadResult<Value: Sendable>: Sendable { public let value: Value; public let corruptFileBackup: URL? }
  public struct SettingsStore: Sendable {
      public static var defaultDirectory: URL { get }   // ~/Library/Application Support/Commander
      public init(directory: URL)
      public func loadSettings() -> LoadResult<AppSettings>
      public func loadSession() -> LoadResult<Session>
      public func save(_ settings: AppSettings) throws
      public func save(_ session: Session) throws
  }
  public actor DebouncedWriter {
      public init(interval: Duration = .milliseconds(500))
      public func schedule(_ work: @escaping @Sendable () -> Void)   // oldingisini bekor qiladi
      public func flush() async                                       // kutayotganini darhol bajaradi (ilova yopilishida)
  }
  ```

**Qoidalar:**
- Barcha struct'larda qo'lda `init(from:)` — har maydon `decodeIfPresent`, yo'q bo'lsa default.
- Saqlash: papka bo'lmasa yaratiladi; `JSONEncoder` (`.prettyPrinted, .sortedKeys`), `Data.write(to:options: .atomic)`.
- O'qish: fayl yo'q → default, `corruptFileBackup == nil`. JSON parse bo'lmasa → fayl `<nom>.broken-yyyy-MM-dd-HHmmss.json` ga ko'chiriladi (mahalliy vaqt), default va backup URL qaytadi.
- Migratsiya: JSON avval `[String: Any]` sifatida o'qiladi; `version < current` bo'lsa `migrations[version]` qadamlari ketma-ket qo'llanadi. 1-versiyada ro'yxat bo'sh; mexanizm `internal init(directory:settingsMigrations:)` orqali test qilinadi. `version > current` → o'qiladigan qismi o'qiladi.

- [ ] **Step 1: Failing testlar**

```swift
// SettingsCodingTests
@Test func emptyObjectDecodesToDefaults()            // "{}" → AppSettings(); Session ham
@Test func partialObjectKeepsGivenValues()           // {"appearance":{"fontSize":15}} → 15, qolgani default
@Test func unknownKeysIgnored()
@Test func overridesEncodeAsCommandNameToStrings()   // {"newTab":["cmd+n"]}
@Test func unknownCommandInOverridesIsDropped()      // {"removedCmd":["cmd+q"], "reload":["cmd+e"]} → faqat reload
@Test func recentServersCappedAtTenNewestFirst()     // 12 ta → 10 ta, birinchisi oxirgi qo'shilgan; takror → boshiga
// SettingsStoreTests (vaqtinchalik papkada)
@Test func missingFilesGiveDefaultsWithoutBackup()
@Test func saveThenLoadRoundTrip()                   // settings va session
@Test func saveCreatesDirectory()
@Test func corruptFileIsBackedUpAndDefaultsReturned() // "{not json" → backup "settings.broken-" bilan boshlanadi, ".json" bilan tugaydi, ichida asl matn; settings.json yo'q
@Test func migrationStepsRunInOrder()                // version 0 fayl + migrations [0: "x" qo'shadi] → natijada x bor
// DebouncedWriterTests
@Test func burstRunsOnce()                           // interval 50 ms, 3 marta schedule → 150 ms dan keyin 1 marta, oxirgi ish
@Test func flushRunsPendingImmediately()
```

- [ ] **Step 2: Run** `--filter "SettingsCodingTests|SettingsStoreTests|DebouncedWriterTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add settings and session persistence`

---

### Task 7: `DirectoryReader` va benchmark

**Files:**
- Modify: `Sources/CommanderFileSystem/DirectoryReader.swift`
- Create: `Tests/CommanderFileSystemTests/DirectoryReaderTests.swift`, `DirectoryReaderBenchmark.swift`

**Interfaces:**
- Consumes: `FileItem`
- Produces:
  ```swift
  public enum ListingError: Error, Equatable, Sendable { case notFound, notADirectory, permissionDenied, other(String) }
  public struct DirectoryReader: Sendable {
      public init()
      public func list(_ directory: URL) throws(ListingError) -> [FileItem]   // yashirinlar ham qaytadi; filtr TabState'da
      public func nearestExistingDirectory(from url: URL) -> URL             // o'zi yoki eng yaqin mavjud ota papka; oxiri "/"
  }
  ```
- Prefetch qilinadigan resource key'lar: `nameKey, isDirectoryKey, isSymbolicLinkKey, isPackageKey, fileSizeKey, contentModificationDateKey, isHiddenKey`. Symlink: `resolvingSymlinksInPath()` → `isDirectoryKey`; buzilgan link → `.symlink(toDirectory: false)`.
- Xatolar: `NSFileReadNoSuchFileError` → `.notFound`; `NSFileReadNoPermissionError` / `EACCES` / `EPERM` → `.permissionDenied`.

- [ ] **Step 1: Failing testlar**

```swift
@Test func listsFilesFoldersWithMetadata()      // a.txt (5 bayt) → .file, size 5; sub/ → .directory, size nil
@Test func hiddenFlagFromDotName()              // ".env" → isHidden true
@Test func symlinkKinds()                       // dirga → .symlink(toDirectory: true); faylga → false; buzilgan → false
@Test func appBundleIsPackage()                 // "X.app/Contents/" → .package
@Test func missingDirectoryThrowsNotFound()
@Test func fileThrowsNotADirectory()
@Test func unreadableDirectoryThrowsPermissionDenied()   // chmod 000, oxirida 755 qaytariladi
@Test func nearestExistingDirectoryWalksUp()    // tmp/a/b/c (faqat tmp/a bor) → tmp/a
// DirectoryReaderBenchmark — .enabled(if: ProcessInfo.processInfo.environment["CK_BENCHMARK"] == "1")
@Test func list5000FilesUnder100ms()            // 5 000 bo'sh fayl; 1 isinish + 5 o'lchov (ContinuousClock), median ≤ .milliseconds(100)
```

- [ ] **Step 2: Run** `--filter DirectoryReaderTests` → FAIL.
- [ ] **Step 3: Implement qilish** — `FileManager.contentsOfDirectory(at:includingPropertiesForKeys:options: [])`.
- [ ] **Step 4: Run** `--filter DirectoryReaderTests` → PASS; `CK_BENCHMARK=1 swift test --package-path Packages/CommanderKit -c release --filter DirectoryReaderBenchmark` → PASS. O'lchangan median commit xabariga yoziladi.
- [ ] **Step 5: Commit** — `Add DirectoryReader with listing benchmark`

---

### Task 8: `DirectoryWatcher` (FSEvents)

**Files:**
- Create: `Sources/CommanderFileSystem/DirectoryWatcher.swift`, `Tests/CommanderFileSystemTests/DirectoryWatcherTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public final class DirectoryWatcher: Sendable {
      public init(directory: URL, latency: Duration = .milliseconds(150), onChange: @escaping @Sendable () -> Void)
      public func start()
      public func stop()      // deinit ham to'xtatadi
  }
  ```
- `FSEventStreamCreate` (`kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer`; `latency` — FSEvents'ning o'z coalescing'i), o'z serial `DispatchQueue` ida. Batch'dagi yo'llardan birortasi `directory` ning o'zi yoki **bevosita** farzandi bo'lsa — `onChange` bir marta chaqiriladi. Mutable holat `Mutex` ichida.

- [ ] **Step 1: Failing testlar**

```swift
@Test func fileCreationTriggersChange()           // start → fayl yaratish → 2 s ichida onChange
@Test func burstCoalescesIntoFewCallbacks()       // 50 fayl ketma-ket → 1 s kutish → chaqiruvlar ≤ 3
@Test func changesInSubfolderAreIgnored()         // sub/x.txt → 1 s ichida chaqiruv yo'q
@Test func deletingWatchedDirectoryTriggersChange()
@Test func stopPreventsFurtherCallbacks()
```

- [ ] **Step 2: Run** `--filter DirectoryWatcherTests` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS (beqarorlikni tekshirish uchun 3 marta ketma-ket).
- [ ] **Step 5: Commit** — `Add FSEvents-based DirectoryWatcher`

---

### Task 9: Amal turlari va noyob nomlar (Core)

**Files:**
- Create: `Sources/CommanderCore/Operations.swift`, `UniqueName.swift`, `Tests/CommanderCoreTests/UniqueNameTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct OperationProgress: Equatable, Sendable {
      public var totalFiles: Int; public var completedFiles: Int
      public var totalBytes: Int64; public var completedBytes: Int64
      public var currentName: String?
  }
  public struct Conflict: Sendable { public let source: URL; public let existing: URL }
  public enum ConflictDecision: Sendable { case replace, skip, keepBoth }
  public struct ConflictResolution: Sendable { public let decision: ConflictDecision; public let applyToAll: Bool }
  public struct OperationFailure: Error, Equatable, Sendable {
      public enum Reason: Equatable, Sendable { case permissionDenied, fileBusy, diskFull, destinationInsideSource, other(String) }
      public let url: URL; public let reason: Reason
  }
  public enum ErrorDecision: Sendable { case retry, skip, cancelAll }
  public enum OperationOutcome: Equatable, Sendable { case completed, cancelled }
  public protocol OperationDelegate: Sendable {
      func progress(_ progress: OperationProgress)
      func resolve(_ conflict: Conflict) async -> ConflictResolution
      func decide(_ failure: OperationFailure) async -> ErrorDecision
  }
  public enum OperationKind: Sendable { case copy, move, trash, delete }
  public enum OperationStatus: Equatable, Sendable { case running, waitingForUser, completed, cancelled }
  public struct OperationState: Identifiable, Sendable {   // footer UI uchun
      public let id: UUID; public let kind: OperationKind
      public var progress: OperationProgress; public var status: OperationStatus
  }
  public enum UniqueName {
      public static func keepBoth(_ name: String, exists: (String) -> Bool) -> String     // "a.txt" → "a 2.txt", "a 3.txt"; "dir" → "dir 2"; "X.app" → "X 2.app"
      public static func duplicate(_ name: String, exists: (String) -> Bool) -> String    // "a.txt" → "a copy.txt", "a copy 2.txt"
      public static func newFolder(exists: (String) -> Bool) -> String                    // "untitled folder", "untitled folder 2"
  }
  ```
- Kengaytma — oxirgi `.` dan keyin; boshidagi nuqta kengaytma emas (`".bashrc"` → `".bashrc 2"`).

- [ ] **Step 1: Failing testlar**

```swift
@Test func keepBothAddsNumberBeforeExtension()   // exists {"a.txt","a 2.txt"} → "a 3.txt"
@Test func keepBothForFolderAndPackage()         // "dir" → "dir 2"; "X.app" → "X 2.app"
@Test func dotfileHasNoExtension()               // ".bashrc" → ".bashrc 2"
@Test func duplicateUsesCopySuffix()             // {"a.txt"} → "a copy.txt"; {"a.txt","a copy.txt"} → "a copy 2.txt"
@Test func newFolderName()                       // {} → "untitled folder"; {"untitled folder"} → "untitled folder 2"
```

- [ ] **Step 2: Run** `--filter UniqueNameTests` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add operation types and unique naming`

---

### Task 10: `CopyOperation`

**Files:**
- Create: `Sources/CommanderFileSystem/CopyOperation.swift`, `Tests/CommanderFileSystemTests/CopyOperationTests.swift`, `Tests/CommanderFileSystemTests/RecordingDelegate.swift`

**Interfaces:**
- Consumes: Task 9 turlari, `UniqueName`
- Produces:
  ```swift
  public struct CopyOperation: Sendable {
      public init(sources: [URL], destination: URL, delegate: any OperationDelegate)
      public func run() async -> OperationOutcome     // Task cancellation'ni hurmat qiladi
  }
  // test helper: oldindan berilgan ConflictResolution / ErrorDecision navbatlari; progress va chaqiruvlar sonini yozib boradi (Mutex)
  final class RecordingDelegate: OperationDelegate
  ```

**Algoritm:**
1. Har manba uchun: `destination` manbaning o'zi yoki uning ichida bo'lsa (standartlashtirilgan yo'l, komponentlar bo'yicha prefiks) → `decide(.destinationInsideSource)`; bu manba hech qachon yozilmaydi (`cancelAll` → butun amal `.cancelled`).
2. Oldindan yurish: `totalFiles`, `totalBytes` (symlink'ga kirilmaydi).
3. Daraja-daraja: papka → `createDirectory`; fayl va symlink → `copyfile(src, dst, state, COPYFILE_ALL | COPYFILE_NOFOLLOW)` + `COPYFILE_STATE_STATUS_CB`. Callback progress yuboradi va cancel bayrog'i o'rnatilgan bo'lsa `COPYFILE_QUIT` qaytaradi.
4. Cancel: `withTaskCancellationHandler` → `Mutex<Bool>`; har fayldan keyin va callback ichida tekshiriladi. Cancel'da chala `dst` fayli o'chiriladi, tugallanganlari qoladi → `.cancelled`.
5. Top-level konflikt: manbaning ota papkasi `destination` ga teng bo'lsa → so'ralmaydi, `UniqueName.duplicate` nomi bilan nusxalanadi. Aks holda `resolve`: `replace` → avval mavjud element o'chiriladi; `skip`; `keepBoth` → `UniqueName.keepBoth`. `applyToAll` keyingi konfliktlarga ham qo'llanadi.
6. Xato: `EACCES`/`EPERM` → `.permissionDenied`, `EBUSY`/`ETXTBSY` → `.fileBusy`, `ENOSPC` → `.diskFull`, boshqasi → `.other(strerror)`. `decide`: `retry` shu faylni qaytadan, `skip` keyingisiga, `cancelAll` → `.cancelled`.

- [ ] **Step 1: Failing testlar**

```swift
@Test func copiesFilesAndFoldersRecursively()   // a.txt + dir/b.txt → bir xil daraxt va tarkib; .completed
@Test func reportsProgressTotals()              // oxirgi progress: completedFiles == totalFiles == 2, completedBytes == totalBytes
@Test func conflictReplace()                    // manzilda a.txt ("old") → replace → "new"
@Test func conflictSkip()
@Test func conflictKeepBoth()                   // "a 2.txt" yaratiladi, "a.txt" o'zgarmaydi
@Test func applyToAllAsksOnce()                 // 3 konflikt, birinchi javob (skip, applyToAll: true) → resolve 1 marta
@Test func sameFolderMakesDuplicateWithoutAsking()   // → "a copy.txt", resolve chaqirilmagan, asl fayl joyida
@Test func destinationInsideSourceIsRefused()   // dir → dir/sub → reason .destinationInsideSource, dir/sub ichida yangi narsa yo'q
@Test func symlinkCopiedAsLink()                // manzilda ham symlink, destinationOfSymbolicLink bir xil
@Test func cancelRemovesPartialFileKeepsFinished()   // kichik + 200 MB fayl; katta fayl progress'i boshlangach Task.cancel → .cancelled, kichigi bor, kattasi yo'q
@Test func permissionErrorSkipContinues()       // chmod 000 fayl + oddiy fayl, decide → skip → oddiy fayl nusxalangan, .completed
@Test func permissionErrorRetryThenSkip()       // decide navbati [retry, skip] → decide 2 marta chaqirilgan
```

- [ ] **Step 2: Run** `--filter CopyOperationTests` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add CopyOperation with conflicts, errors and cancel`

---

### Task 11: `MoveOperation`, Trash va o'chirish, `FileActions`

**Files:**
- Create: `Sources/CommanderFileSystem/MoveOperation.swift`, `Trash.swift`, `FileActions.swift`, `Tests/CommanderFileSystemTests/MoveOperationTests.swift`, `TrashTests.swift`, `FileActionsTests.swift`, `DiskImage.swift`

**Interfaces:**
- Consumes: `CopyOperation`, Task 9 turlari, `RecordingDelegate`
- Produces:
  ```swift
  public struct MoveOperation: Sendable {
      public init(sources: [URL], destination: URL, delegate: any OperationDelegate)
      public func run() async -> OperationOutcome
  }
  public protocol Trasher: Sendable { func trash(_ url: URL) throws }
  public struct SystemTrasher: Trasher { public init() }      // FileManager.trashItem
  public struct TrashUnsupportedError: Error {}                 // Trash yo'q volume
  public struct TrashResult: Equatable, Sendable { public var trashed: [URL]; public var unsupported: [URL] }
  public struct TrashOperation: Sendable {
      public init(items: [URL], trasher: any Trasher, delegate: any OperationDelegate)
      public func run() async -> (OperationOutcome, TrashResult)
  }
  public struct DeleteOperation: Sendable {     // qaytarib bo'lmaydi; UI faqat tasdiqdan keyin chaqiradi
      public init(items: [URL], delegate: any OperationDelegate)
      public func run() async -> OperationOutcome
  }
  public enum RenameError: Error, Equatable, Sendable { case empty, invalidCharacter, alreadyExists, failed(String) }
  public enum FileActions {
      public static func createFolder(in directory: URL) throws -> URL               // UniqueName.newFolder
      public static func rename(_ url: URL, to newName: String) throws(RenameError) -> URL
  }
  // test helper: hdiutil create -fs APFS + attach -nobrowse; detach -force
  struct DiskImage { let mountPoint: URL; init(sizeMB: Int = 300) throws; func detach() }
  ```

**Qoidalar:**
- Move: `volumeIdentifierKey` bir xil → `FileManager.moveItem`. Konflikt va xato oqimi CopyOperation'dagidek; bir papkaga move — no-op. Har xil volume → `CopyOperation`, keyin faqat **muvaffaqiyatli nusxalangan** manbalar o'chiriladi; skip qilingan, xato bergan yoki cancel'da tugallanmagan manbalar joyida qoladi.
- `SystemTrasher`: `NSFeatureUnsupportedError` → `TrashUnsupportedError`. `TrashOperation` bunday elementni `unsupported` ga qo'shib davom etadi; boshqa xatolar → `decide`.
- Rename: `newName` trim qilinadi; bo'sh → `.empty`; `/` yoki `:` → `.invalidCharacter`; aynan bir xil nom → URL o'zgarmaydi; boshqa element bor → `.alreadyExists`; faqat harf kattaligi o'zgarishi (`a.txt` → `A.txt`) ruxsat.

- [ ] **Step 1: Failing testlar**

```swift
// MoveOperationTests
@Test func sameVolumeMoveIsRename()              // fileResourceIdentifier o'zgarmaydi
@Test func moveIntoSameFolderIsNoOp()
@Test func moveConflictKeepBoth()
@Test func crossVolumeMoveCopiesThenDeletes()    // DiskImage; hdiutil ishlamasa `try #require` aniq xabar bilan to'xtaydi
@Test func crossVolumeCancelKeepsSources()       // katta fayl, cancel → manba joyida
@Test func crossVolumeSkippedItemKeepsSource()   // bitta konflikt skip → o'sha manba qolgan, boshqalari ko'chgan
// TrashTests (FakeTrasher: berilgan URL'lar uchun TrashUnsupportedError, qolganlarini yozib boradi)
@Test func trashesAllSupported()
@Test func unsupportedCollectedNotFailed()       // result.unsupported == [x], qolganlari trashed
@Test func deleteRemovesRecursively()
// FileActionsTests
@Test func createFolderPicksUniqueName()         // ikki marta → "untitled folder", "untitled folder 2"
@Test func renameValidations()                   // "" → .empty, "a/b" → .invalidCharacter, mavjud nom → .alreadyExists
@Test func renameCaseOnlyChangeAllowed()         // "a.txt" → "A.txt", papkada faqat "A.txt"
```

- [ ] **Step 2: Run** `--filter "MoveOperationTests|TrashTests|FileActionsTests"` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `Add move, trash, delete and file actions`

---

### Task 12: Volume'lar va SMB manzil

**Files:**
- Create: `Sources/CommanderFileSystem/Volumes.swift`, `Tests/CommanderFileSystemTests/VolumesTests.swift`

**Interfaces:**
- Consumes: `DiskImage` (Task 11)
- Produces:
  ```swift
  public struct VolumeInfo: Equatable, Sendable {
      public let name: String; public let url: URL
      public let totalCapacity: Int64?; public let availableCapacity: Int64?
      public let isEjectable: Bool; public let isNetwork: Bool
  }
  public enum Volumes {
      public static func mounted() -> [VolumeInfo]                   // mountedVolumeURLs(..., options: [.skipHiddenVolumes]); "/" birinchi
      public static func eject(_ url: URL) async throws              // FileManager.unmountVolume(at:options: [.allPartitionsAndEjectDisk])
  }
  public enum SMBAddress {
      public static func normalize(_ input: String) -> URL?
  }
  ```
- `normalize`: trim; sxemasiz → `smb://` qo'shiladi; `smb` dan boshqa sxema → `nil`; host bo'sh → `nil`; `user@host/share` saqlanadi.

- [ ] **Step 1: Failing testlar**

```swift
@Test func rootVolumeListedFirstWithCapacity()   // mounted().first?.url.path == "/", availableCapacity > 0
@Test func mountedDiskImageAppearsAndEjects()    // DiskImage → mounted() da bor, isEjectable → eject → yo'q
@Test func smbNormalization()
// "server/share" → "smb://server/share"; "  smb://nas.local/media " → "smb://nas.local/media";
// "smb://user@nas/share" saqlanadi; "afp://x" → nil; "" → nil; "smb://" → nil
```

- [ ] **Step 2: Run** `--filter VolumesTests` → FAIL.
- [ ] **Step 3: Implement qilish.**
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: To'liq suite:** `swift test --package-path Packages/CommanderKit` → hammasi PASS.
- [ ] **Step 6: Commit** — `Add volume listing, eject and SMB address parsing`

---

## Keyingi plan (bu plan doirasidan tashqari)

**1-bosqich B — App UI**: XcodeGen `project.yml`, AppKit oyna/sidebar/panellar/`NSTableView`, buyruq dispatcher (`KeyBindings` + `BehaviorSettings` → `TabState`/amallar), kontekst menyu, drag & drop, clipboard (`⌘C/⌘X/⌘V`, Copy path/name), SMB mount (`NSWorkspace`), Full Disk Access banner, SwiftUI Settings, footer progress (`OperationState`), session tiklash, XCUITest smoke, cold start va RAM o'lchovi. A plan bajarilgach, uning aniq interfeyslari asosida yoziladi.
