# Commander for Mac

Total Commander uslubidagi ikki panelli, klaviatura bilan tez ishlaydigan, yengil macOS file manager. Muallifning shaxsiy vositasi — App Store, litsenziya yoki tarqatish rejasi yo'q.

## Joriy holat

**1-bosqich (yadro): A, B (App UI) va C (foydalanuvchi fikrlari) kodi tayyor — B+C `phase1c-feedback` branch'ida (B ustiga qurilgan), qo'lda tekshiruv va `main` ga merge kutilmoqda.**

- Asosiy manba — spec: `docs/superpowers/specs/2026-10-21-phase1-core-design.md`. Brainstorm tarixi va ochiq savollar: `docs/brainstorm/2026-10-21-commander-decisions.md` — har sessiya boshida o'qing.
- Bajarilgan plan'lar: `docs/superpowers/plans/2026-10-21-phase1a-commanderkit.md` (Core + FileSystem), `docs/superpowers/plans/2026-10-22-phase1b-app-ui.md` (CommanderController + `App/`) va `docs/superpowers/plans/2026-10-23-phase1c-feedback.md` (spec: `docs/superpowers/specs/2026-10-23-phase1c-feedback-design.md`). Testlar: `swift test` — 288, XCUITest smoke — 17.
- Interaktiv dizayn maketi: `docs/design/prototype/index.html`. Tanlangan layout — **A · Native balance**.
- O'lchovlar (2026-10-23, MacBook Pro Intel, Release, `sudo purge`siz): bo'sh holatda RAM 63 MB (maqsad ≤100 ✅); 5 000 faylli papkani o'qish — benchmark ≤100 ms ✅; ishga tushish xctrace App Launch bo'yicha `applicationDidFinishLaunching` oxirigacha ~1,04–1,08 s (3 o'lchov, birinchisi 1,53 s) — maqsad ≤1 s dan biroz oshadi, ~0,5 s `applicationDidFinishLaunching` ichida (asosan AppKit oyna qurilishi, sidebar ikonkalari). Optimizatsiya alohida task.
- Keyingi qadam: foydalanuvchi DMG'dan o'rnatib qo'lda sinaydi, so'ng merge; keyin 2-bosqich spec'i.

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
- App build: `xcodebuild -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64' build`
- UI smoke testlar: `xcodebuild test -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64'` (birinchi marta macOS UI automation uchun Touch ID / parol so'raydi)
- O'rnatiladigan DMG (Universal: Apple silicon + Intel, Release): `scripts/make-dmg.sh` → `build/Commander.dmg`. Developer ID yo'q — boshqa Mac'da birinchi ochish: o'ng tugma → Open (yoki `xattr -dr com.apple.quarantine /Applications/Commander.app`).
- Ilova ikonkasi: `swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset` (kod bilan chiziladi).
- Eslatma: ad-hoc imzo har build'da o'zgaradi — Full Disk Access ruxsatini qayta berish kerak bo'lishi mumkin.
