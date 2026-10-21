# Commander for Mac

Total Commander uslubidagi ikki panelli, klaviatura bilan tez ishlaydigan, yengil macOS file manager. Muallifning shaxsiy vositasi — App Store, litsenziya yoki tarqatish rejasi yo'q.

## Joriy holat

**Brainstorming bosqichi. Mahsulot kodi hali yo'q.**

- Kelishilgan barcha qarorlar va keyingi qadam: `docs/brainstorm/2026-10-21-commander-decisions.md` — har sessiya boshida shu faylni o'qing.
- Interaktiv dizayn maketi: `docs/design/prototype/index.html` (brauzerda to'g'ridan-to'g'ri ochiladi). Tanlangan layout — **A · Native balance**.
- Keyingi qadam: 1-bosqich (yadro) dizayn bo'limlarini tasdiqlash → spec → implementation plan.

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

Xcode loyihasi hali yaratilmagan. Yaratilganda shu bo'limga aniq build, test va run buyruqlarini qo'shing.
