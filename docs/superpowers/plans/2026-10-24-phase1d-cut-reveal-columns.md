# 1-bosqich D — Cut, Reveal in Commander, ustunlar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut belgisi, Finder/Dock'dan "Reveal in Commander", bitta panel kengligi xatosi, boshqariladigan ustunlar (Ext, Created, Kind) va Copy To ichidagi papka brauzeri.

**Architecture:** 1C kabi: mantiq `CommanderCore`/`CommanderController` da (`swift test` bilan TDD), AppKit faqat ko'rsatadi. Ustunlar sozlamasi `AppearanceSettings` da, saralash `FileSort` da. Reveal — `WindowModel.reveal(_:)`, App'da Services/`application(_:open:)` uni chaqiradi.

**Tech Stack:** Swift 6, SwiftPM, Swift Testing, AppKit, SwiftUI (Copy To), UniformTypeIdentifiers, XcodeGen, XCUITest.

**Spec:** `docs/superpowers/specs/2026-10-24-phase1d-cut-reveal-columns-design.md`

## Global Constraints

- 1B/1C plan'larining Global Constraints'i amal qiladi: Core/FileSystem/Controller AppKit import qilmaydi; har harakat `Command`/`WindowModel` orqali; UI matnlari inglizcha.
- Branch: `phase1d-cut-reveal-columns` (`main` dan).
- Default ustunlar: Ext 60 pt, Size 72 pt, Modified 135 pt; Created 135 pt, Kind 120 pt. Name doim birinchi, o'chmaydi.
- Reveal — faol panelda yangi tab; `LSHandlerRank = None`.
- Test buyruqlari: `swift test --package-path Packages/CommanderKit`; `xcodegen generate && xcodebuild test -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64'`.

## Review Focus

1. **Murakkab nomlar:** `archive.tar.gz` → base `archive.tar`, ext `gz`; `.env` → ext yo'q; `file.` → ext yo'q. → Task 1 `extensionParts`.
2. **Ikkala panel bir papkada:** cut qilingan element ikkalasida ham ✂ bilan. → Task 3 `cutShowsInBothPanes`.
3. **Package/symlink reveal:** `X.app` reveal → ota papka ochiladi, kursor `X.app` da (ichiga kirmaydi). → Task 4 `revealPackageSelectsIt`.
4. **Buzilgan ustun sozlamasi:** noma'lum id, takror id, `name` id → tashlab yuboriladi, qolgani o'qiladi. → Task 2 `columnsDecodeLeniently`.
5. **Brauzerda root:** maydon `/` bo'lganda yuqoriga chiqish `/` da qoladi. → Task 7 `parentOfRootIsRoot`.

---

### Task 1: Core — Ext, Created, Kind ma'lumoti va saralash

**Files:**
- Modify: `Sources/CommanderCore/FileItem.swift`, `Sources/CommanderFileSystem/DirectoryReader.swift`
- Test: `Tests/CommanderCoreTests/FileSortTests.swift`, `Tests/CommanderFileSystemTests/DirectoryReaderTests.swift`

**Interfaces:**
- Produces:
  ```swift
  // FileItem — yangi saqlanadigan maydonlar (init'da default bilan, mavjud chaqiruvlar buzilmaydi)
  public let created: Date?          // default nil
  public let kindName: String        // default ""
  public var ext: String { get }     // papka/symlink-papka: ""; aks holda nomning extension'i (asl harflar)
  public var baseName: String { get } // ext bo'lsa "name" − ".ext", aks holda name
  public enum SortColumn { case name, size, modified, ext, created, kind }
  ```
- Ext qoidasi: `(name as NSString).pathExtension`, lekin nom `.` bilan boshlanib boshqa nuqtasi bo'lmasa yoki ext bo'sh bo'lsa — `""`.
- Saralash: `ext` va `kind` — `localizedStandardCompare` (katta-kichik farqsiz); `created` — `nil` eng kichik. Papkalar doim tepada, tenglikda nom.
- `DirectoryReader`: `.creationDateKey` prefetch; `kindName` — papka "Folder", package/fayl — `UTType(filenameExtension:)?.localizedDescription`, extension yo'q fayl "Document", symlink "Alias"; bitta `list` ichida extension bo'yicha kesh.

