# Commander for Mac — 1-bosqich C (foydalanuvchi fikrlari) dizayni

Sana: 2026-10-23. Holat: **tasdiqlash kutilmoqda**. Asos: `docs/superpowers/specs/2026-10-21-phase1-core-design.md` (1-bosqich spec'i). Bu hujjat o'sha spec'ni to'ldiradi; ziddiyat bo'lsa shu hujjat ustun.
Implementation plan: `docs/superpowers/plans/2026-10-23-phase1c-feedback.md`.

## 1. Maqsad

1B ilovasini qo'lda sinashdan keyingi 7 ta talab. Muvaffaqiyat: quyidagi har bir xatti-harakat ishlaydi, mavjud 1B xatti-harakatlari (⌘A, ⌘⌫, F5/F6 darhol) o'zgarmaydi.

## 2. Kelishilgan qarorlar

### 2.1 Belgilarni olib tashlash
- `⌘A` (Mark All) — o'zgarmaydi.
- Yangi buyruq **Unmark All**, default tugma **`Esc`** (jadval fokusda). Matn maydonida `Esc` avvalgidek tahrirni bekor qiladi.
- Selection bar'da **Clear** tugmasi → Unmark All.

### 2.2 Copy To… / Move To…
- `F5`/`F6` — avvalgidek darhol boshqa panelga. Behavior'dagi "Ask for destination" yoqilgan bo'lsa F5/F6 ham shu dialogni ochadi.
- Yangi buyruqlar **Copy To…** `⌥F5` va **Move To…** `⌥F6` (kontekst menyu va File menyuda ham).
- Dialog (sheet): path maydoni (papka nomlari bo'yicha autocomplete), **Choose…** (NSOpenPanel, faqat papka), **New Folder** (tanlangan manzil ichida "untitled folder" yaratadi va uni manzil qiladi), ro'yxatlar: **Recent** (oxirgi 10 manzil), **Tabs** (ikkala paneldagi barcha tablar papkalari, takrorsiz), **Favorites**.
- Kiritilgan papka yo'q bo'lsa: "Folder “X” doesn't exist. Create it and copy/move there?" → **Create & Copy/Move** / Cancel. Yaratish oraliq papkalari bilan.
- Amal boshlangach manzil Recent ro'yxatiga yoziladi (`session.json`, eng yangisi birinchi, takrorsiz, 10 ta).

### 2.3 Yashirin fayllar
- Yashirin element (`isHidden`) ko'rsatilganda nomi va ikonkasi **50% shaffof** (Finder kabi).

### 2.4 Drag & drop
- **Manzilni ko'rsatish:** papka qatori ustida — qator accent rangli ramka va fon bilan; panelning o'ziga tushganda — butun jadval atrofida accent ramka.
- **Spring-loading:** sudrab papka qatori, tab yoki breadcrumb segmenti ustida **0,7 s** ushlab turilsa — o'sha papkaga kiriladi (panel faollashadi), drag davom etadi. Drag faqat tugma qo'yib yuborilganda tugaydi; `Esc` yoki ilovadan tashqarida qo'yib yuborish — bekor.
- **Tashqariga chiqish:** drag paytida jadval tepasida **"↑ Enclosing folder"** chizig'i paydo bo'ladi: 0,7 s ushlash → bir pog'ona yuqoriga; ustiga tashlash → ota papkaga. Root'da chiziq ko'rinmaydi.
- **Breadcrumbs:** path qatori segmentlarga bo'linadi (`/ › Users › sanjar › Documents`). Segmentga click → o'sha papka; drag paytida 0,7 s → o'sha papkaga; tashlash → o'sha papkaga. Path qatorining bo'sh joyiga click yoki `⌘L` → avvalgidek tahrirlanadigan matn maydoni (Return/Esc qoidalari o'zgarmaydi).
- **Tablar:** drag tab ustida 0,7 s → o'sha tab faollashadi; tab ustiga tashlash → o'sha tab papkasiga.
- Drop operatsiyasi qoidasi (bir volume — move, boshqa — copy, `⌥` — copy) hamma manzillarga bir xil.
- Spring-loading bilan kirilgan papkada panel qoladi (tarixga yoziladi).

### 2.5 Ishga tushgandagi papkalar
- Settings → Behavior → **On launch**: "Restore last session" (avvalgi `restoreTabsOnLaunch = true`) yoki "Open these folders" — **Left** va **Right** uchun papka (Choose… bilan; bo'sh = Home). Papka yo'q bo'lsa — eng yaqin mavjud ota papka.

### 2.6 Bitta panel rejimi
- View → **Single Pane** (`⌘\`, Settings → Appearance'da ham). Holat `session.json` da saqlanadi.
- Bitta panelda: faqat chap panel ko'rinadi va faol; `Tab` ishlamaydi; F5/F6 → Copy To…/Move To… dialogi (default manzil — oxirgi Recent yoki joriy papka); "Copy/Move to Other Pane" menyu bandlari "Copy To…/Move To…" kabi ishlaydi.

### 2.7 Butunlay o'chirish
- `⌘⌫` — avvalgidek Trash.
- Yangi buyruq **Delete Immediately…**, default **`⇧⌘⌫`**: tasdiq dialogi "Delete “N” immediately? You can't undo this action." (bir nechta bo'lsa "Delete N items immediately?" + birinchi 5 nom), tugmalar **Delete** (destructive) / **Cancel** (default, Esc). Tasdiqlansa — fonda, progress va Cancel bilan (mavjud `DeleteOperation`).

### 2.8 Papka hajmi
- Yangi buyruq **Calculate Size**, default **`⌥Space`** (menyu, kontekst menyu, selection bar'da **Size** tugmasi).
- Belgilangan papkalar (belgilangan bo'lmasa — kursordagi papka) uchun fonda hisoblanadi; symlink'lar kuzatilmaydi; package'lar ham papka kabi hisoblanadi.
- Footer'da "Calculating size… 2 of 5 folders" + **Cancel**; belgilash va navigatsiya to'xtamaydi.
- Natija Size ustunida va status qatorida (belgilangan papkalar hajmi qo'shiladi). Natija papka yo'li bo'yicha eslab qolinadi; `⌘R` yoki shu panelda boshqa papkaga o'tish o'sha panel natijalarini tozalaydi.

## 3. Doiradan tashqari
- Get Info, Compare, Quick Look — 3-bosqichda qoladi (spec'dagi jadval: "Calculate folder size" 1C ga ko'chdi).
- Spring-loading Finder va sidebar'ga — yo'q (faqat panel ichida: qatorlar, chiziq, breadcrumbs, tablar).
