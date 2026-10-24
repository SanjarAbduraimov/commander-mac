# 1-bosqich E — Multi-Rename va belgilash vositalari Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** TC uslubidagi Multi-Rename Tool (shablon, qidirish/almashtirish, harf, hisoblagich, oldindan ko'rish, xavfsiz bajarish, undo) va shablon bo'yicha belgilash vositalari.

**Architecture:** Shablon dvigateli va preview — `CommanderController` da sof funksiyalar (TDD). Ommaviy rename (vaqtinchalik nomlar, rollback) — `CommanderFileSystem` da. `WindowModel` buyruqlar, undo va effektlarni bog'laydi; App faqat sheet va so'rov oynasini ko'rsatadi.

**Tech Stack:** Swift 6, Swift Testing, AppKit, SwiftUI, XcodeGen, XCUITest.

**Spec:** `docs/superpowers/specs/2026-10-24-phase1e-multi-rename-design.md`

## Global Constraints

- Avvalgi plan'larning Global Constraints'i amal qiladi (Core/FileSystem/Controller AppKit'siz; hamma narsa `Command` orqali; UI matnlari inglizcha).
- Branch: `phase1e-multi-rename` (`main` dan).
- Default tugmalar: Multi-Rename `ctrl+m`; Mark by Pattern `cmd+=`; Unmark by Pattern `cmd+-`; Invert Marks `cmd+shift+i`; Mark Same Extension `opt+cmd+=`. Undo Multi-Rename — tugmasiz (Edit menyu).
- Recent patterns — 10 ta.
- Testlar: `swift test --package-path Packages/CommanderKit`; `xcodegen generate && xcodebuild test -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64'`.

## Review Focus

1. **Faqat katta-kichik harfi o'zgaradigan nom** (`a.txt` → `A.txt`) — "exists" deb hisoblanmasligi, bajarilishi. → Task 1 `caseOnlyChangeIsNotAConflict`, Task 2 `caseOnlyRename`.
2. **Almashinuv zanjiri** (`a`→`b`, `b`→`a`) — ikkalasi ham to'g'ri. → Task 2 `swapsNames`.
3. **Yarmida xato** — avvalgilari asliga qaytadi. → Task 2 `rollsBackOnFailure`.
4. **Undo'dan oldin fayl o'zgargan** — mavjudlari qaytadi, yo'qlari sanaladi. → Task 3 `undoSkipsMissing`.
5. **Yashirin fayl bilan to'qnashuv** — panelda ko'rinmasa ham "exists". → Task 3 `previewSeesHiddenNames`.

---

### Task 1: Shablon dvigateli va preview

**Files:**
- Create: `Sources/CommanderController/MultiRename.swift`, `Tests/CommanderControllerTests/MultiRenameTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum NameCase: String, CaseIterable, Sendable { case unchanged, lower, upper, firstLetter, title }
  public struct MultiRenameOptions: Equatable, Sendable {
      public var nameMask = "[N]", extMask = "[E]", search = "", replace = ""
      public var useRegex = false, caseSensitive = false, nameCase = NameCase.unchanged
      public var counterStart = 1, counterStep = 1, counterDigits = 1
      public init()
  }
  public enum RenameProblem: Equatable, Sendable { case empty, invalidCharacter, exists, duplicate, invalidRegex }
  public struct MultiRenameRow: Equatable, Sendable {
      public let item: FileItem; public let newName: String; public let problem: RenameProblem?
      public var isChanged: Bool { newName != item.name }
  }
  public enum MultiRename {
      /// existing — papkadagi barcha nomlar (yashirinlar ham)
      public static func preview(_ items: [FileItem], folderName: String, existing: Set<String>, options: MultiRenameOptions) -> [MultiRenameRow]
  }
  extension NameCase { public var title: String }   // "Unchanged", "lowercase", "UPPERCASE", "First letter", "Title Case"
  ```
- Tartib: maska → qidirish/almashtirish → harf. `exists`: yangi nom (katta-kichik farqsiz) to'plamdan tashqari biror mavjud nomga teng, va o'zining eski nomi emas. `duplicate`: to'plam ichida ikki yangi nom katta-kichik farqsiz teng.

- [ ] **Step 1: Failing testlar**

```swift
@Test func defaultMasksKeepNames()           // [N].[E] → o'zgarmagan, isChanged false, problem nil
@Test func nameRangesAndCounter()            // "[N1-3]_[C]" counter start 5 step 2 digits 3: "photo.jpg","x.png" → "pho_005.jpg","x_007.png"
@Test func openRangeAndSingleChar()          // "[N3-]" "abcdef"→"cdef"; "[N2]" → "b"; "[N9-]" → "" (empty problem)
@Test func parentAndDateTags()               // "[P]-[YMD]-[hms]" sana 2026-10-24 15:30:12 mahalliy → "Holiday-20261024-153012.jpg"
@Test func unknownTagStaysText()             // "[X][N]" → "[X]name"
@Test func plainAndRegexReplace()            // search "IMG" → "Photo"; regex "(\\d+)" → "n$1"; caseSensitive false matches "img"
@Test func invalidRegexMarksAllRows()        // search "(" regex → har qator .invalidRegex
@Test func caseModes()                       // lower/upper/firstLetter/title: "my FILE name.TXT"
@Test func conflictsAreReported()            // existing ["b.txt"] → a→b.txt .exists; ikkisi "same.txt" → .duplicate; "a/b" → .invalidCharacter
@Test func caseOnlyChangeIsNotAConflict()    // "a.txt" → "A.txt", existing ["a.txt"] → problem nil
@Test func folderHasNoExtension()            // papka "My.Folder" "[N]_x" → "My.Folder_x"
```

- [ ] **Step 2: Run** `--filter MultiRenameTests` → FAIL. **Step 3:** implement. **Step 4:** PASS + to'liq `swift test`.
- [ ] **Step 5: Commit** — `Add multi-rename pattern engine and preview`

---

### Task 2: Ommaviy rename (FileSystem)

**Files:**
- Create: `Sources/CommanderFileSystem/BatchRename.swift`, `Tests/CommanderFileSystemTests/BatchRenameTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct RenamePair: Equatable, Sendable { public let from: URL; public let to: URL }
  public enum BatchRename {
      /// Avval hammasi vaqtinchalik nomlarga, keyin yakuniy nomlarga; xatoda bajarilganlar asliga qaytariladi.
      public static func run(_ pairs: [RenamePair]) throws(BatchRenameError)
  }
  public struct BatchRenameError: Error, Equatable, Sendable { public let message: String }
  ```
- `from == to` juftliklar o'tkazib yuboriladi; nishon to'plamdan tashqari mavjud bo'lsa (o'zining o'zi emas) — boshlamasdan xato.

- [ ] **Step 1: Failing testlar**

```swift
@Test func renamesAll()            // a.txt→x.txt, b.txt→y.txt
@Test func swapsNames()            // a→b, b→a: tarkib almashgan
@Test func caseOnlyRename()        // a.txt→A.txt: listing "A.txt"
@Test func refusesExistingTarget() // c.txt mavjud, a→c → xato, a joyida
@Test func rollsBackOnFailure()    // ikkinchi juftlik manbasi yo'q → xato; birinchisi asl nomida, vaqtinchalik fayl qolmagan
```

- [ ] **Step 2: Run** `--filter BatchRenameTests` → FAIL. **Step 3:** implement (`Darwin.rename`). **Step 4:** PASS + to'liq.
- [ ] **Step 5: Commit** — `Add batch rename with rollback`

---

### Task 3: Multi-Rename buyrug'i, bajarish va Undo (Controller)

**Files:**
- Create: `Sources/CommanderController/WindowModel+MultiRename.swift`, `Tests/CommanderControllerTests/MultiRenameCommandTests.swift`
- Modify: `Command.swift` (+ `multiRename`, `undoMultiRename`), `KeyBindings.swift` (`ctrl+m`), `Command+Title.swift` ("Multi-Rename…", "Undo Multi-Rename"), `Environment.swift` (`showMultiRename`), `WindowModel+Commands.swift`, `WindowModel+Files.swift` (F2 aqlli), `WindowModel+Mouse.swift` (kontekst menyu: `rename` dan keyin `multiRename`), `Fakes.swift`, `ContextMenuTests.fileMenuEntries`

**Interfaces:**
- Produces:
  ```swift
  public struct MultiRenameRequest: Equatable, Sendable { public let side: PaneSide; public let folder: URL; public let items: [FileItem]; public let existing: Set<String> }
  // WindowEffects
  func showMultiRename(_ request: MultiRenameRequest)
  extension WindowModel {
      public func applyMultiRename(_ rows: [MultiRenameRow], in request: MultiRenameRequest) async -> String?  // nil — muvaffaqiyat
      public var canUndoMultiRename: Bool { get }
      public func undoMultiRename() async -> String?   // nil yoki "N item(s) could not be restored."
  }
  ```
- `perform(.multiRename)`: targets bo'sh → beep; `existing` = papkaning barcha nomlari (`listingExecutor`'da) → `showMultiRename`. Muvaffaqiyatdan keyin: panel qayta o'qiladi, belgilar tozalanadi, kursor birinchi yangi nomda.
- `perform(.rename)`: `tab.marked.count > 1` → `.multiRename`.
- `isEnabled(.multiRename)` — targets bo'sh emas; `.undoMultiRename` — `canUndoMultiRename`.

