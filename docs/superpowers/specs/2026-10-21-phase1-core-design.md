# Commander for Mac — 1-bosqich (yadro) dizayni

Sana: 2026-10-21. Holat: **foydalanuvchi ko'rib chiqishi kutilmoqda.**
Manba: `docs/brainstorm/2026-10-21-commander-decisions.md` (bu spec tasdiqlangach asosiy manba shu fayl bo'ladi).
Dizayn maketi: `docs/design/prototype/index.html`, layout **A · Native balance**.

## 1. Maqsad va muvaffaqiyat mezoni

Total Commander uslubidagi ikki panelli, klaviatura bilan tez ishlaydigan, yengil macOS file manager — muallifning shaxsiy vositasi (App Store, litsenziya, tarqatish yo'q).

1-bosqich tugadi deyiladi, agar:
- Finder'ni kundalik local fayl ishlarida (ko'rish, navigatsiya, copy/move/rename/Trash, SMB disklar) almashtira olsa;
- quyidagi barcha klaviatura va mouse qoidalari ishlasa;
- 10-bo'limdagi performance maqsadlari MacBook Pro Intel, macOS 15.7.9 da bajarilsa.

## 2. Doira

### 1-bosqichga kiradi
- Bitta oyna: Places sidebar + 2 panel (har birida tablar) + selection bar + shortcut footer.
- Local fayllar va `/Volumes` ga ulangan disklar, jumladan SMB (macOS tomonidan mount qilingan oddiy papka sifatida).
- Navigatsiya, tablar, belgilash, saralash, yashirin fayllar, type-ahead.
- Oddiy fayl amallari: copy, move, new folder, rename, duplicate, Move to Trash, drag & drop — fonda, oddiy progress, **Cancel**, konfliktda Replace / Skip / Keep both.
- Kontekst menyu (2.1), Settings (Appearance, Behavior, Shortcuts), session tiklash.

### 1-bosqichga kirmaydi
| Funksiya | Bosqich |
|---|---|
| Amallar navbati, pause, batafsil konflikt dialogi, fayl amallari undo | 2 |
| Open With ▸, "Always open with", Settings → File associations | 2 |
| `F4` Edit | 2 |
| ZIP Compress / Extract, Quick Look (`F3`, Preview), Share ▸ / Telegram, "Open in Commander" (Services, Finder Sync, `NSFileViewer`) | 3 |
| Get Info, Calculate folder size, Compare (2 fayl) | 3 |
| SFTP / FTP | 4 |

1-bosqichda bu buyruqlar uchun menyu bandi va tugma **ko'rsatilmaydi** (o'chiq holda ham emas).

