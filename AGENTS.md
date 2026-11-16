# Commander for Mac

Total Commander uslubidagi ikki panelli, klaviatura bilan tez ishlaydigan, yengil macOS file manager. Open-source (MIT litsenziyasi).

## Joriy holat

**UX & Qulaylik yaxshilanishlari: 4 ta asosiy talab to'liq bajarildi (2026-11-14): Clipboard Image Paste (`⌘V`), In-App Modal Settings Sheet (`⌘,`), Total Commander Quick View (`⌃Q`, `Esc`), va Zamonaviy macOS 15 Visual Polish (pill selection, frosted glass, chiclet shortcuts, spacious tabs, modern interactive split divider).**

- Asosiy manba — plan: `docs/superpowers/plans/2026-11-14-phase3-ux-polish.md`. Spec: `docs/superpowers/specs/2026-11-14-phase2-file-operations-design.md`.
- Bajarilgan plan'lar:
  - 1-bosqich: `phase1a-commanderkit.md`, `phase1b-app-ui.md`, `phase1c-feedback.md`, `phase1d-cut-reveal-columns.md`, `phase1e-multi-rename.md`, `phase1f-redesign-context-menu.md`.
  - 2-bosqich: `phase2a-transfer-queue.md`, `phase2b-stream-file-copier.md`, `phase2c-conflict-resolution.md`, `phase2d-transfer-manager-ui.md`, `phase2e-undo-redo.md`.
  - UX Polish: `2026-11-14-phase3-ux-polish.md`.
- Testlar: `swift test` — 381 ta test (63 suite), barchasi muvaffaqiyatli.
- Universal Release: `build/Commander.dmg` (3.6 MB, x86_64 + arm64).
- Keyingi qadam: 4-bosqich (SFTP/FTP tarmoq transferlari) yoki foydalanuvchi sinovi.

## Ish tartibi

- `superpowers` skill'lari bilan ishlanadi: `brainstorming` → `writing-plans` → `test-driven-development` / `executing-plans`.
- **Spec va implementation plan foydalanuvchi tomonidan tasdiqlanmaguncha mahsulot kodi yozilmaydi, Xcode loyihasi yaratilmaydi, dependency o'rnatilmaydi.**
- Spec'lar: `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`. Plan'lar: `docs/superpowers/plans/`.
- Yangi qaror qabul qilinganda `docs/brainstorm/2026-10-21-commander-decisions.md` yangilanadi (spec yozilgach — spec asosiy manba bo'ladi).
- Savollar bittadan, iloji bo'lsa variantlar (A/B/C) bilan va tavsiya ko'rsatilgan holda beriladi.
- Ish 4 bosqichga bo'lingan; har bosqich alohida spec → plan → kod sikli. Hozir faqat **1-bosqich (yadro)** ustida ishlanadi — keyingi bosqich funksiyalarini oldindan qurmang.

## Muloqot

- Foydalanuvchi bilan **o'zbek tilida**, texnik atamalar inglizcha (`NSTableView`, `drag & drop`, `shortcut`).
- Qisqa va to'g'ridan-to'g'ri. Kelishmovchilik yoki xavf bo'lsa — birinchi gapda ayting.

## Texnik yo'nalish (kelishilgan)

- Swift. **AppKit asosiy** (oyna, panellar, `NSTableView`, fokus, klaviatura, kontekst menyu, drag & drop). **SwiftUI faqat Settings va kichik dialoglar** uchun.
- Target: macOS 15.0+, asosiy qurilma **MacBook Pro Intel (x86_64), macOS 15.7.9**. Performance shu qurilmada o'lchanadi.
- Sandbox yo'q, App Store yo'q.
- Barcha foydalanuvchi harakatlari bitta `Command` qatlamidan o'tadi (klaviatura, menyu, tugmalar, drag & drop) — shortcut'lar `KeyBindings` orqali qayta tayinlanadi.
- Core mantiq (state, buyruqlar, keybinding, settings) UI'siz va unit test qilinadigan bo'lishi kerak.

## Build va test

Talab: to'liq Xcode (Command Line Tools'da `Testing` moduli yo'q). Barcha buyruqlar repo ildizidan:

- Core/FileSystem testlari: `swift test --package-path Packages/CommanderKit`
- Bitta suite: `swift test --package-path Packages/CommanderKit --filter <SuiteName>`
- Benchmark: `CK_BENCHMARK=1 swift test --package-path Packages/CommanderKit -c release --filter DirectoryReaderBenchmark`
- Faqat kompilyatsiya (Xcode'siz ham ishlaydi): `swift build --package-path Packages/CommanderKit`

- Controller testlari: `swift test --package-path Packages/CommanderKit --filter <Suite>` (CommanderController ham shu package'da)
- Xcode loyihasini generatsiya qilish: `xcodegen generate`
- App build: `xcodebuild -project Commander.xcodeproj -scheme Commander -destination 'generic/platform=macOS' build`
- UI smoke testlar: `xcodebuild test -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64'` (birinchi marta macOS UI automation uchun Touch ID / parol so'raydi)
- O'rnatiladigan DMG (Universal: Apple silicon + Intel, Release): `scripts/make-dmg.sh` → `build/Commander.dmg`. Developer ID yo'q — "Apple could not verify…" ogohlantirishi chiqadi; birinchi ochish: System Settings → Privacy & Security → **Open Anyway** (macOS 15 da o'ng tugma → Open endi ishlamaydi) yoki `xattr -dr com.apple.quarantine /Applications/Commander.app`.
- Ilova ikonkasi: `swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset` (kod bilan chiziladi).
- Eslatma: ad-hoc imzo har build'da o'zgaradi — Full Disk Access ruxsatini qayta berish kerak bo'lishi mumkin.
