# Phase 2C Implementation Plan: Kengaytirilgan Konflikt Dialogi

Sana: 2026-11-14  
Spec: `docs/superpowers/specs/2026-11-14-phase2-file-operations-design.md`  
Qamrov: To'qnashuv qarorlari (`ConflictDecision`) kengaytirilishi, `CopyOperation`/`MoveOperation` integratsiyasi va `ConflictDialogSheet` (UI).

---

## 1. Vazifalar

### Task 1: `ConflictDecision` va `ConflictDetails` kengaytirilishi (`CommanderCore`)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderCore/Operations.swift`
  - `Packages/CommanderKit/Sources/CommanderCore/Transfer/ConflictResolution.swift`
- O'zgarishlar:
  - `ConflictDecision` enum'iga `.replaceIfOlder`, `.replaceIfSizeDiffers`, `.resume` qo'shish.
  - `Conflict` struct'iga `details: ConflictDetails?` yoki URL'lardan `ConflictDetails` yaratish imkoniyati.
- Testlar: `Packages/CommanderKit/Tests/CommanderCoreTests/OperationsTests.swift`

### Task 2: `CopyOperation` va `MoveOperation` da yangi qarorlarni qo'llash (`CommanderFileSystem`)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderFileSystem/CopyOperation.swift`
  - `Packages/CommanderKit/Sources/CommanderFileSystem/MoveOperation.swift`
- Mantiq:
  - `.replaceIfOlder`: manba sanasi > nishon sanasi bo'lsa replace, aks holda skip.
  - `.replaceIfSizeDiffers`: manba hajmi != nishon hajmi bo'lsa replace, aks holda skip.
  - `.resume`: qolgan baytlardan davom ettirish (StreamFileCopier orqali).
- Testlar: `Packages/CommanderKit/Tests/CommanderFileSystemTests/CopyOperationTests.swift`

### Task 3: Kengaytirilgan `ConflictDialogSheet` (SwiftUI + AppKit)
- Fayllar:
  - `App/Dialogs/ConflictDialogSheet.swift`
  - `App/Dialogs/AlertPrompts.swift`
- Interfeys:
  - Yonma-yon taqqoslash (Mavjud fayl vs Yangi fayl): Hajmi, sanasi, qaysi biri yangiroq ekanligi rangi bilan, agar rasm bo'lsa thumbnail.
  - Tugmalar: Replace, If Older, If Size Differs, Auto-rename, Resume, Skip, Cancel.
  - "Apply to all" checkbox'i.

---

## 2. Tekshirish mezonlari
- `swift test` da barcha testlar muvaffaqiyatli o'tishi.
- `xcodebuild build` muvaffaqiyatli chiqishi.
