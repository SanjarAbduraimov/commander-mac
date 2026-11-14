# Phase 3 UX Polish Implementation Plan: Image Paste, In-App Settings, TC Quick View, and Modern macOS 15 Design

Sana: 2026-11-14  
Muallif: Antigravity  
Qamrov:
1. **Clipboard Image Paste (`⌘V`)**: Clipboard'dan rasm nusxalanganda to'g'ridan-to'g'ri `⌘V` orqali fayl sifatida yaratish.
2. **In-App Modal Settings**: Sozlamalarni tashqi oyna emas, asosiy oyna ichida to'liq in-app sheet/overlay sifatida ochish va yopish (`⌘,`, `Esc`, `Done`).
3. **Total Commander Quick View (`⌃Q` / Live Preview)**: Qo'shni panelda tanlangan media/faylning jonli preview'sini ko'rsatish, `↑/↓` da avtomatik yangilanish, `Esc` bilan darhol chiqish.
4. **macOS 15 Native UI Polish**: Zamonaviy pill-style selection, visual effect materiallar, zamonaviy breadcrumb va tab dizayni.

---

## 1. Vazifalar

### Task 1: Clipboard Image Paste (`⌘V`) ni to'liq sozlash
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderController/Environment.swift` (FilePasteboard protokoli)
  - `App/System/SystemPasteboard.swift`
  - `Packages/CommanderKit/Sources/CommanderController/WindowModel+Commands.swift`
  - `Packages/CommanderKit/Sources/CommanderController/WindowModel+Files.swift`
  - `App/MainWindowController.swift`
- Mantiq:
  - `FilePasteboard` protokoliga `func hasImage() -> Bool` qo'shish.
  - `SystemPasteboard` da `hasImage()`: `NSImage.canInit(with: pasteboard)` yoki `public.png/tiff/jpeg` mavjudligini aniqlash.
  - `WindowModel.isEnabled(.paste)`: `pasteboard.readFiles() != nil || pasteboard.hasImage()`.
  - `WindowModel` da `perform(.paste)`: agar fayllar bo'lsa ularni nusxalash; agar fayllar bo'lmasa lekin rasm bo'lsa — avtomatik `effects.pasteImage(side)` chaqirish!
  - `MainWindowController.pasteImageFromClipboard`: raw PNG/TIFF/NSImage dan sifatli fayl yaratish, aktiv papkaga saqlash va kursorga qo'yish.

### Task 2: In-App Modal Settings Sheet (Oyna ichida)
- Fayllar:
  - `App/Settings/SettingsWindowController.swift`
  - `App/MainWindowController.swift`
- Mantiq:
  - Alohida `NSWindow` va macOS toolbar emas, to'g'ridan-to'g'ri `window.contentViewController?.presentAsSheet(...)` orqali in-app sheet.
  - Modern Segmented Tab Bar (Appearance, Behavior, Clipboard, Associations, Shortcuts) — ichki zamonaviy dizayn.
  - `Esc`, `⌘,`, yoki "Done" bosilganda sheet bir lahzada yopiladi.

### Task 3: Total Commander Quick View (`⌃Q` / Jonli Preview)
- Fayllar:
  - `Packages/CommanderKit/Sources/CommanderCore/Command.swift` (`.toggleQuickView`)
  - `Packages/CommanderKit/Sources/CommanderCore/KeyBindings.swift` (`ctrl+q`)
  - `Packages/CommanderKit/Sources/CommanderController/WindowModel+Commands.swift`
  - `Packages/CommanderKit/Sources/CommanderController/WindowModel.swift` (`quickViewSide: PaneSide?`)
  - `App/Pane/QuickViewPanel.swift` (Yangi viewer: Image, Video, Audio, Code/Text, PDF, Binary info)
  - `App/PanesViewController.swift` (Qo'shni panelni QuickViewPanel bilan almashtirish)
  - `App/Pane/FileTableView.swift` (`Esc` bosilganda Quick View ni yopish)
- Mantiq:
  - `⌃Q` (yoki Quick View tugmasi) bosilganda: qo'shni panel `QuickViewPanel` ga aylanadi.
  - Foydalanuvchi chap panelda `↑ / ↓` bilan yurganda, o'ng panelda shu fayl darhol preview qilinadi (rasm, video, matn, pdf).
  - `Esc` bosilganda: Quick View darhol yopilib, o'ng panel asl fayl jadvaliga qaytadi.

### Task 4: Zamonaviy macOS 15 UI Dizayni
- Fayllar:
  - `App/Pane/FileRowView.swift`: Rounded pill selection (inset 4px, `cornerRadius = 6`), yumshoq tint, silliq kursor indikatori.
  - `App/Pane/FileTableView.swift`: Zamonaviy qator balandligi va hover effektlari.
  - `App/Pane/TabBarView.swift`: Zamonaviy elevated pill tablar, close xmark tugmasi.
  - `App/Pane/BreadcrumbBar.swift`: Segmented pill breadcrumbs.
  - `App/Window/SelectionBarView.swift` va `FooterView.swift`: `NSVisualEffectView` shisha effekti va toza ikonka tugmalari.

---

## 2. Tekshirish mezonlari
- Barcha `swift test` 376+ testlar o'tishi kerak.
- `xcodebuild build` muvaffaqiyatli bo'lishi kerak.
- `scripts/make-dmg.sh` orqali yangi Release DMG yaratilishi kerak.