- [ ] **Step 1: Failing testlar**

```swift
// FileSortTests
@Test func extensionParts()   // "archive.tar.gz" → ext "gz", baseName "archive.tar"; ".env" → "", ".env"; "file." → "", "file."; papka "a.b" → ext ""
@Test func sortsByExtensionThenName()  // [b.txt, a.pdf, c.pdf, dir/] ext ↑ → [dir, a.pdf, c.pdf, b.txt]
@Test func sortsByKindAndCreated()     // kindName "PDF"/"Text" bo'yicha; created nil < date
// DirectoryReaderTests
@Test func readsCreatedAndKind()       // fayl "a.pdf" → created != nil, kindName bo'sh emas; papka → kindName "Folder"
```

- [ ] **Step 2: Run** `swift test --package-path Packages/CommanderKit --filter "FileSortTests|DirectoryReaderTests"` → FAIL (yo'q a'zolar).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** → PASS; to'liq `swift test` → PASS; benchmark `CK_BENCHMARK=1 … DirectoryReaderBenchmark` ≤100 ms.
- [ ] **Step 5: Commit** — `Read created date and kind; sort by extension, created and kind`

---

### Task 2: Ustun sozlamalari (Core + Controller)

**Files:**
- Modify: `Sources/CommanderCore/Settings.swift`, `Sources/CommanderController/Texts.swift`; Create: `Sources/CommanderController/WindowModel+Columns.swift`
- Test: `Tests/CommanderCoreTests/SettingsCodingTests.swift`, `Tests/CommanderControllerTests/ColumnTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum ColumnID: String, Codable, CaseIterable, Sendable { case ext, size, modified, created, kind }
  public struct ColumnSetting: Codable, Equatable, Sendable { public var id: ColumnID; public var width: Double }
  // AppearanceSettings
  public var columns: [ColumnSetting]   // default: ext 60, size 72, modified 135
  public static let defaultColumnWidths: [ColumnID: Double]  // ext 60, size 72, modified 135, created 135, kind 120
  extension ColumnID { public var title: String }   // "Ext", "Size", "Modified", "Created", "Kind"
  extension ColumnID { public var sortColumn: SortColumn }
  extension WindowModel {
      public func toggleColumn(_ id: ColumnID)            // yo'q bo'lsa oxiriga default kenglik bilan; bor bo'lsa olib tashlaydi
      public func setColumns(_ columns: [ColumnSetting])  // tartib/kenglik (sudrash, resize); o'zgarmasa hech narsa
  }
  ```
- Dekodlash: `columns` xom ro'yxat sifatida o'qiladi; noma'lum id va takrorlar tashlanadi; kalit yo'q bo'lsa default.

- [ ] **Step 1: Failing testlar**

```swift
@Test func columnsDefaultAndRoundTrip()     // AppSettings().appearance.columns.map(\.id) == [.ext, .size, .modified]; encode/decode teng
@Test func columnsDecodeLeniently()         // [{"id":"name"},{"id":"kind","width":90},{"id":"kind","width":5},{"id":"bogus"}] → [kind 90]
@Test func toggleColumnAddsAndRemoves()     // toggle(.kind) → oxirida kind 120; toggle(.ext) → ext yo'q; onSettingsChange chaqirilgan
@Test func setColumnsReordersAndKeepsWidths()
```

- [ ] **Step 2: Run** `--filter "SettingsCodingTests|ColumnTests"` → FAIL. **Step 3:** implement. **Step 4:** PASS + to'liq `swift test`.
- [ ] **Step 5: Commit** — `Add configurable column settings`

---

### Task 3: Cut belgisi (Controller)

**Files:**
- Create: `Sources/CommanderController/WindowModel+Cut.swift`, `Tests/CommanderControllerTests/CutTests.swift`
- Modify: `WindowModel.swift` (stored `cutPaths: Set<String>`), `WindowModel+Files.swift`, `WindowModel.appDidBecomeActive`

