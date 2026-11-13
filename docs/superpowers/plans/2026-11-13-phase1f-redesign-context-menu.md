# 1-bosqich F — Kengaytirilgan kontekst menyu, In-App sozlamalar, Rasm Paste va Modern UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Commander for Mac 1F bosqichini amalga oshirish: Smart Type-Ahead (aylanib o'tish va yashirin fayllar), In-App Modal Settings, Clipboard Image Paste (Telegram uslubida), File Associations (doimiy dastur biriktirish), Quick Look (<kbd>F3</kbd>), Windows File Explorer uslubidagi inline yaratish va AppKit UI'ni macOS 15 Sequoia darajasida modernizatsiya qilish (SF Symbols 6, modern card/pill tablar).

**Architecture:** 
- Core/Controller sof Swift (TDD): `TypeAhead` cycling mantiqi, `FileAssociations` va `ClipboardImage` modeli.
- AppKit UI: `IconCache` ni SF Symbols va rangli ierarxiya bilan yangilash; `TabBarView` ni modern card/pill dizayniga o'tkazish; In-App Sheet/Modal tizimini joriy qilish.

**Tech Stack:** Swift 6, Swift Testing, AppKit, SwiftUI (dialoglar uchun), XcodeGen, XCUITest.

**Spec:** `docs/superpowers/specs/2026-11-13-phase1f-redesign-context-menu.md`

---

## Global Constraints

- Core va Controller modullari sof Swift bo'lib qoladi (`AppKit` import qilinmaydi), barcha yangi funksiyalar unit testlar bilan qoplanadi.
- Mavjud 343 unit testlar va 25 XCUITest buzilmasligi shart.
- Branch: `phase1f-redesign-context-menu` (`main` dan).
- Klaviatura shortcutlarida to'qnashuv bo'lmasligi shart:
  - <kbd>Space</kbd> — faqat va faqat **Mark & Next**.
  - <kbd>F3</kbd> / <kbd>⌘Y</kbd> — **Quick Look**.
  - <kbd>F7</kbd> / <kbd>⌘⇧N</kbd> — **New Folder**.
  - <kbd>⌘N</kbd> — **New File**.
  - <kbd>⌥⌘T</kbd> — **Open in Terminal**.
  - <kbd>⌥↩</kbd> — **Open With App Chooser**.

---

### Task 1: Smart Type-Ahead — Aylanib o'tish va yashirin fayllarni qidirish

**Files:**
- Modify: `Packages/CommanderKit/Sources/CommanderCore/TypeAhead.swift`
- Modify: `Packages/CommanderKit/Tests/CommanderCoreTests/TypeAheadTests.swift`

**Requirements:**
- Bir xil harf ketma-ket bosilganda (1 soniya ichida) matching elementlar bo'ylab aylanib o'tish (cycle).
- Nuqtali fayllar (`.git`, `.env`) harf terilganda (masalan, `g`) ham topilishi.
- Agar qidiruv prefiksi `.` bilan boshlansa, to'g'ridan-to'g'ri nuqtali nomlarga mos kelishi.

- [ ] **Step 1: TypeAheadTests ga yangi testlar yozish (Failing tests)**
- [ ] **Step 2: TypeAhead.swift ni yangilash va testlarni yashil qilish**
- [ ] **Step 3: Testlarni tekshirish (`swift test --package-path Packages/CommanderKit --filter TypeAheadTests`)**

---

### Task 2: File Associations va Settings Modelini kengaytirish

**Files:**
- Modify: `Packages/CommanderKit/Sources/CommanderCore/Settings.swift`
- Modify: `Packages/CommanderKit/Tests/CommanderCoreTests/SettingsTests.swift`

