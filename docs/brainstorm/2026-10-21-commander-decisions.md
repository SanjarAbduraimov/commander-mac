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

> **Tasdiqlandi (B varianti):** oddiy copy / move / new folder / rename / Trash / drag & drop 1-bosqichga kiradi — fonda, oddiy progress, oddiy **Cancel** (har fayldan keyin tekshiriladi), konfliktda Replace / Skip / Keep both. Navbat, pause, batafsil konflikt dialogi, undo — 2-bosqichda.

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

### 1-bo'lim: Arxitektura — **tasdiqlandi**
- macOS 15.0+, x86_64 (universal ixtiyoriy). Sandbox yo'q, App Store yo'q. Full Disk Access tavsiya.
- Modullar:
  - **Core** (sof Swift, UI'siz): `FileItem`, `PaneState` (path, tarix, kursor, belgilanganlar, saralash), `Command` enum, `KeyBindings`, `Settings`.
  - **FileSystem**: papka o'qish, FSEvents kuzatish, fayl amallari, ulangan disklar/SMB (`/Volumes`). Core'ga bog'liq.
    - `FileOperation`: copy/move/trash fonda; progress va cancel Core'dagi `OperationState` orqali UI'ga beriladi (UI'siz test qilinadi).
  - **UI** (AppKit): main window, sidebar, 2× `PaneViewController` (tablar, path field, jadval, status), selection bar.
  - **SettingsUI** (SwiftUI): Appearance / Behavior / Shortcuts.
- Har bir harakat bitta `Command` orqali: klaviatura, kontekst menyu, tugmalar, drag & drop bir xil kodni chaqiradi → shortcut remap = `KeyBindings` jadvalini o'zgartirish; Core UI'siz unit test qilinadi.
- Klaviatura oqimi: event → fokus konteksti (jadval / matn maydoni) → `KeyBindings` → `Command` → `PaneState` → jadval yangilanadi.

### 2-bo'lim: Panel/tab modeli, klaviatura + mouse — **tasdiqlandi**
- `WindowState` (chap/o'ng panel, faol panel) → `PaneState` (tablar, faol tab) → `TabState` (`path`, back/forward tarix, kursor — nom bo'yicha, belgilanganlar — nomlar to'plami, saralash; papkalar doim yuqorida).
- `..` qatori **yo'q** — yuqoriga `⌫` va path field orqali.
- Buyruqlar belgilanganlarga, bo'lmasa kursordagi faylga ishlaydi.
- Boshqa papkaga o'tganda belgilar tozalanadi; `⌫` bilan chiqqanda kursor chiqilgan papkada turadi.
- FSEvents yangilanishida kursor va belgilar nom bo'yicha saqlanadi; fayl yo'qolsa kursor qo'shni qatorga.
- Harf terish → shu nom bilan boshlanuvchi faylga sakrash (type-ahead).
- Tablar: `⌘T` yangi (joriy papkada), `⌘W` yopish (oxirgisi yopilmaydi), `⌃Tab` / `⌃⇧Tab`. Qayta ochilganda tablar tiklanadi (Settings'da o'chiriladi).
- Belgilash: `Space`; `⇧↑ / ⇧↓` yurib belgilaydi; `⇧`+click — kursordan bosilgan qatorgacha diapazon; `⌘`+click — bitta qatorni yoqish/o'chirish.
- Click — kursor qo'yadi. O'ng tugma: belgilangan fayl ustida → menyu belgilanganlarga; belgilanmagan ustida → kursor o'sha faylga, menyu faqat unga.
- Panelning istalgan joyiga bosish uni faol qiladi.

### 3-bo'lim: Fayl tizimi — **tasdiqlandi**
- **O'qish**: fonda, kerakli resource key'lar bir yo'la (nom, tur, hajm, sana, yashirin, symlink, package). Maqsad: Intel Mac'da 5 000 faylli papka ≤100 ms. Yashirin fayllar default yashirin, `⌘⇧.` bilan ko'rsatiladi. Package'lar (`.app`) fayl sifatida; kontekst menyuda "Show Package Contents".
- **Kuzatish**: har panelning faol tabi FSEvents bilan, 150 ms debounce, keyin qayta o'qish. SMB'da panel fokusga qaytganda yangilanadi; `⌘R` — qo'lda yangilash.
- **Amallar (`FileOperation`)**: copy — o'z daraxt yurgichi, har fayldan keyin cancel tekshiriladi; cancel'da chala fayl o'chiriladi, tayyorlari qoladi. Move bir disk ichida — rename; boshqa diskka — copy, hammasi muvaffaqiyatli bo'lgach asl o'chiriladi. Trash — `trashItem`; Trash bo'lmasa qaytarilmas o'chirish tasdig'i. Konflikt: Replace / Skip / Keep both + "Apply to all". Bir nechta amal parallel; progress (fayl soni, bayt) va Cancel footer'da.
- **Xatolar**: ruxsat yo'q / fayl band → Retry / Skip / Cancel all. Joriy papka yo'qolsa (disk chiqarilgan) → eng yaqin mavjud ota papkaga. Full Disk Access yo'q → panelda banner, System Settings'ni ochuvchi tugma.

### 4-bo'lim: Settings saqlash — **tasdiqlandi**
- `~/Library/Application Support/Commander/`: `settings.json` (Appearance, Behavior, Shortcuts) va `session.json` (tablar, papkalar, faol panel, sidebar kengligi). Oyna frame — `NSWindow` autosave.
- JSON + `Codable`, Core'da, UI'siz test qilinadi.
- Shortcut'lar: faylga faqat foydalanuvchi o'zgartirganlari yoziladi; default'lar kodda (yangi default'lar avtomatik qo'shiladi).
- Har o'zgarishda 0,5 s debounce bilan atomik yozish. Fayl faqat ishga tushishda o'qiladi.
- `"version": 1`; eski versiya → ketma-ket migratsiya. Noma'lum kalit e'tiborsiz, yetishmagani default. Buzilgan fayl → `settings.broken-<sana>.json` ga saqlanadi, default bilan ochiladi, bir marta ogohlantiriladi.

### 5-bo'lim: Testlash — **tasdiqlandi**
- Core va FileSystem — **local Swift Package** (`swift test` bilan Xcode'siz ishlaydi; package AppKit'ni import qilmaydi). AppKit UI — Xcode app target.
- Core unit testlar (TDD): `PaneState` (kursor, belgilash, `⇧↑/⇧↓`, tarix, `⌫` dan keyingi kursor, FSEvents yangilanishi), `KeyBindings` (tugma → `Command`, matn maydoni konteksti, to'qnashuv, override + default), `Settings` (o'qish/yozish, migratsiya, buzilgan fayl, noma'lum/yetishmagan kalitlar).
- FileSystem integratsion testlar vaqtinchalik papkada: copy, move (bir disk / boshqa disk), cancel, konflikt, Retry/Skip. Trash protokol orqali, testda fake.
- XCUITest — bir necha smoke test: ochilish, `Tab`, `⌫`, vaqtinchalik papkada `F5`.
- Performance (Intel Mac): 5 000 faylli papka ≤100 ms (avtomatik benchmark); cold start ≤1 s va bo'sh holatda RAM ≤100 MB (Instruments bilan qo'lda).

## Ochiq savollar
- Spec tasdiqlandi: `docs/superpowers/specs/2026-10-21-phase1-core-design.md` (endi asosiy manba shu).
- Plan A (CommanderKit) bajarildi va `main` ga merge qilindi (2026-10-22, 122 test, Xcode 26.3). Yakuniy review'dagi Critical/Important topilmalar tuzatildi.
- Hal qilindi (A): boshqa diskka move'da Cancel — to'liq nusxalangan manbalar o'chiriladi (Finder kabi); spec yangilandi.
- Plan B (App UI) bajarildi (2026-10-23, `phase1b-app-ui` branch'ida): CommanderController (244 test) + AppKit ilova, 11 XCUITest smoke. SMB ulanish — NetFS orqali (`NSWorkspace.open` mount nuqtasini qaytarmaydi). Cold start ~1,05 s (maqsad 1 s) — alohida optimizatsiya taski.
- 1C (foydalanuvchi fikrlari) bajarildi (2026-10-24, `phase1c-feedback` branch'ida): Esc — Unmark All, Copy To…/Move To… dialogi (New Folder, Recent/Tabs/Favorites), yashirin fayllar xira, drag & drop manzilini ko'rsatish + spring-loading (qatorlar, "↑ Enclosing folder", breadcrumbs, tablar), On launch papkalari, bitta panel rejimi (`⌘\`), `⇧⌘⌫` butunlay o'chirish, Calculate Size. "Calculate folder size" 3-bosqichdan 1C ga ko'chdi; uning default tugmasi `⌥⇧↩` (`⌥Space` ni Raycast global ushlaydi).
- Qo'shimcha: ilova ikonkasi va o'rnatiladigan Universal DMG (`scripts/make-dmg.sh`).
- 1B+1C foydalanuvchi tomonidan sinaldi va `main` ga merge qilindi (2026-10-24; `swift test` 289, XCUITest 18).
- 1C review'dan qolgan mayda kamchiliklar (keyinroq): bitta panelda footer'da "Tab Switch pane" ko'rinadi; Copy To'da nisbiy yo'l `/` ga nisbatan olinadi; "Create & Copy" manba ichida bo'sh papka qoldirishi mumkin; "↑ Enclosing folder" ustida ushlab turish ketma-ket yuqoriga chiqadi va `/` da chiziq qoladi; bir panelda hajm hisobi ikkinchisidagini to'xtatadi; Settings ochiqligida ⌘\ toggle'ni yangilamaydi; uzun yo'lda breadcrumbs spring-loading zanjir bo'lishi mumkin; bitta panelda Tab iste'mol qilinmaydi.
- 1D bajarildi (2026-10-24, `phase1d-cut-reveal-columns`): ⌘X cut belgisi (✂ + kursiv accent), Finder Services / Dock / `open -a` orqali "Reveal in Commander" (3-bosqichdan 1D ga ko'chdi; faol panelda yangi tab), bitta panelda divider chizig'i tuzatildi, boshqariladigan ustunlar (Name, Ext, Size, Modified, Created, Kind — sarlavhada o'ng tugma, sudrash, saralash), Copy To ichida klaviatura bilan ishlaydigan papka brauzeri.
- 1E (keyingi): Multi-Rename Tool (TC kabi), belgilangan elementlar uchun kengaytirilgan kontekst menyu. Finder "Use Groups" uslubidagi guruhlash — ixtiyoriy.
- Keyin: 2-bosqich (fayl operatsiyalari) spec'i.

### Asboblar — **tasdiqlandi**
- 2026-10-21 holati: Xcode o'rnatilmagan, faqat Command Line Tools (Swift 6.2.1, x86_64), XcodeGen yo'q.
- Xcode'ni foydalanuvchi o'zi App Store'dan o'rnatadi. Loyiha formati — **XcodeGen `project.yml`** (`.xcodeproj` generatsiya qilinadi, git'ga kirmaydi). XcodeGen plan tasdiqlangach o'rnatiladi.