**Interfaces:**
- Produces: `extension WindowModel { public func isCut(_ item: FileItem) -> Bool }` (standardized yo'l bo'yicha).
- ⌘X → `cutPaths` = targets; ⌘C, Copy Path, Copy Name → bo'sh; cut paste → bo'sh; `appDidBecomeActive` → `pasteboard.readFiles()?.isCut != true` bo'lsa bo'sh. Har o'zgarishda ikkala panelga `stateDidChange(.pane(_))`.

- [ ] **Step 1: Failing testlar**

```swift
@Test func cutMarksItems()              // ⌘X b.txt → isCut(b.txt) true, c.txt false
@Test func copyClearsCut()              // ⌘X keyin ⌘C → hech biri cut emas
@Test func pasteOfCutClearsCut()        // FileHarness: ⌘X, right'ga o'tib ⌘V → isCut false
@Test func foreignClipboardClearsCut()  // ⌘X; pasteboard.clearCut(); appDidBecomeActive → false
@Test func cutShowsInBothPanes()        // ikkala panel /root; ⌘X → right tab item ham isCut
```

- [ ] **Step 2: Run** `--filter CutTests` → FAIL. **Step 3:** implement. **Step 4:** PASS + to'liq.
- [ ] **Step 5: Commit** — `Remember cut items for display`

---

### Task 4: Reveal in Commander (Controller + App)

**Files:**
- Create: `Sources/CommanderController/WindowModel+Reveal.swift`, `Tests/CommanderControllerTests/RevealTests.swift`
- Modify: `App/AppDelegate.swift` (Services provider, `application(_:open:)`, model tayyor bo'lguncha navbat), `project.yml` (`NSServices`, `CFBundleDocumentTypes`)

**Interfaces:**
- Produces: `extension WindowModel { public func reveal(_ url: URL) }` — faol panelda `newTab`; papka (navigable) → shu papka; fayl/package → ota papka + `pendingCursor`; yo'q → beep.
- `NSServices`: `NSMenuItem.default = "Reveal in Commander"`, `NSMessage = revealInCommander`, `NSSendFileTypes = [public.item]`, `NSRequiredContext = {}`. Handler: birinchi fayl URL'i → `model.reveal`, `NSApp.activate()`.
- `CFBundleDocumentTypes`: bitta tur, `LSItemContentTypes = [public.item]`, `CFBundleTypeRole = Viewer`, `LSHandlerRank = None`.

- [ ] **Step 1: Failing testlar**

```swift
@Test func revealFileOpensParentInNewTab()   // FileHarness: right faol; reveal(left/a.txt) → right tabs 2 ta, path left, cursor "a.txt"
@Test func revealFolderOpensIt()             // reveal(left/sub) → path left/sub
@Test func revealPackageSelectsIt()          // "X.app/" → path left, cursor "X.app"
@Test func revealMissingBeeps()              // → beeps 1, tablar soni o'zgarmagan
```

- [ ] **Step 2: Run** `--filter RevealTests` → FAIL. **Step 3:** implement (Controller, keyin App). **Step 4:** PASS + to'liq; App build.
- [ ] **Step 5: Qo'lda tekshirish** — `open -a build/…/Commander.app ~/Downloads` → yangi tab; Finder Services ro'yxatida band (`/System/Library/CoreServices/pbs -update` dan keyin).
- [ ] **Step 6: Commit** — `Add Reveal in Commander service and open handling`

---

### Task 5: Bitta panel — to'liq kenglik

**Files:**
- Modify: `App/PanesViewController.swift`
- Test: `AppUITests/SmokeTests.swift`

- [ ] **Step 1: UI test** `testSinglePaneUsesFullWidth` — `pane.left` kengligi `w0`; `⌘\` → `pane.left.frame.width > w0 * 1.8`; `⌘\` → kenglik `w0 ± 10`.
- [ ] **Step 2: Run** → FAIL. **Step 3:** tuzatish. **Step 4:** PASS + to'liq UI.
- [ ] **Step 5: Commit** — `Let the left pane fill the window in single-pane mode`

---

### Task 6: Ustunlar (App) va cut ko'rinishi

**Files:**
- Modify: `App/Pane/FileTableController.swift` (ustunlar settings'dan; Name/Ext/Created/Kind kataklari; cut: ✂ `scissors` belgisi + kursiv accent nom), `App/Pane/PaneViewController.swift` (ustunlar o'zgarsa qayta qurish; cut o'zgarsa qatorlarni yangilash; sarlavha menyusi; `columnDidMove/DidResize` → `model.setColumns`)
- Test: `AppUITests/SmokeTests.swift`

- [ ] **Step 1: UI testlar**

```swift
func testHeaderMenuTogglesKindColumn()   // table.left sarlavhasida o'ng tugma → "Kind" → table.left.buttons["Kind"] bor; yana → yo'q
func testCutShowsScissors()             // alpha.txt da ⌘X → table.left.images["Cut"] mavjud
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4:** PASS + to'liq UI (mavjud testlar: "alpha.txt" endi Name'da "alpha" + Ext "txt" — testlar moslanadi).
- [ ] **Step 5: Qo'lda tekshirish** — screenshot: Ext ustuni, kursiv cut, yashirin+cut, qayta ochganda saqlangan.
- [ ] **Step 6: Commit** — `Add configurable columns and cut styling`