- [ ] **Step 1: Failing testlar**

```swift
@Test func ctrlMOpensRequestWithHiddenNames()
@Test func previewSeesHiddenNames()
@Test func f2WithSeveralMarkedOpensMultiRename()
@Test func applyRenamesAndReloads()
@Test func undoRestoresNames()
@Test func undoSkipsMissing()
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4:** PASS + to'liq.
- [ ] **Step 5: Commit** — `Add Multi-Rename command with undo`

---

### Task 4: Belgilash vositalari (Core + Controller)

**Files:**
- Create: `Sources/CommanderCore/NamePattern.swift`, `Tests/CommanderCoreTests/NamePatternTests.swift`, `Tests/CommanderControllerTests/MarkPatternTests.swift`
- Modify: `TabState+Cursor.swift`, `Session.swift` (`recentPatterns`), `Command.swift`, `KeyBindings.swift`, `Command+Title.swift`, `Environment.swift` (`askPattern`), `WindowModel+Commands.swift`, `Fakes.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct NamePattern: Sendable { public init(_ text: String); public func matches(_ name: String) -> Bool }
  extension TabState {
      public mutating func mark(matching pattern: NamePattern)
      public mutating func unmark(matching pattern: NamePattern)
      public mutating func invertMarks()
      public mutating func markSameExtension()
  }
  public struct PatternRequest: Equatable, Sendable { public let marking: Bool; public let recent: [String] }
  // WindowEffects
  func askPattern(_ request: PatternRequest) async -> String?
  // Session
  public var recentPatterns: [String]; public mutating func addRecentPattern(_ text: String)
  ```
- Titles: "Mark by Pattern…", "Unmark by Pattern…", "Invert Marks", "Mark Same Extension".

- [ ] **Step 1: Failing testlar**

```swift
@Test func wildcardsAndSeparators()   // "*.jpg; *.PNG" — "a.JPG" ✓, "b.png" ✓, "c.gif" ✗; "a?c" — "abc" ✓; "" — hech narsa
@Test func markAndUnmarkByPattern()
@Test func cancelledPatternChangesNothing()
@Test func invertMarks()
@Test func markSameExtension()
@Test func phase1eDefaults()          // ctrl+m, cmd+=, cmd+-, cmd+shift+i, opt+cmd+=
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4:** PASS + to'liq.
- [ ] **Step 5: Commit** — `Add mark by pattern, invert marks and mark same extension`