### 2.1 Kontekst menyu (1-bosqich)
- Fayl/papka ustida: Open · Copy to other pane `F5` · Move to other pane `F6` · Rename `F2` · Duplicate `⌘D` · Move to Trash `⌘⌫` · Copy path · Copy name · Show Package Contents (faqat package'larda) · Reveal in Finder · Open in Terminal.
- Bo'sh joyda: New Folder `F7` · Paste `⌘V` · Show/Hide hidden files `⌘⇧.` · Open in Terminal.

## 3. Arxitektura

- Swift 6, macOS 15.0+, x86_64 (universal ixtiyoriy). Sandbox yo'q. Full Disk Access tavsiya qilinadi.
- **AppKit asosiy** (oyna, sidebar, panellar, `NSTableView`, fokus, klaviatura, menyu, drag & drop, inline rename). **SwiftUI faqat Settings va kichik dialoglar** (`NSHostingController`).

### Modullar
| Modul | Tur | Vazifa | Bog'liqlik |
|---|---|---|---|
| **Core** | local Swift Package | `FileItem`, `WindowState` / `PaneState` / `TabState`, `Command`, `KeyBindings`, `Settings`, `OperationState` | faqat Foundation |
| **FileSystem** | local Swift Package | papka o'qish, FSEvents, `FileOperation`, volume'lar | Core |
| **App (UI)** | Xcode app target | main window, sidebar, `PaneViewController` (tablar, path field, jadval, status), selection bar, footer, dialoglar | Core, FileSystem |
| **SettingsUI** | App target ichida, SwiftUI | Appearance / Behavior / Shortcuts | Core |

- Core va FileSystem AppKit'ni import qilmaydi — buni package chegarasi kafolatlaydi.
- **Bitta `Command` qatlami**: klaviatura, menyu, selection bar tugmalari va drag & drop bir xil `Command` ni yuboradi. Shortcut remap = `KeyBindings` jadvalini o'zgartirish.
- Klaviatura oqimi: `NSEvent` → fokus konteksti (`table` / `textField`) → `KeyBindings` → `Command` → `WindowState` o'zgaradi → UI yangilanadi.
- Fayl amallari oqimi: `Command` → `FileOperation` (fonda) → `OperationState` (progress, konflikt, xato) → UI.

## 4. Holat modeli (Core)

- `WindowState`: `left`, `right: PaneState`, `activePane`.
- `PaneState`: `tabs: [TabState]`, `activeTab`.
- `TabState`:
  - `path`, `backHistory`, `forwardHistory`;
  - `cursor` — fayl **nomi** bo'yicha (indeks emas);
  - `marked: Set<String>` — nomlar, kursordan alohida;
  - `sort` — ustun (Name / Size / Modified) va yo'nalish; papkalar doim yuqorida;
  - `showHidden` — default `false`.
- `FileItem`: nom, URL, tur (fayl / papka / symlink / package), hajm, o'zgartirilgan sana, yashirinlik.

### Qoidalar
- Buyruqlar **belgilanganlarga** ishlaydi; hech narsa belgilanmagan bo'lsa — kursordagi faylga.
- Boshqa papkaga o'tilganda `marked` tozalanadi.
- `⌫` bilan yuqoriga chiqilganda kursor chiqilgan papka nomida turadi.
- Papka qayta o'qilganda kursor va `marked` nom bo'yicha saqlanadi; yo'qolgan nomlar `marked` dan olib tashlanadi; kursordagi fayl yo'qolsa kursor o'sha indeksdagi (bo'lmasa oxirgi) qatorga o'tadi.
- `..` qatori **yo'q**.
- Type-ahead: jadval fokusda bo'lganda harf/raqam terish kursorni shu prefiks bilan boshlanuvchi birinchi faylga o'tkazadi (katta-kichik harf farqsiz); 1 s pauzadan keyin prefiks yangidan boshlanadi. `Space` type-ahead'ga kirmaydi.

## 5. Klaviatura (default `KeyBindings`)

Barcha tugmalar Settings → Shortcuts'da qayta tayinlanadi. Quyidagilar fokus **jadvalda** bo'lganda ishlaydi.

