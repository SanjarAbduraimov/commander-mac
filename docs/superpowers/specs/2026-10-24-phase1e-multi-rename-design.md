# Commander for Mac — 1-bosqich E (Multi-Rename, belgilash vositalari) dizayni

Sana: 2026-10-24. Holat: **tasdiqlandi** (foydalanuvchi: "ha bos"). Asos: 1-bosqich spec'i va 1C/1D spec'lari; ziddiyat bo'lsa shu hujjat ustun.
Implementation plan: `docs/superpowers/plans/2026-10-24-phase1e-multi-rename.md`. Kontekst menyu kengaytmasi — 1F (alohida spec).

## 1. Maqsad

Total Commander'ning Multi-Rename Tool'i va belgilash vositalari (Num+ / Num− / Num*). Muvaffaqiyat: quyidagi har bir xatti-harakat ishlaydi, 1A–1D o'zgarmaydi.

## 2. Kelishilgan qarorlar

### 2.1 Ochish
- **⌃M** — Multi-Rename… (File menyu, kontekst menyu ham). **F2**: bitta element — joyida rename (avvalgidek); bir nechta belgilangan — Multi-Rename.
- Asosiy oyna ustida sheet. Elementlar — targets, paneldagi tartibda.

### 2.2 Shablonlar
- **Nom maskasi** (default `[N]`) va **Ext maskasi** (default `[E]`). Yakuniy nom: `nom` + (ext bo'sh bo'lmasa `.` + ext).
- `[N]` eski nom (kengaytmasiz, `FileItem.baseName`); `[E]` kengaytma (`FileItem.ext`; papkada bo'sh).
- `[Nx]` — x-belgi; `[Nx-y]` — x dan y gacha; `[Nx-]` — x dan oxirigacha (1 dan sanaladi, chegaradan tashqari qism bo'sh).
- `[C]` — hisoblagich: boshlanish (default 1), qadam (1), raqamlar (1 — nol bilan to'ldiriladi).
- `[P]` — ota papka nomi. `[YMD]` (`20261024`), `[Y]`, `[M]`, `[D]`, `[hms]` (`153012`) — o'zgartirilgan sana, mahalliy vaqt.
- Noma'lum `[…]` o'zgarishsiz matn bo'lib qoladi.
- **Qidirish/almashtirish** yakuniy to'liq nomga: oddiy yoki regex (`$1`), katta-kichik harf sezgir/sezgir emas; bo'sh qidiruv — o'tkazib yuboriladi.
- **Harf:** Unchanged / lowercase / UPPERCASE / First letter (birinchi harf katta, qolgani o'zgarmaydi) / Title Case — almashtirishdan keyin.

### 2.3 Oldindan ko'rish va bajarish
- Jadval: eski → yangi; o'zgarmaganlar xira; muammolilar qizil va sababi bilan: bo'sh nom, `/` yoki `:`, papkada shu nomli boshqa element bor (to'plamdan tashqari, yashirinlari ham), to'plam ichida takror (katta-kichik harfsiz), noto'g'ri regex. Birorta muammo bo'lsa — **Rename** o'chiq.
- Bajarish fonda: avval o'zgaradiganlar vaqtinchalik nomlarga, keyin yakuniy nomlarga (almashinuv zanjirlari a→b, b→a ishlaydi). Xatoda — qilinganlar orqaga, xabar.
- **Undo:** oxirgi Multi-Rename — dialogdagi "Undo Last" va Edit → Undo Multi-Rename; faqat ilova yopilguncha. Joyida bo'lmagan fayllar o'tkazib yuboriladi va xabarda sanaladi.

### 2.4 Belgilash vositalari
- **Mark by Pattern… (⌘=)**, **Unmark by Pattern… (⌘−)**: shablon `*.jpg;*.png` (`;`, `,` yoki bo'sh joy bilan ajratiladi), `*` va `?`, katta-kichik harf farqsiz; ko'rinadigan elementlarga. Oxirgi 10 shablon eslab qolinadi (`session.json`).
- **Invert Marks (⌘⇧I)**, **Mark Same Extension (⌥⌘=)** — kursordagi kengaytma (kengaytmasizlar — kengaytmasizlarni).
- Hammasi Edit menyusida; Settings → Shortcuts'da qayta tayinlanadi.

## 3. Doiradan tashqari (1F va keyin)
- Kontekst menyu: Cut/Copy/Paste, New File, Alias/Symlink, ZIP, Open With, Quick Look, Get Info, Share, teglar — 1F.
- Presetlar, EXIF/ID3 maydonlari, papkalar ichiga rekursiv rename.
