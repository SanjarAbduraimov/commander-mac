# Commander for Mac — 1-bosqich F (Kengaytirilgan kontekst menyu, In-App sozlamalar, Rasm Paste va Modern UI) dizayni

Sana: 2026-11-13. Holat: **loyihalashtirildi**. Asos: 1-bosqich yadro spec'i va 1C/1D/1E spec'lari; ziddiyat bo'lsa shu hujjat ustun.
Interaktiv dizayn prototipi: `docs/design/prototype/v2/index.html`.

---

## 1. Maqsad

Foydalanuvchi tajribasini (UX) zamonaviy macOS 15 darajasiga olib chiqish, mavjud kamchiliklarni bartaraf etish va 1F bosqichining barcha rejalashtirilgan funksiyalarini to'liq tatbiq etish. Muvaffaqiyat mezoni: barcha avvalgi 1A–1E testlari (343 unit test) buzilmaydi, yangi xatti-harakatlar to'liq unit va UI testlar bilan qoplanadi.

---

## 2. Kelishilgan qarorlar

### 2.1 In-App Modal Settings (Ichki sozlamalar varag'i)
- **Ochish:** `⌘,` yoki Titlebar'dagi sozlamalar tugmasi orqali. Alohida suzuvchi `NSWindow` emas, balki asosiy oyna ustida orqa fonni xiralashtiruvchi silliq in-window sheet/modal sifatida ochiladi.
- **Yopish:** `Esc`, modal tashqarisiga (backdrop) chertish yoki "✕" tugmasi orqali bir zumda yopiladi.
- **Avvalgi barcha sozlamalar 100% saqlanadi:**
  - **Behavior:** `backspaceAction` (parent vs historyBack), `spaceAdvances` (keyingi qatorga o'tish), `askDestinationForCopyMove` (darhol vs manzil so'rash), `forwardDeleteTrashes` (Fn+⌫ / ⌦ Delete), `showHiddenByDefault`, `restoreTabsOnLaunch` (oxirgi tablar vs boshlang'ich papkalar).
  - **Appearance:** `theme` (system/light/dark), `rowDensity` (24/30/36px), `fontSize`, `fontName`, ustunlar boshqaruvi (`columns`).
  - **Shortcuts:** to'liq klaviatura qayta tayinlash va to'qnashuvlarni oldini olish.
- **Yangi bo'limlar:**
  - **File Associations:** fayl kengaytmasini ochuvchi dasturga bog'lash.
  - **Clipboard & Paste:** rasm qo'yish sozlamalari (avtomatik nomlash formati, PNG/JPG tanlovi, tasdiq so'rovi).
  - **Type-Ahead & Search:** klaviatura qidiruvi xatti-harakatlari.

### 2.2 Telegram uslubidagi Rasm Paste qilish (Clipboard Image Paste)
- Brauzer yoki tizim clipboard'ida rasm nusxalangan holda `⌘V` bosilganda:
  - Telegram kabi silliq preview oynasi ochiladi (rasm ko'rinishi, o'lchami va hajmi).
  - Fayl nomi avtomatik vaqt tamg'asi bilan taklif qilinadi: `Pasted-Image-YYYY-MM-DD_HHmm.png`.
  - Format tanlovi: `.png` (Lossless), `.jpg` (Compressed), `.webp`.
  - <kbd>↩ Enter</kbd> bosilsa — darhol faol panelga fayl qilib yoziladi, <kbd>Esc</kbd> — bekor qilinadi.

### 2.3 Qidirishdagi kamchiliklar yechimi (Smart Type-Ahead)
- **Aylanib o'tish (Cycling matches):** Bir xil harf ketma-ket bosilganda (masalan, `d` → `d` → `d`) shu harf bilan boshlanuvchi barcha elementlar bo'ylab navbatma-navbat o'tiladi.
- **Yashirin fayllar:** Nuqta bilan boshlanuvchi fayllar (`.git`, `.gitignore`, `.env`) harf terilganda (masalan `g`) ham qidiruvga olinadi va kursor sakraydi.
- Qidiruv paytida faol panel burchagida qidiruv ko'rsatkichi (badge) vaqtincha paydo bo'ladi.

### 2.4 Tezkor ko'rish (Quick Look & Quick View)
- <kbd>F3</kbd> yoki <kbd>⌘Y</kbd> orqali chaqiriladi.
- **Shortcut qoidasi:** <kbd>Space</kbd> faqat va faqat fayllarni belgilash (Mark & advance) uchun ishlaydi, Quick Look bilan to'qnashmaydi.
- Quick Look ochiqligida <kbd>↑</kbd> va <kbd>↓</kbd> orqali fayllar orasida to'xtovsiz o'tish mumkin.
- Rasm, matn/kod (syntax highlighting) va PDF fayllar oyna ichida tezkor render qilinadi.

### 2.5 Tasdiq dialoglarida Default Enter
- O'chirish (<kbd>⌘⌫</kbd>) va boshqa tasdiq talab qilinuvchi dialoglarda ijobiy tugma ("Ha, o'chirish" / "Tasdiqlash") asosiy fokusga olinadi.
- Klaviaturada shunchaki **<kbd>↩ Enter</kbd>** bosilishi bilan amal bajariladi; <kbd>Esc</kbd> — bekor qiladi.

### 2.6 Windows File Explorer uslubidagi Yangi papka / fayl yaratish
- Sarlavha panelida **`+ New ▾`** split button (<kbd>F7</kbd> Folder, <kbd>⌘N</kbd> File).
- **Inline yaratish:** Jadvalning eng yuqori qatorida yangi satr ochiladi, nom kiritilib <kbd>↩ Enter</kbd> bosiladi. Papkada to'liq nom tanlanadi, faylda faqat kengaytmagacha bo'lgan qism tanlanadi.

### 2.7 Open With (App Chooser) va Open in Terminal
- **Open in Terminal (<kbd>⌥⌘T</kbd>):** joriy papkada macOS Terminal / iTerm ochiladi.
- **Open With App Chooser (<kbd>⌥↩</kbd>):**
  - Tanlangan fayl turiga mos keluvchi dasturlar ro'yxati chiqadi.
  - `☑ Har doim ushbu turdagi fayllarni shu dasturda ochish` bitta chertish bilan belgilanadi.
  - Commander xotirasida (`settings.json`) saqlanadi, macOS tizimiga ta'sir qilmaydi.
- **Send to Telegram:** tanlangan fayllarni `NSSharingService` orqali Telegram chatlariga yuborish.

### 2.8 UI va Ikonkalarni modernizatsiya qilish (macOS 15 Sequoia Native Polish)
- **SF Symbols 6:** `IconCache` da eski tizim dok-ikonkalari o'rniga zamonaviy rangli SF Symbols ikonkalari (`folder.fill` oranj, `photo.fill` yashil, `doc.text.fill` qizil PDF, `chevron.left.forwardslash` kod).
- **Modern TabBar:** `NSButton(bezelStyle: .recessed)` o'rniga Safari/Finder uslubidagi silliq card/pill tablar.
- **Unified Titlebar:** silliq sarlavha paneli va breadcrumbs.

---

## 3. Doiradan tashqari (Keyingi 2-bosqichda)
- Amallar navbati (File operation queue) va Pause/Resume.
- SFTP/FTP masofaviy protokollar.
- ZIP arxivlarini papka kabi ochib ichiga kirish.