| Tugma | Buyruq |
|---|---|
| `↑ / ↓`, `Home / End`, `PgUp / PgDn` | Kursorni yurgizish; belgilar saqlanadi |
| `⇧↑ / ⇧↓` | Yurib belgilash (o'tilgan qatorlar belgilanadi) |
| `Space` | Kursordagini belgilash/olib tashlash va keyingi qatorga o'tish |
| `⌘A` | Hammasini belgilash |
| `Return`, `⌘↓` | Papka → ichiga kirish; fayl → default ilovada ochish |
| `⌫`, `⌘↑` | Bir pog'ona yuqoriga |
| `⌘[` / `⌘]` | Tarix: orqaga / oldinga |
| `Tab` | Faol panelni almashtirish |
| `⌘T` / `⌘W` | Yangi tab (joriy papkada) / tabni yopish (oxirgi tab yopilmaydi) |
| `⌃Tab` / `⌃⇧Tab` | Keyingi / oldingi tab |
| `⌘L` | Path field'ga fokus |
| `⌘R` | Panelni qayta o'qish |
| `⌘⇧.` | Yashirin fayllarni ko'rsatish/yashirish |
| `⌘C` / `⌘X` / `⌘V` | Fayllarni clipboard'ga copy / cut, joriy papkaga paste |
| `⌘D` | Duplicate |
| `F5` / `F6` | Boshqa panelning joriy papkasiga copy / move — **darhol** |
| `F7` | New folder: "untitled folder" yaratiladi va darhol inline rename |
| `F2`, `⇧F6` | Inline rename |
| `⌘⌫`, `Fn+⌫` (`⌦`) | Belgilanganlarni (yoki kursordagini) Trash'ga |
| `⌘K` | Connect to Server (SMB manzil oynasi) |
| `⌘,` | Settings |

- Fokus **matn maydonida** (path field, rename) bo'lganda bu tugmalar matnni tahrirlaydi; papkadan chiqish, fayl o'chirish kabi buyruqlar ishlamaydi.
- `Esc` — matn maydonidan jadvalga qaytish (rename bekor qilinadi). Path field'da `Return` — shu manzilga o'tish.
- `⌘Z` 1-bosqichda faqat matn maydonlarida ishlaydi (fayl amallari undo — 2-bosqich).

## 6. Mouse va drag & drop

- Click — kursorni qo'yadi (belgilarni o'zgartirmaydi). Panelning istalgan joyiga bosish uni faol qiladi.
- `⌘`+click — bitta qatorni belgilash/olib tashlash. `⇧`+click — kursordan bosilgan qatorgacha belgilash.
- Double-click: papka → ichiga; fayl → default ilovada ochish.
- Kursordagi fayl nomiga pauzadan keyin yana bir click → inline rename (double-click oralig'idan uzoqroq pauza).
- Ustun sarlavhasiga click — shu ustun bo'yicha saralash; qayta click — yo'nalishni almashtirish.
- O'ng tugma: belgilangan fayl ustida → menyu barcha belgilanganlarga; belgilanmagan fayl ustida → kursor o'sha faylga o'tadi, menyu faqat unga.
- Drag & drop: panellar orasida, Finder, Dock va boshqa ilovalar bilan ikki tomonlama. Default — Finder qoidasi: bir volume ichida move, boshqa volume'ga copy; `⌥` bilan — doim copy. Sidebar Favorites'ga papka tashlash uni Favorites'ga qo'shadi.

## 7. Oyna tarkibi

- **Places sidebar**:
  - Favorites — default: Home, Desktop, Documents, Downloads, Applications; drag bilan qo'shish, o'ng tugma → Remove.
  - Locations — ulangan disklar (`/Volumes`) va SMB ulanishlar; eject tugmasi; har birida bo'sh joy.
  - Sidebar bandiga click faol panelning joriy tabini o'sha papkaga o'tkazadi.
- **Panel**: tablar qatori, path field, jadval (Name / Size / Modified), status qatori ("N ta element, M ta belgilangan, X MB").
- **Selection bar** (belgilanganlar bo'lganda): Copy, Move, Trash.
- **Footer**: asosiy shortcut'lar (`F5 Copy`, `F6 Move`, `F7 New folder`, …) va ishlayotgan amallar progressi + Cancel.
- Kursor va belgilangan qatorlar vizual jihatdan turlicha (maketdagidek).

### SMB
- `⌘K` → `smb://server/share` kiritiladi → `NSWorkspace` orqali macOS mount qiladi (login oynasi macOS'niki) → `/Volumes/<share>` sidebar'da paydo bo'ladi va faol panelda ochiladi.
- Oxirgi 10 ta manzil `⌘K` oynasida eslab qolinadi.

## 8. Fayl tizimi

### O'qish
- Papka fonda o'qiladi; kerakli resource key'lar bir yo'la prefetch qilinadi (nom, tur, hajm, sana, yashirinlik, symlink, package).
- Package'lar (`.app` va h.k.) fayl sifatida ko'rinadi; ichiga faqat "Show Package Contents" bilan kiriladi.
- Symlink papkaga kirish — maqsad papkaga o'tadi; path field symlink yo'lini ko'rsatadi.

### Kuzatish
- Har panelning **faol** tabi FSEvents bilan kuzatiladi; hodisalar 150 ms debounce'dan keyin papkani qayta o'qishga olib keladi.
- SMB'da tarmoqdagi o'zgarishlar kelmasligi mumkin: panel fokusga qaytganda qayta o'qiladi; `⌘R` — qo'lda.

### `FileOperation`
- **Copy**: o'z rekursiv yurgichi; har fayldan keyin cancel tekshiriladi. Cancel'da chala yozilgan fayl o'chiriladi, tugallanganlari qoladi.
- **Move**: bir volume ichida — rename (darhol). Boshqa volume'ga — copy, hammasi muvaffaqiyatli bo'lgach manbalar o'chiriladi; cancel yoki xatoda manbalar o'chirilmaydi.
- **Trash**: `FileManager.trashItem`. Trash qo'llab-quvvatlanmasa → "Bu fayllar butunlay o'chiriladi, qaytarib bo'lmaydi" tasdig'i.
- **Konflikt**: dialog Replace / Skip / Keep both + "Apply to all". Keep both → `name 2.ext` (Finder uslubi).
- Bir nechta amal **parallel** ishlashi mumkin; har biri footer'da progress (fayl soni, bayt) va Cancel bilan.
- Trash protokol (`Trasher`) orqali ulanadi — testda fake.

### Xatolar
| Holat | Xatti-harakat |
|---|---|
| Ruxsat yo'q / fayl band / disk to'la (amal paytida) | Dialog: Retry / Skip / Cancel all |
| Joriy papka yo'qolgan (o'chirilgan, disk chiqarilgan) | Panel eng yaqin mavjud ota papkaga o'tadi |
| Papka o'qilmaydi (Full Disk Access yo'q) | Panel ichida banner + System Settings → Privacy'ni ochuvchi tugma |
| SMB mount muvaffaqiyatsiz | macOS xato matni bilan alert |

## 9. Settings va session

- Joy: `~/Library/Application Support/Commander/`.
  - `settings.json` — Appearance, Behavior, Shortcuts.
  - `session.json` — tablar va ularning papkalari, faol panel/tab, sidebar kengligi, Favorites, `⌘K` tarixi.
  - Oyna frame — `NSWindow` autosave.
- JSON + `Codable`, Core'da.
- Shortcuts: faylga faqat foydalanuvchi **override**'lari yoziladi; default'lar kodda.
- O'zgarish → 0,5 s debounce → atomik yozish. Fayllar faqat ishga tushishda o'qiladi.
- `"version": 1`; eski versiya → ketma-ket migratsiya. Noma'lum kalit e'tiborsiz; yetishmagani — default. Buzilgan fayl → `<nom>.broken-<sana>.json` ga ko'chiriladi, default'lar bilan ochiladi, bir marta ogohlantiriladi.

### Settings oynasi
- **Appearance**: theme (Light / Dark / System), fayl nomi shrifti va o'lchami, ikonka o'lchami, qator balandligi — darhol preview.
- **Behavior** (default — yuqoridagi qoidalar):
  - `⌫` = parent papka / history back;
  - `Space` = belgilab keyingi qatorga o'tish / joyida qolish;
  - `F5`/`F6` = darhol / manzilni so'rash;
  - `Fn+⌫` (`⌦`) Trash'ga — yoqilgan / o'chirilgan;
  - yashirin fayllarning default holati;
  - ishga tushganda tablarni tiklash — yoqilgan / o'chirilgan.
- **Shortcuts**: buyruqlar ro'yxati, qidiruv, qayta tayinlash, to'qnashuvni saqlashdan oldin ko'rsatish, Restore defaults.

## 10. Testlash

- **Core unit testlar (TDD)**: `TabState`/`PaneState` (kursor, belgilash, `⇧↑/⇧↓`, tarix, `⌫` dan keyingi kursor, qayta o'qishdan keyin kursor va belgilar, type-ahead), `KeyBindings` (tugma → `Command`, fokus konteksti, to'qnashuv, override + default), `Settings` (o'qish/yozish, migratsiya, buzilgan fayl, noma'lum/yetishmagan kalitlar).
- **FileSystem integratsion testlar** — vaqtinchalik papkada: copy, move (bir volume; boshqa volume — vaqtinchalik disk image bilan), cancel, konflikt, Retry/Skip, fake `Trasher`.
- **XCUITest smoke**: ilova ochilishi, `Tab`, `⌫`, vaqtinchalik papkada `F5`.
- **Performance** (MacBook Pro Intel, macOS 15.7.9):
  - 5 000 faylli papkani o'qish va ko'rsatish ≤ 100 ms — avtomatik benchmark test;
  - cold start ≤ 1 s, bo'sh holatda RAM ≤ 100 MB — Instruments bilan qo'lda.

## 11. Loyiha va asboblar

- Xcode — foydalanuvchi App Store'dan o'rnatadi (2026-10-21 holatida faqat Command Line Tools, Swift 6.2.1).
- Loyiha — **XcodeGen `project.yml`**; `.xcodeproj` generatsiya qilinadi va `.gitignore` ga kiradi. XcodeGen plan tasdiqlangach o'rnatiladi.
- Tuzilma (taxminiy, plan'da aniqlashtiriladi):
  ```
  project.yml
  Packages/CommanderKit/      # Core + FileSystem target'lari, Tests/
  App/                        # AppKit UI, SettingsUI, Info.plist
  AppUITests/
  ```
- Build/test buyruqlari loyiha yaratilganda `AGENTS.md` → "Build va test" bo'limiga yoziladi.