---

### Task 7: Copy To — papka brauzeri

**Files:**
- Modify: `Sources/CommanderController/WindowModel+Destinations.swift`, `App/Dialogs/CopyToView.swift`
- Test: `Tests/CommanderControllerTests/DestinationTests.swift`, `AppUITests/SmokeTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public func folderSuggestions(for text: String, limit: Int? = 10) async -> [String]   // limit nil — hammasi
  public enum PathText {
      public static func enter(_ folder: String) -> String        // "/a/b" → "/a/b/"
      public static func parent(of text: String) -> String         // "/a/b/" → "/a/"; "/a/b" → "/a/"; "/" → "/"
  }
  ```
- Dialog: chapda Recent/Tabs/Favorites (ixcham), o'ngda brauzer (`folderSuggestions(limit: nil)`), tanlov indeksi; yo'l maydoni delegate: `moveUp/moveDown` → tanlov, `insertNewline` → tanlov bo'lsa `enter`, aks holda confirm; `deleteBackward` matn `/` bilan tugasa → `parent`; `⌘↑` → `parent`; Copy/Move tugmasi `⌘↵`.

- [ ] **Step 1: Failing testlar**

```swift
@Test func suggestionsWithoutLimitListAll()   // 12 papka → limit nil = 12, default = 10
@Test func parentOfRootIsRoot()               // PathText.parent(of: "/") == "/"; "/a/b/" → "/a/"; "/a/b" → "/a/"
@Test func enterAddsSlash()                    // PathText.enter("/a/b") == "/a/b/"
// UI
func testCopyToBrowserEntersFolder()   // ⌥F5 → maydon root+"/" → "nested" tanlanguncha ↓ → ↵ → maydon …/nested/ → ⌘↵ → root/nested/alpha.txt bor
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4:** PASS; to'liq testlar.
- [ ] **Step 5: Qo'lda tekshirish** — screenshot: brauzer ko'rinishi, ⌫ bilan yuqoriga, double-click.
- [ ] **Step 6: Commit** — `Browse folders inside the Copy To dialog`

---

### Task 8: Hujjatlar, yakuniy tekshiruv, DMG

**Files:**
- Modify: `AGENTS.md`, `docs/brainstorm/2026-10-21-commander-decisions.md` ("Open in Commander" 3 → 1D; 1E rejasi), `docs/superpowers/specs/2026-10-21-phase1-core-design.md` (jadval)

- [ ] **Step 1:** `swift test` → hammasi PASS; `xcodebuild test` → hammasi PASS.
- [ ] **Step 2:** Hujjatlarni yangilash; `scripts/make-dmg.sh`.
- [ ] **Step 3: Commit** — `Record phase 1D status`
