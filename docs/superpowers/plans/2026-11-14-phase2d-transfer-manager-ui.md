# Phase 2D Implementation Plan: Transfer Manager Sheet va Status Bar UI

Sana: 2026-11-14  
Spec: `docs/superpowers/specs/2026-11-14-phase2-file-operations-design.md`  
Qamrov: Background Transfer Manager Sheet yaratish, FooterView integratsiyasi, tezlik/ETA ko'rsatish va menyu buyrug'i.

---

## 1. Vazifalar

### Task 1: `TransferManagerSheet.swift` (SwiftUI + AppKit)
- Fayl: `App/Dialogs/TransferManagerSheet.swift`
- Mantiq:
  - In-App Modal Sheet (asosiy oynaning ustida ochiladi, `Esc` bilan yopiladi).
  - Barcha faol va bajarilayotgan operatsiyalar ro'yxati (`OperationState`).
  - Har bir operatsiya uchun: progress bar, baytlar va fayllar soni, joriy fayl nomi, Cancel tugmasi.
  - Agar operatsiyalar bo'lmasa: "No active background transfers" ko'rsatiladi.

### Task 2: `FooterView.swift` da Transfer Manager integratsiyasi
- Fayl: `App/Window/FooterView.swift`
- Mantiq:
  - `OperationRow` ga tezlik/ETA va Transfer Manager tugmasi (`slider.horizontal.3`) qo'shish.
  - Bosilganda `windowController.showTransferManager()` chaqiriladi.

### Task 3: `MainWindowController.swift` va `MainMenu.swift` integratsiyasi
- Fayllar:
  - `App/MainWindowController.swift`
  - `App/MainMenu.swift`
  - `App/System/AppKitEffects.swift`
- Mantiq:
  - `MainWindowController.showTransferManager()` metodi.
  - `Window` menyusiga "Background Transfer Manager…" (`⌥⌘B`) qo'shish.

---

## 2. Tekshirish mezonlari
- `xcodebuild build` muvaffaqiyatli chiqishi.
- Barcha `swift test` 373+ testlar muvaffaqiyatli o'tishi.