---

### Task 5: App — Multi-Rename sheet, pattern so'rovi, menyular

**Files:**
- Create: `App/Dialogs/MultiRenameView.swift`
- Modify: `App/System/AppKitEffects.swift`, `App/Dialogs/AlertPrompts.swift` (`askPattern`), `App/MainMenu.swift`
- Test: `AppUITests/SmokeTests.swift`

Dialog: Name mask / Ext mask va teg tugmalari, Search / Replace + Regex + Case sensitive, Case popup, Counter; preview jadvali (o'zgarmagan xira, muammo qizil + sabab); Undo Last, Cancel (Esc), Rename N (↵/⌘↵, muammo bo'lsa o'chiq). Identifier'lar: `multiRename.nameMask`, `multiRename.rename`.

- [ ] **Step 1: UI testlar**

```swift
func testMultiRenameRenamesMarkedFiles()  // alpha.txt + beta.txt; ⌘A; ⌃M; nameMask "[N]_x" → Rename → alpha_x.txt, beta_x.txt
func testMarkByPattern()                  // ⌘= → "*.txt" ↵ → "1 marked in left pane"
```

- [ ] **Step 2: Run** → FAIL. **Step 3:** implement. **Step 4:** PASS + to'liq UI.
- [ ] **Step 5: Qo'lda tekshirish** — screenshot.
- [ ] **Step 6: Commit** — `Add Multi-Rename dialog and pattern marking UI`

---

### Task 6: Hujjatlar, review, DMG

- [ ] `swift test`, `xcodebuild test` → PASS; AGENTS.md, decisions, core spec jadvali; yakuniy review; `scripts/make-dmg.sh`; commit `Record phase 1E status`.
