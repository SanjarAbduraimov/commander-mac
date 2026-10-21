# Commander for Mac — brainstorm qarorlari va holati

Sana: 2026-10-21. Manbalar: Codex sessiyasi (`~/.codex/sessions/2026/10/21/rollout-2026-10-21T20-23-52-01a15f0f-...jsonl`, usage limit tufayli to'xtagan) va Claude bilan davomi.

Bu fayl **spec emas**. Bu — brainstorming jarayonida kelishilgan qarorlar. Spec dizayn bo'limlari tasdiqlangandan keyin `docs/superpowers/specs/` ga yoziladi.

## Maqsad

MacBook uchun Total Commander uslubidagi ikki panelli, klaviatura bilan tez ishlaydigan, zamonaviy va yengil file manager. Avval dizayn, keyin native macOS ilova.

## Kelishilgan qarorlar

### Umumiy
- Jarayon: architectural yo'l — savollar → approach → dizayn bo'limlari → yozma spec → implementation plan → kod.
- Kim uchun: **shaxsiy vosita** (App Store, litsenziya, ro'yxatdan o'tish yo'q).
- Foydalanish: **universal** fayl menejeri; Total Commander funksiyalari bo'lsin, lekin doim ko'rinadigan yuqori panel ixcham, ortiqcha tugma va "Register" kabi eslatmalar yo'q.
- Qurilma: **MacBook Pro Intel, macOS 15.7.9**. Yengillik va tezlik shu qurilmada o'lchanadi.
- Tarmoq: SFTP/FTP va SMB kerak (4-bosqichga bo'lingan, pastda).

### Stack
- **Swift. AppKit asosiy**: oyna, sidebar, panellar, `NSTableView` fayl jadvali, fokus, klaviatura, kontekst menyu, drag & drop, rename.
- **SwiftUI faqat Settings va kichik dialoglar** uchun (`NSHostingController` orqali).
- Sabab: klaviatura fokusi (Tab, ⌫, Space, matn maydonlari) ilovaning yuragi; fokusni SwiftUI↔AppKit o'rtasida bo'lishish xato manbai. Codex taklif qilgan "SwiftUI asosiy + AppKit jadval" varianti shu sababdan rad etildi.
- Rad etilgan: Tauri/Electron (yengillik va native integratsiya yomonroq).

### Bosqichlar (har biriga alohida spec → plan → kod)
1. **Yadro**: 2 panel + tablar, Places sidebar, klaviatura, mouse, kontekst menyu, drag & drop, Settings, local fayllar, SMB (macOS `/Volumes` ga oddiy papka sifatida ulaydi).
2. **Fayl operatsiyalari**: amallar navbati, pause/cancel, batafsil konflikt dialogi, undo, Open With + File associations.
3. **Qo'shimchalar**: ZIP qilish/ochish, Quick Look, Share → Telegram, boshqa ilovalardan "Open in Commander".
4. **Tarmoq**: SFTP/FTP.

> **Taklif, hali tasdiqlanmagan:** oddiy copy / move / new folder / rename / Trash / drag & drop 1-bosqichga kiradi (fonda, oddiy progress, konfliktda Replace / Skip / Keep both). Aks holda yadro kundalik ishda yaroqsiz bo'ladi.

### Klaviatura
| Tugma | Vazifa (fayl jadvalida) |
|---|---|
| `⌫` (Backspace / Mac Delete) | Bir pog'ona yuqori papkaga |
| `⌘⌫`, `Fn+⌫`, tashqi `Delete ⌦` | Belgilanganlarni (bo'lmasa kursordagi faylni) Trash'ga |
| `Space` | Belgilash/olib tashlash va keyingi qatorga o'tish |
| `↑ / ↓` | Yurish; belgilar saqlanadi |
| `Tab` | Panelni almashtirish |
| `⌘C / ⌘V / ⌘X / ⌘A / ⌘Z` | Mac standarti |
| `F5 / F6 / F7` | Boshqa panelga copy / move / new folder |
| `Shift+F6`, `F2` | Rename (taklif) |
| `F3 / F4` | Quick Look / Edit (taklif) |

- Matn maydonida (path, qidiruv, rename) bu tugmalar matnni tahrirlaydi — papkadan chiqmaydi, fayl o'chirmaydi.
- Trash bo'lmagan joyda (server, ba'zi disklar) qaytarilmas o'chirishdan oldin tasdiq.
- F5/F6 **darhol** boshlanadi; muammo bo'lsa dialog.

### Mouse
- Double-click: papka → ichiga kiradi; fayl → default ilovada ochiladi.
- Tanlangan fayl nomini pauzadan keyin yana bir marta bosish → rename (Windows/Finder kabi), double-click'dan farqlanadi.
- O'ng tugma: Total Commander uslubidagi kontekst menyu (pastda).
- Drag & drop: panellar orasida, Finder, Dock va boshqa ilovalar bilan; `⌥` bilan sudrash doim nusxalaydi.

### Kontekst menyu (taklif, TC asosida)
Open · Open With ▸ (ilovalar, Other…, Always open with this app) · Quick Look `F3` · Edit `F4` · Copy to other pane `F5` · Move `F6` · Rename · Duplicate · Move to Trash · Compress (ZIP) / Extract · Copy path · Copy name · Share ▸ · Reveal in Finder · Open in Terminal · Get Info · Calculate folder size · Compare (2 fayl)

### Open With
- "Always open with" qoidasi **faqat Commander ichida** saqlanadi (Settings → File associations). macOS tizim default'i o'zgarmaydi.
- Default ilova topilmagan fayl turida ilova tanlash oynasi chiqadi; qolgan holatlarda darhol ochiladi.

### Boshqa ilovalardan "Open in Commander"
- Boshqa ilovalardagi "Show in Finder" doim Finder'ni ochadi — rasmiy almashtirish yo'li yo'q [Likely].
- `NSFileViewer` yashirin sozlamasi (Path Finder ishlatadi) ko'p ilovalarda ishlaydi, hammasida emas [Guessing] — 3-bosqichda tekshiriladi.
- Ishonchli yo'llar: Finder kontekst menyusiga "Open in Commander" (Services yoki Finder Sync extension), Dock ikonkasiga papka tashlash, `open -a Commander <path>`.

### Telegram
- `Share → Telegram` macOS Share orqali; chat tanlash va yuborish Telegram ilovasida.

### Settings
- **Appearance**: theme (Light/Dark/System), fayl nomi shrifti, ikonka o'lchami, qator balandligi — darhol preview.
- **Behavior**: yuqoridagi kelishilgan xatti-harakatlar default; har biri o'zgartiriladi (masalan ⌫ = parent yoki history back; Space'dan keyin o'tish yoki qolish; F5/F6 darhol yoki manzil so'rash; Forward Delete yoqish).
- **Shortcuts**: har bir buyruqni qayta tayinlash, qidiruv, to'qnashuvni oldindan aniqlash, Restore defaults.

### Layout
- **A — Native balance** tanlangan: Places sidebar (Favorites, Connections, disk joyi) + 2 panel (tablar, path field, ustunlar Name/Size/Modified, status) + selection bar (Preview, Copy, Move, Compress, Share) + shortcut footer.
- Kursor va belgilangan fayllar turlicha ko'rinadi.
- Interaktiv maket: `docs/design/prototype/index.html` (brauzerda to'g'ridan-to'g'ri ochiladi, namunaviy fayllar bilan).

## Dizayn bo'limlari (spec uchun)

### 1-bo'lim: Arxitektura — **taqdim etilgan, tasdiq kutilmoqda**
- macOS 15.0+, x86_64 (universal ixtiyoriy). Sandbox yo'q, App Store yo'q. Full Disk Access tavsiya.
- Modullar:
  - **Core** (sof Swift, UI'siz): `FileItem`, `PaneState` (path, tarix, kursor, belgilanganlar, saralash), `Command` enum, `KeyBindings`, `Settings`.
  - **FileSystem**: papka o'qish, FSEvents kuzatish, fayl amallari, ulangan disklar/SMB (`/Volumes`). Core'ga bog'liq.
  - **UI** (AppKit): main window, sidebar, 2× `PaneViewController` (tablar, path field, jadval, status), selection bar.
  - **SettingsUI** (SwiftUI): Appearance / Behavior / Shortcuts.
- Har bir harakat bitta `Command` orqali: klaviatura, kontekst menyu, tugmalar, drag & drop bir xil kodni chaqiradi → shortcut remap = `KeyBindings` jadvalini o'zgartirish; Core UI'siz unit test qilinadi.
- Klaviatura oqimi: event → fokus konteksti (jadval / matn maydoni) → `KeyBindings` → `Command` → `PaneState` → jadval yangilanadi.

### Qolgan bo'limlar (hali taqdim etilmagan)
2. Panel va tablar modeli, klaviatura + mouse xatti-harakatining aniq qoidalari
3. Fayl tizimi: o'qish, kuzatish, amallar, xatolarni boshqarish
4. Settings saqlash (format, joy, migratsiya)
5. Testlash strategiyasi (Core unit testlar, UI testlar, Intel Mac'da performance o'lchovi)

## Ochiq savollar
- Yuqoridagi "1-bosqichga oddiy fayl amallari kiradi" taklifi va 1-bo'lim arxitekturasini tasdiqlash.
- Xcode versiyasi Intel Mac'da (`xcodebuild -version`) va loyiha formati: Xcode `.xcodeproj` yoki XcodeGen `project.yml` (agentlar uchun `.pbxproj`'dan ko'ra xavfsizroq) [Likely].
