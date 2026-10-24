# Commander for Mac — 1-bosqich D (cut, Reveal in Commander, ustunlar) dizayni

Sana: 2026-10-24. Holat: **tasdiqlandi** (foydalanuvchi: "Ha yoz va keyin codingni boshla"). Asos: `docs/superpowers/specs/2026-10-21-phase1-core-design.md` va `docs/superpowers/specs/2026-10-23-phase1c-feedback-design.md`; ziddiyat bo'lsa shu hujjat ustun.
Implementation plan: `docs/superpowers/plans/2026-10-24-phase1d-cut-reveal-columns.md`.

## 1. Maqsad

DMG'dan o'rnatib sinashdan keyingi talablar. Muvaffaqiyat: quyidagi har bir xatti-harakat ishlaydi, 1A–1C xatti-harakatlari o'zgarmaydi.

## 2. Kelishilgan qarorlar

### 2.1 Cut (⌘X) belgisi
- Kesilgan element: belgi ustunida **✂** (✓ o'rniga; belgilangan qator foni saqlanadi), nomi **kursiv, accent rangda**. Yashirin bo'lsa 50% xiralik ham qo'llanadi.
- Cut holati: ⌘X → kesilganlar yo'llari eslab qolinadi. Tozalanadi: paste (move) bajarilganda; yangi ⌘C / ⌘X / Copy Path / Copy Name; ilova faollashganda clipboard'da bizning cut yo'q bo'lsa (boshqa ilova yozgan).
- `Esc` cut'ni bekor qilmaydi.

### 2.2 Reveal in Commander
- Finder: o'ng tugma → Quick Actions / Services → **Reveal in Commander** (Info.plist `NSServices`, Finder Sync extension yo'q).
- Dock ikonkasiga fayl/papka tashlash va `open -a Commander <yo'l>` — xuddi shu amal (`CFBundleDocumentTypes`, `LSHandlerRank = None` — hech narsaning default ilovasi bo'lmaydi).
- Natija: Commander oldinga chiqadi, **faol panelda yangi tab**: fayl → uning papkasi, kursor faylda; papka → papkaning o'zi. Bir nechta element bo'lsa — faqat birinchisi. Yo'q yo'l — beep.
- Ilova yopiq bo'lsa, ishga tushgach ochiladi.

### 2.3 Bitta panel
- `⌘\` ishlab turgan oynada bosilganda chap panel butun kenglikni egallaydi, o'rtada chiziq qolmaydi; qaytarilganda panellar teng bo'linadi.

### 2.4 Ustunlar
- Ustunlar: **Name** (doim, birinchi), **Ext**, **Size**, **Modified**, **Created**, **Kind**. Default: Name, Ext, Size, Modified.
- Ext ko'rinsa, Name extension'siz ko'rsatiladi (`report.pdf` → `report` + `pdf`). Papka va symlink-papkada Ext bo'sh; package'da (`Safari.app`) Ext ko'rsatiladi. Nuqta bilan boshlanuvchi nomda (`.env`) extension yo'q.
- Kind — tizimning tur nomi (`PDF document`, `Folder`, `Application`).
- Sarlavhada **o'ng tugma** → ustunlar ro'yxati (✓ bilan yoqish/o'chirish; Name o'chmaydi).
- Ustunni sudrab tartibini, chegarasini sudrab kengligini o'zgartirish; ikkala panelda bir xil, `settings.json` da saqlanadi.
- Sarlavhani bosish — shu ustun bo'yicha saralash, qayta bosish — teskari. Hamma ustun bo'yicha saralanadi; papkalar doim tepada; teng qiymatda nom bo'yicha.

### 2.5 Copy To / Move To — ichki papka brauzeri
- Dialog: yuqorida yo'l maydoni; o'ngda **papka brauzeri** — maydondagi yo'l `/` bilan tugasa o'sha papkaning, aks holda ota papkaning (oxirgi qism prefiks sifatida filtrlanadi) ichidagi papkalar, katta-kichik harf farqsiz; chapda ixcham Recent / Tabs / Favorites.
- Klaviatura (fokus yo'l maydonida): `↑↓` — brauzerda tanlash; `↵` — tanlangan papkaga kirish (tanlov bo'lmasa — Copy/Move); `⌘↵` — doim Copy/Move; maydon `/` bilan tugaganda `⌫` — bir pog'ona yuqoriga; `⌘↑` — yuqoriga; `Esc` — Cancel.
- Sichqoncha: double-click — kirish; bitta click — tanlash.
- New Folder brauzerdagi joriy papkada yaratadi. Choose… qoladi.

## 3. Doiradan tashqari (1E)
- Multi-Rename Tool (TC kabi ommaviy rename).
- Belgilangan elementlar uchun kengaytirilgan kontekst menyu.
- Guruh sarlavhalari (Finder "Use Groups").
