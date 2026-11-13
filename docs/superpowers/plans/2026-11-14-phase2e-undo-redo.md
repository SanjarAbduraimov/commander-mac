# Phase 2E Implementation Plan: Undo / Redo (`⌘Z`, `⇧⌘Z`) Integratsiyasi

Sana: 2026-11-14  
Spec: `docs/superpowers/specs/2026-11-14-phase2-file-operations-design.md`  
Qamrov: `Command.undo` va `Command.redo` qo'shish, `WindowModel` da Undo/Redo ijrosi, Rename/Move/Copy/Trash amallarini qayd etish, MainMenu va TDD testlar.

---

## 1. Vazifalar

### Task 1: `Command.undo` va `Command.redo` (`CommanderCore`)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderCore/Command.swift`
  - `Packages/CommanderKit/Sources/CommanderCore/KeyBindings.swift`
  - `Packages/CommanderKit/Sources/CommanderController/Command+Title.swift`
  - `Packages/CommanderKit/Tests/CommanderCoreTests/KeyBindingsTests.swift`
- Chords:
  - `.undo`: `["cmd+z"]`
  - `.redo`: `["cmd+shift+z"]`
- TextField ruxsati: `isAllowedInTextField = false` (matn maydonlarida standart NSTextField undo ishlaydi).

### Task 2: `WindowModel` da `UndoStack` va ijro mantiqi (`CommanderController`)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderController/WindowModel.swift`
  - `Packages/CommanderKit/Sources/CommanderController/WindowModel+Commands.swift`
  - `Packages/CommanderKit/Sources/CommanderController/WindowModel+Files.swift`
  - `Packages/CommanderKit/Tests/CommanderControllerTests/UndoCommandTests.swift`
- Mantiq:
  - `performUndo()`: `undoStack.popUndo()` orqali teskari amalni bajaradi (`.rename`, `.move`, `.copy` trash, `.trash` restore).
  - `performRedo()`: `undoStack.popRedo()` orqali asl amalni qayta qo'llaydi.
  - `commitRename` muvaffaqiyatli bo'lganda avtomatik `undoStack.push` chaqiriladi.
  - Testlar: Rename qilib `⌘Z` bosilganda eski nomga qaytishi va `⇧⌘Z` bosilganda yangi nomga o'tishi.

### Task 3: `MainMenu.swift` integratsiyasi (`App/`)
- Fayl: `App/MainMenu.swift`
- Mantiq:
  - Edit menyusidagi Undo va Redo elementlarini `command(.undo)` va `command(.redo)` ga bog'lash.

---

## 2. Tekshirish mezonlari
- Barcha `swift test` 375+ testlar muvaffaqiyatli o'tishi.
- `xcodebuild build` muvaffaqiyatli chiqishi.
- `scripts/make-dmg.sh` orqali Release Universal DMG yaratilishi.