**Requirements:**
- `AppSettings` ga `fileAssociations: [String: String]` (kengaytma → ilova yo'li/nomi) lug'atini qo'shish.
- `ClipboardSettings` (avtomatik nomlash shabloni, format, confirmPaste) qo'shish.
- JSON saqlash, o'qish va orqaga moslik (backward compatibility) testlari.

- [ ] **Step 1: SettingsTests ga testlar yozish**
- [ ] **Step 2: Settings.swift ni kengaytirish**
- [ ] **Step 3: Testlarni tekshirish (`swift test --package-path Packages/CommanderKit --filter SettingsTests`)**

---

### Task 3: WindowModel — Open With, Paste Image va Terminal amallari

**Files:**
- Modify: `Packages/CommanderKit/Sources/CommanderController/WindowModel+Commands.swift`
- Modify: `Packages/CommanderKit/Sources/CommanderController/WindowModel.swift`
- Modify: `Packages/CommanderKit/Tests/CommanderControllerTests/KeyHandlingTests.swift`

**Requirements:**
- `Command` enumiga `openInTerminal`, `openWithAppChooser`, `pasteImage` buyruqlarini kiritish.
- `openCurrentFile`: agar `fileAssociations` da ushbu kengaytma bo'lsa, o'sha ilovada ochish.
- Shortcut remap va default bindinglar.

- [ ] **Step 1: Controller testlariga test qo'shish**
- [ ] **Step 2: Commands va WindowModel ni yangilash**
- [ ] **Step 3: Testlarni tekshirish (`swift test --package-path Packages/CommanderKit --filter KeyHandlingTests`)**

---

### Task 4: Modern IconCache — SF Symbols 6 va Vektor Ikonkalar

**Files:**
- Modify: `App/System/IconCache.swift`

**Requirements:**
- Eski tizim dok-ikonkalari o'rniga zamonaviy SF Symbols (`folder.fill` oranj/ko'k, `photo.fill` yashil, `doc.text.fill` qizil PDF, `chevron.left.forwardslash` kod).
- macOS 15 ierarxik ranglari bilan sifatli render.

- [ ] **Step 1: IconCache.swift ni yangilash**
- [ ] **Step 2: Fayl jadvalida testlash**

---

### Task 5: In-App Modal Settings & Modern TabBar / Titlebar

**Files:**
- Modify: `App/Pane/TabBarView.swift`
- Modify: `App/MainWindowController.swift`
- Modify: `App/Settings/SettingsWindowController.swift` (yoki in-app sheet host)

**Requirements:**
- TabBarView: `.recessed` tugmalardan modern card/pill tablarga o'tish (rounded corners, subtle shadow, active state).
- Settings: alohida suzuvchi oyna o'rniga, asosiy oyna ustida sheet/in-app modal sifatida ochilish.
- File Associations va yangi sozlamalar UI'sini kiritish.

- [ ] **Step 1: TabBarView ni modernizatsiya qilish**
- [ ] **Step 2: In-App Settings Sheet ni ulash**

---

### Task 6: Open With App Chooser va Telegram Share

**Files:**
- Create: `App/Dialogs/AppChooserSheet.swift`
- Modify: `App/Pane/FileTableController.swift`
- Modify: `App/Window/SelectionBarView.swift`

**Requirements:**
- <kbd>⌥↩</kbd> bosilganda ilova tanlash sheet'i chiqishi, "Har doim shu dasturda ochish" checkbox'i.
- Selection Bar va kontekst menyuda Telegram'ga yuborish tugmasi (`NSSharingService`).

- [ ] **Step 1: AppChooser dialogini yaratish**
- [ ] **Step 2: Telegram Share'ni ulash**

---

### Task 7: Windows File Explorer Uslubidagi Inline Yaratish

**Files:**
- Modify: `App/Pane/FileTableController.swift`
- Modify: `App/MainWindowController.swift`

**Requirements:**
- Sarlavha panelida `+ New ▾` split tugmasi.
- <kbd>F7</kbd> yoki <kbd>⌘N</kbd> bosilganda jadvalning tepasida inline satr ochilib, nom kiritilishi va <kbd>↩ Enter</kbd> bilan saqlanishi.

- [ ] **Step 1: Inline create row logikasini kiritish**
- [ ] **Step 2: Keyboard oqimini tekshirish**

---

### Task 8: Yakuniy Tekshiruv va Testlar

- [ ] **Step 1: Core/Controller testlari to'liq o'tishi (`swift test --package-path Packages/CommanderKit`)**
- [ ] **Step 2: Xcode loyihasini generatsiya qilish (`xcodegen generate`)**
- [ ] **Step 3: App build va XCUITest smoke testlarini ishga tushirish**
- [ ] **Step 4: Foydalanuvchi sinovi uchun yangi DMG tayyorlash (`scripts/make-dmg.sh`)**
