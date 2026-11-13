// ==========================================================================
// Commander for Mac · Prototype v2 JavaScript
// Smart Type-Ahead, Quick Look, Default Confirm Enter, Open in Terminal
// ==========================================================================

const state = {
  activePane: 'left', // 'left' | 'right'
  theme: 'light',
  rowDensity: 'normal',
  showHidden: true,
  confirmPaste: true,
  defaultFormat: 'png',
  
  // Cut clipboard
  cutItems: new Set(),
  pendingPasteBlob: null,
  inlineCreation: null, // { side: 'left'|'right', type: 'folder'|'file', defaultName: 'New Folder' }

  // Smart Type-Ahead state
  typeAhead: {
    prefix: '',
    lastTime: 0,
    matches: [],
    cycleIndex: 0,
    timer: null
  },

  panes: {
    left: {
      path: '/Users/sanjar/Downloads',
      isRemote: false,
      cursor: 1,
      marked: new Set(['brand-guidelines.pdf', 'hero-image.png']),
      files: [
        // Multiple items starting with 'D' to test cycling!
        { name: 'Deployments', ext: '', size: '—', date: 'Bugun, 11:30', type: 'folder', isHidden: false },
        { name: 'Design assets', ext: '', size: '—', date: 'Bugun, 10:45', type: 'folder', isHidden: false },
        { name: 'Documents', ext: '', size: '—', date: 'Kecha, 18:20', type: 'folder', isHidden: false },
        { name: 'Downloads-Archive', ext: 'zip', size: '142 MB', date: '19 Okt 2026', type: 'archive', isHidden: false },
        { name: 'database', ext: 'sqlite', size: '18.4 MB', date: '18 Okt 2026', type: 'code', isHidden: false },
        
        // Hidden files to test smart hidden file search!
        { name: '.git', ext: '', size: '—', date: 'Bugun, 09:10', type: 'folder', isHidden: true },
        { name: '.gitignore', ext: '', size: '420 B', date: '18 Okt 2026', type: 'code', isHidden: true },
        { name: '.env.local', ext: '', size: '1.2 KB', date: '17 Okt 2026', type: 'code', isHidden: true },
        
        // Other files
        { name: 'brand-guidelines', ext: 'pdf', size: '4.8 MB', date: 'Bugun, 10:26', type: 'pdf', isHidden: false },
        { name: 'hero-image', ext: 'png', size: '2.6 MB', date: 'Bugun, 09:40', type: 'image', isHidden: false },
        { name: 'meeting-notes', ext: 'md', size: '12 KB', date: '18 Okt 2026', type: 'code', isHidden: false },
        { name: 'invoice-october', ext: 'pdf', size: '185 KB', date: '16 Okt 2026', type: 'pdf', isHidden: false },
        { name: 'project-assets', ext: 'zip', size: '36.4 MB', date: '15 Okt 2026', type: 'archive', isHidden: false },
        { name: 'README', ext: 'txt', size: '2 KB', date: '14 Okt 2026', type: 'file', isHidden: false }
      ]
    },
    right: {
      path: '/home/sanjar/files',
      isRemote: true,
      cursor: 0,
      marked: new Set(),
      files: [
        { name: 'Backups', ext: '', size: '—', date: 'Bugun, 08:00', type: 'folder', isHidden: false },
        { name: 'Deploy-scripts', ext: '', size: '—', date: 'Bugun, 07:15', type: 'folder', isHidden: false },
        { name: 'Docker-compose', ext: 'yml', size: '4 KB', date: 'Kecha, 21:00', type: 'code', isHidden: false },
        { name: 'Documents', ext: '', size: '—', date: 'Kecha, 19:10', type: 'folder', isHidden: false },
        { name: '.bashrc', ext: '', size: '3.4 KB', date: '19 Okt 2026', type: 'code', isHidden: true },
        { name: 'app-release', ext: 'zip', size: '24.6 MB', date: '19 Okt 2026', type: 'archive', isHidden: false },
        { name: 'deployment', ext: 'md', size: '6 KB', date: '18 Okt 2026', type: 'code', isHidden: false },
        { name: 'server-config', ext: 'json', size: '3 KB', date: '17 Okt 2026', type: 'code', isHidden: false },
        { name: 'welcome-guide', ext: 'pdf', size: '1.2 MB', date: '15 Okt 2026', type: 'pdf', isHidden: false }
      ]
    }
  }
};

// DOM References
const leftRowsEl = document.getElementById('left-file-rows');
const rightRowsEl = document.getElementById('right-file-rows');
const leftSummaryEl = document.getElementById('left-summary');
const rightSummaryEl = document.getElementById('right-summary');
const globalSelCountEl = document.getElementById('global-sel-count');

const appWindowEl = document.getElementById('app-window');
const paneLeftEl = document.getElementById('pane-left');
const paneRightEl = document.getElementById('pane-right');
const sidebarEl = document.getElementById('places-sidebar');

// Modals
const settingsModalEl = document.getElementById('settings-modal');
const pasteModalEl = document.getElementById('paste-modal');
const quicklookModalEl = document.getElementById('quicklook-modal');
const confirmDialogModalEl = document.getElementById('confirm-dialog-modal');
const openwithModalEl = document.getElementById('openwith-modal');
const toastEl = document.getElementById('toast');
const toastMsgEl = document.getElementById('toast-msg');
const contextMenuEl = document.getElementById('file-context-menu');

// Helpers
function getActivePane() {
  return state.panes[state.activePane];
}

function showToast(message) {
  toastMsgEl.textContent = message;
  toastEl.hidden = false;
  clearTimeout(window.toastTimer);
  window.toastTimer = setTimeout(() => {
    toastEl.hidden = true;
  }, 3200);
}

// Generate sample test image for paste
function generateSampleImageBlob() {
  const canvas = document.createElement('canvas');
  canvas.width = 640;
  canvas.height = 360;
  const ctx = canvas.getContext('2d');

  const grad = ctx.createLinearGradient(0, 0, 640, 360);
  grad.addColorStop(0, '#007aff');
  grad.addColorStop(1, '#5856d6');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 640, 360);

  ctx.fillStyle = 'rgba(255, 255, 255, 0.15)';
  ctx.beginPath();
  ctx.arc(320, 180, 120, 0, Math.PI * 2);
  ctx.fill();

  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 26px -apple-system, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('Chrome: Copy Image Sample', 320, 160);

  ctx.font = '15px -apple-system, sans-serif';
  ctx.fillStyle = 'rgba(255, 255, 255, 0.85)';
  ctx.fillText('Telegram kabi clipboard rasm namunasi', 320, 200);

  return new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
}

// Render Files in a Pane
function renderPane(side) {
  const pane = state.panes[side];
  const container = side === 'left' ? leftRowsEl : rightRowsEl;
  const summaryEl = side === 'left' ? leftSummaryEl : rightSummaryEl;

  container.innerHTML = '';

  // Windows File Explorer Style: Inline New Item Row at the top!
  if (state.inlineCreation && state.inlineCreation.side === side) {
    const isFolder = state.inlineCreation.type === 'folder';
    const inlineRow = document.createElement('div');
    inlineRow.className = 'inline-create-row';
    inlineRow.innerHTML = `
      <div class="inline-input-wrap">
        <svg class="file-icon ${isFolder ? 'icon-folder' : 'icon-file'}"><use href="#${isFolder ? 'i-folder' : 'i-file'}"></use></svg>
        <input type="text" class="inline-create-input" value="${state.inlineCreation.defaultName}">
        <span class="inline-hint"><kbd>↩ Enter</kbd> saqlash, <kbd>Esc</kbd> bekor</span>
      </div>
      <div class="ext-cell">${isFolder ? '—' : 'txt'}</div>
      <div class="size-cell">0 B</div>
      <div class="date-cell">Hozirgina</div>
    `;

    container.appendChild(inlineRow);

    const input = inlineRow.querySelector('.inline-create-input');
    setTimeout(() => {
      input.focus();
      if (!isFolder && input.value.includes('.')) {
        const dotIndex = input.value.lastIndexOf('.');
        input.setSelectionRange(0, dotIndex);
      } else {
        input.select();
      }
    }, 20);

    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        commitInlineCreation(input.value);
      } else if (e.key === 'Escape') {
        e.preventDefault();
        cancelInlineCreation();
      }
    });
  }

  const visibleFiles = state.showHidden 
    ? pane.files 
    : pane.files.filter(f => !f.isHidden);

  visibleFiles.forEach((file, index) => {
    const isFocused = index === pane.cursor;
    const fullName = file.name + (file.ext ? '.' + file.ext : '');
    const isMarked = pane.marked.has(fullName);
    const isCut = state.cutItems.has(file.name);

    const row = document.createElement('div');
    row.className = `file-row ${isFocused ? 'focused' : ''} ${isMarked ? 'marked' : ''} ${isCut ? 'is-cut' : ''} ${file.isHidden ? 'is-hidden-file' : ''}`;
    row.dataset.index = index;

    let iconId = 'i-file';
    let iconClass = 'icon-file';
    if (file.type === 'folder') { iconId = 'i-folder'; iconClass = 'icon-folder'; }
    else if (file.type === 'image') { iconId = 'i-image'; iconClass = 'icon-image'; }
    else if (file.type === 'pdf') { iconId = 'i-file'; iconClass = 'icon-pdf'; }
    else if (file.type === 'archive') { iconId = 'i-archive'; iconClass = 'icon-archive'; }
    else if (file.type === 'code') { iconId = 'i-code'; iconClass = 'icon-code'; }

    row.innerHTML = `
      <div class="file-name-cell">
        <svg class="file-icon ${iconClass}"><use href="#${iconId}"></use></svg>
        <span class="file-title" title="${fullName}">${file.name}</span>
        ${file.isHidden ? '<span class="hidden-dot">hidden</span>' : ''}
      </div>
      <div class="ext-cell">${file.ext || '—'}</div>
      <div class="size-cell">${file.size}</div>
      <div class="date-cell">${file.date}</div>
    `;

    row.addEventListener('click', (e) => {
      switchPane(side);
      pane.cursor = index;
      if (e.metaKey || e.shiftKey) {
        toggleMark(side, fullName);
      }
      renderAll();
    });

    row.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      switchPane(side);
      pane.cursor = index;
      renderAll();
      openContextMenu(e.clientX, e.clientY);
    });

    container.appendChild(row);
  });

  const markedCount = pane.marked.size;
  summaryEl.textContent = `${visibleFiles.length} items ${markedCount ? `· ${markedCount} marked` : ''}`;

  if (state.activePane === side) {
    globalSelCountEl.innerHTML = markedCount 
      ? `<strong>${markedCount} ta element</strong> belgilandi` 
      : `<strong>1 ta element</strong> kursor ostida`;
  }
}

function renderAll() {
  renderPane('left');
  renderPane('right');

  paneLeftEl.classList.toggle('active', state.activePane === 'left');
  paneRightEl.classList.toggle('active', state.activePane === 'right');
}

function switchPane(side) {
  state.activePane = side;
  renderAll();
}

function toggleMark(side, fullName) {
  const pane = state.panes[side];
  if (pane.marked.has(fullName)) {
    pane.marked.delete(fullName);
  } else {
    pane.marked.add(fullName);
  }
}

// ==========================================================================
// Smart Type-Ahead: Hidden Files & Cycling Matches ('d' -> 'd' -> 'd')
// ==========================================================================

function handleTypeAhead(char) {
  const now = Date.now();
  const lowerChar = char.toLowerCase();
  const active = getActivePane();
  const badge = document.getElementById(`${state.activePane}-typeahead`);

  const visibleFiles = state.showHidden 
    ? active.files 
    : active.files.filter(f => !f.isHidden);

  if (!visibleFiles.length) return;

  const isWithinReset = (now - state.typeAhead.lastTime) < 1000;
  state.typeAhead.lastTime = now;

  if (isWithinReset && state.typeAhead.prefix.length === 1 && state.typeAhead.prefix === lowerChar) {
    // REPEATED SINGLE LETTER: Cycle to next match!
    if (state.typeAhead.matches.length > 1) {
      state.typeAhead.cycleIndex = (state.typeAhead.cycleIndex + 1) % state.typeAhead.matches.length;
      const targetIndex = state.typeAhead.matches[state.typeAhead.cycleIndex];
      active.cursor = targetIndex;
      renderAll();

      showTypeAheadBadge(badge, `"${lowerChar}"`, `${state.typeAhead.cycleIndex + 1} of ${state.typeAhead.matches.length} (bosishda davom eting)`);
      scrollCursorIntoView();
      return;
    }
  }

  if (isWithinReset) {
    state.typeAhead.prefix += lowerChar;
  } else {
    state.typeAhead.prefix = lowerChar;
    state.typeAhead.cycleIndex = 0;
  }

  const query = state.typeAhead.prefix;

  // Search logic: matches normal names AND hidden files (with or without dot!)
  const matches = [];
  visibleFiles.forEach((file, index) => {
    const rawName = file.name.toLowerCase();
    const strippedName = rawName.replace(/^\./, ''); // e.g. .git -> git

    // If query starts with '.', match directly; if not, match either normal or stripped!
    const matchesPrefix = query.startsWith('.') 
      ? rawName.startsWith(query) 
      : (rawName.startsWith(query) || strippedName.startsWith(query));

    if (matchesPrefix) {
      matches.push(index);
    }
  });

  state.typeAhead.matches = matches;

  if (matches.length > 0) {
    state.typeAhead.cycleIndex = 0;
    active.cursor = matches[0];
    renderAll();
    scrollCursorIntoView();

    const hint = matches.length > 1 
      ? `1 of ${matches.length} ('${lowerChar}' ni bosib keyingisiga o'ting)` 
      : '1 ta topildi';
    showTypeAheadBadge(badge, `"${query}"`, hint);
  } else {
    showTypeAheadBadge(badge, `"${query}"`, 'Topilmadi');
  }
}

function showTypeAheadBadge(badge, queryText, hintText) {
  badge.querySelector('.query-text').textContent = queryText;
  badge.querySelector('.match-count').textContent = hintText;
  badge.hidden = false;

  clearTimeout(state.typeAhead.timer);
  state.typeAhead.timer = setTimeout(() => {
    badge.hidden = true;
    state.typeAhead.prefix = '';
    state.typeAhead.matches = [];
  }, 1800);
}

function scrollCursorIntoView() {
  const container = state.activePane === 'left' ? leftRowsEl : rightRowsEl;
  const focusedRow = container.querySelector('.file-row.focused');
  if (focusedRow) {
    focusedRow.scrollIntoView({ block: 'nearest' });
  }
}

// ==========================================================================
// Quick Look Preview Modal (Space / F3)
// ==========================================================================

function openQuickLook() {
  const active = getActivePane();
  const curFile = active.files[active.cursor];
  if (!curFile) return;

  closeContextMenu();
  settingsModalEl.hidden = true;
  pasteModalEl.hidden = true;
  confirmDialogModalEl.hidden = true;

  updateQuickLookContent(curFile);
  quicklookModalEl.hidden = false;
}

function closeQuickLook() {
  quicklookModalEl.hidden = true;
  appWindowEl.focus();
}

function updateQuickLookContent(file) {
  const titleEl = document.getElementById('ql-filename');
  const metaEl = document.getElementById('ql-meta');
  const bodyEl = document.getElementById('quicklook-content');

  const fullName = file.name + (file.ext ? '.' + file.ext : '');
  titleEl.textContent = fullName;
  metaEl.textContent = `${file.type.toUpperCase()} · ${file.size} · Oxirgi o'zgarish: ${file.date}`;

  if (file.type === 'image') {
    bodyEl.innerHTML = `
      <img src="https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80" 
           alt="${fullName}" class="ql-preview-img">
    `;
  } else if (file.type === 'code' || file.ext === 'md' || file.ext === 'txt') {
    bodyEl.innerHTML = `
      <pre class="ql-preview-text"># ${fullName}
// Commander for Mac · Fast Preview
// Bu yerda fayl tarkibi darhol ko'rinadi

export interface FileItem {
  name: string;
  size: number;
  modified: Date;
  isFolder: boolean;
}

console.log("Quick Look is working seamlessly!");
</pre>
    `;
  } else {
    bodyEl.innerHTML = `
      <div style="text-align: center; color: var(--text-secondary); display: flex; flex-direction: column; align-items: center; gap: 12px;">
        <svg style="width: 48px; height: 48px; color: var(--accent-color);"><use href="#i-file"></use></svg>
        <div>
          <strong style="font-size: 14px; color: var(--text-main); display: block;">${fullName}</strong>
          <span>${file.size} · ${file.date}</span>
        </div>
        <p style="font-size: 11px; max-width: 280px; color: var(--text-muted);">
          Bu fayl turini to'liq ko'rish uchun "Open in Default App" tugmasini bosing.
        </p>
      </div>
    `;
  }
}

function navQuickLook(delta) {
  const active = getActivePane();
  active.cursor = Math.max(0, Math.min(active.cursor + delta, active.files.length - 1));
  renderAll();
  updateQuickLookContent(active.files[active.cursor]);
}

document.getElementById('close-quicklook-modal').addEventListener('click', closeQuickLook);
document.getElementById('done-quicklook-btn').addEventListener('click', closeQuickLook);
document.getElementById('ql-prev-btn').addEventListener('click', () => navQuickLook(-1));
document.getElementById('ql-next-btn').addEventListener('click', () => navQuickLook(1));
document.getElementById('ql-open-with-btn').addEventListener('click', () => {
  const active = getActivePane();
  const cur = active.files[active.cursor];
  showToast(`🚀 "${cur.name}" tizim default ilovasida ochildi`);
  closeQuickLook();
});

quicklookModalEl.addEventListener('click', (e) => {
  if (e.target === quicklookModalEl) closeQuickLook();
});

// ==========================================================================
// Affirmative Confirmation Dialog (Enter by default confirms!)
// ==========================================================================

function openConfirmDialog(message, onConfirm) {
  closeContextMenu();
  const msgEl = document.getElementById('dialog-message');
  msgEl.innerHTML = message;

  confirmDialogModalEl.hidden = false;

  const confirmBtn = document.getElementById('dialog-confirm-btn');
  const cancelBtn = document.getElementById('dialog-cancel-btn');

  // Affirmative button is focused by default!
  confirmBtn.focus();

  const handleConfirm = () => {
    confirmDialogModalEl.hidden = true;
    cleanup();
    onConfirm();
  };

  const handleCancel = () => {
    confirmDialogModalEl.hidden = true;
    cleanup();
    appWindowEl.focus();
  };

  function cleanup() {
    confirmBtn.removeEventListener('click', handleConfirm);
    cancelBtn.removeEventListener('click', handleCancel);
    document.getElementById('close-confirm-modal').removeEventListener('click', handleCancel);
  }

  confirmBtn.addEventListener('click', handleConfirm);
  cancelBtn.addEventListener('click', handleCancel);
  document.getElementById('close-confirm-modal').addEventListener('click', handleCancel);
}

// Trigger Delete Confirmation Modal (⌘⌫)
function promptDeleteSelected() {
  const active = getActivePane();
  const count = active.marked.size;
  const targetName = count 
    ? `${count} ta belgilangan faylni` 
    : `<strong>"${active.files[active.cursor]?.name}"</strong> faylini`;

  openConfirmDialog(
    `Haqiqatan ham ${targetName} Trash'ga tashlaysizmi?`,
    () => {
      if (active.marked.size) {
        active.files = active.files.filter(f => !active.marked.has(f.name + (f.ext ? '.' + f.ext : '')));
        active.marked.clear();
      } else {
        active.files.splice(active.cursor, 1);
      }
      active.cursor = Math.max(0, Math.min(active.cursor, active.files.length - 1));
      renderAll();
      showToast('🗑 Elementlar Trash\'ga muvaffaqiyatli o\'chirildi (Enter tasdiqladi)');
    }
  );
}

// ==========================================================================
// Windows File Explorer Style: New Folder & New File (Inline & Buttons)
// ==========================================================================

const newItemsPopoverEl = document.getElementById('new-items-popover');

function toggleNewDropdown() {
  newItemsPopoverEl.hidden = !newItemsPopoverEl.hidden;
}

function closeNewDropdown() {
  if (newItemsPopoverEl) newItemsPopoverEl.hidden = true;
}

function startInlineCreation(type) {
  closeNewDropdown();
  closeContextMenu();
  const defaultName = type === 'folder' ? 'New Folder' : 'untitled.txt';
  state.inlineCreation = {
    side: state.activePane,
    type: type,
    defaultName: defaultName
  };
  renderAll();
}

function commitInlineCreation(rawName) {
  if (!state.inlineCreation) return;
  const isFolder = state.inlineCreation.type === 'folder';
  const side = state.inlineCreation.side;
  const pane = state.panes[side];

  let name = rawName.trim();
  let ext = '';

  if (isFolder) {
    if (!name) name = 'New Folder';
  } else {
    if (!name) name = 'untitled.txt';
    if (name.includes('.')) {
      const parts = name.split('.');
      ext = parts.pop();
      name = parts.join('.');
    } else {
      ext = 'txt';
    }
  }

  const newItem = {
    name: name,
    ext: ext,
    size: isFolder ? '—' : '0 B',
    date: 'Hozirgina',
    type: isFolder ? 'folder' : 'file',
    isHidden: name.startsWith('.')
  };

  pane.files.unshift(newItem);
  pane.cursor = 0;
  state.inlineCreation = null;
  renderAll();
  showToast(isFolder ? `📁 "${name}" papkasi yaratildi!` : `📄 "${name}.${ext}" fayli yaratildi!`);
}

function cancelInlineCreation() {
  state.inlineCreation = null;
  renderAll();
}

// Dropdown button triggers
document.getElementById('tb-new-main-btn').addEventListener('click', () => startInlineCreation('folder'));
document.getElementById('tb-new-dropdown-arrow').addEventListener('click', (e) => {
  e.stopPropagation();
  toggleNewDropdown();
});

document.getElementById('pop-new-folder').addEventListener('click', () => startInlineCreation('folder'));
document.getElementById('pop-new-file').addEventListener('click', () => startInlineCreation('file'));
document.getElementById('pop-new-paste').addEventListener('click', async () => {
  closeNewDropdown();
  const blob = await generateSampleImageBlob();
  openPasteModalWithBlob(blob);
});

document.getElementById('btn-quick-new-folder').addEventListener('click', () => startInlineCreation('folder'));
document.getElementById('btn-quick-new-file').addEventListener('click', () => startInlineCreation('file'));
document.getElementById('act-new-folder').addEventListener('click', () => startInlineCreation('folder'));
document.getElementById('act-new-file').addEventListener('click', () => startInlineCreation('file'));

document.addEventListener('click', (e) => {
  if (newItemsPopoverEl && !e.target.closest('.new-dropdown-wrap')) {
    closeNewDropdown();
  }
});

// ==========================================================================
// Open in Terminal & Open With Actions
// ==========================================================================

function openCurrentPathInTerminal() {
  const active = getActivePane();
  showToast(`💻 Terminal ochildi: ${active.path}`);
}

document.getElementById('demo-terminal-btn').addEventListener('click', openCurrentPathInTerminal);
document.getElementById('tb-terminal-btn').addEventListener('click', openCurrentPathInTerminal);
document.getElementById('left-terminal-btn').addEventListener('click', openCurrentPathInTerminal);

// Context menu open with options
document.querySelectorAll('#ctx-open-with-menu .ctx-item').forEach(btn => {
  btn.addEventListener('click', () => {
    const app = btn.dataset.app;
    const cur = getActivePane().files[getActivePane().cursor];
    closeContextMenu();
    if (app === 'choose' || app === 'always' || app === 'other') {
      openAppChooserModal(cur);
      return;
    }
    showToast(`🚀 "${cur.name}" ${btn.textContent.trim()} orqali ochildi`);
  });
});

document.getElementById('ql-choose-app-btn')?.addEventListener('click', () => {
  const cur = getActivePane().files[getActivePane().cursor];
  closeQuickLook();
  openAppChooserModal(cur);
});

// ==========================================================================
// Open With App Chooser Modal
// ==========================================================================

const recommendedApps = {
  image: [
    { name: 'Preview.app', path: '/System/Applications/Preview.app', isDefault: true, icon: 'i-eye' },
    { name: 'CleanShot X', path: '/Applications/CleanShot X.app', isDefault: false, icon: 'i-camera' },
    { name: 'Pixelmator Pro', path: '/Applications/Pixelmator Pro.app', isDefault: false, icon: 'i-image' },
    { name: 'Google Chrome', path: '/Applications/Google Chrome.app', isDefault: false, icon: 'i-external' }
  ],
  code: [
    { name: 'Visual Studio Code', path: '/Applications/Visual Studio Code.app', isDefault: true, icon: 'i-code' },
    { name: 'Sublime Text', path: '/Applications/Sublime Text.app', isDefault: false, icon: 'i-code' },
    { name: 'TextEdit.app', path: '/System/Applications/TextEdit.app', isDefault: false, icon: 'i-file' },
    { name: 'Xcode', path: '/Applications/Xcode.app', isDefault: false, icon: 'i-code' },
    { name: 'Terminal (nano)', path: '/System/Applications/Utilities/Terminal.app', isDefault: false, icon: 'i-terminal' }
  ],
  pdf: [
    { name: 'Preview.app', path: '/System/Applications/Preview.app', isDefault: true, icon: 'i-eye' },
    { name: 'Adobe Acrobat Reader', path: '/Applications/Adobe Acrobat Reader.app', isDefault: false, icon: 'i-file' },
    { name: 'Google Chrome', path: '/Applications/Google Chrome.app', isDefault: false, icon: 'i-external' }
  ],
  archive: [
    { name: 'Archive Utility', path: '/System/Library/CoreServices/Applications/Archive Utility.app', isDefault: true, icon: 'i-archive' },
    { name: 'The Unarchiver', path: '/Applications/The Unarchiver.app', isDefault: false, icon: 'i-archive' },
    { name: 'Commander Unpack', path: 'Commander Built-in', isDefault: false, icon: 'i-archive' }
  ],
  fallback: [
    { name: 'TextEdit.app', path: '/System/Applications/TextEdit.app', isDefault: true, icon: 'i-file' },
    { name: 'Quick Look', path: 'macOS Quick Look', isDefault: false, icon: 'i-eye' },
    { name: 'Visual Studio Code', path: '/Applications/Visual Studio Code.app', isDefault: false, icon: 'i-code' }
  ]
};

let currentAppChooserFile = null;

function openAppChooserModal(file = null) {
  const active = getActivePane();
  currentAppChooserFile = file || active.files[active.cursor];
  if (!currentAppChooserFile) return;

  closeContextMenu();
  settingsModalEl.hidden = true;
  pasteModalEl.hidden = true;
  quicklookModalEl.hidden = true;
  confirmDialogModalEl.hidden = true;

  const ext = (currentAppChooserFile.ext || '').toLowerCase();
  let category = 'fallback';
  if (['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg'].includes(ext) || currentAppChooserFile.type === 'image') category = 'image';
  else if (['md', 'txt', 'py', 'js', 'ts', 'json', 'swift', 'html', 'css', 'sh'].includes(ext) || currentAppChooserFile.type === 'code') category = 'code';
  else if (ext === 'pdf' || currentAppChooserFile.type === 'pdf') category = 'pdf';
  else if (['zip', 'tar', 'gz', 'rar', '7z'].includes(ext) || currentAppChooserFile.type === 'archive') category = 'archive';

  const apps = recommendedApps[category] || recommendedApps.fallback;

  document.getElementById('openwith-target-info').textContent = `"${currentAppChooserFile.name}.${ext}" uchun ochuvchi ilovani tanlang`;
  document.getElementById('always-ext-label').textContent = ext ? `.${ext}` : 'fayllar';

  const listEl = document.getElementById('openwith-apps-list');
  listEl.innerHTML = '';

  apps.forEach((app, idx) => {
    const item = document.createElement('div');
    item.className = `app-picker-item ${idx === 0 ? 'selected' : ''}`;
    item.dataset.appIndex = idx;
    item.dataset.appName = app.name;

    item.innerHTML = `
      <div class="app-picker-icon"><svg><use href="#${app.icon}"></use></svg></div>
      <div class="app-picker-info">
        <span class="app-picker-title">${app.name}</span>
        <span class="app-picker-meta">${app.path}</span>
      </div>
      ${app.isDefault ? '<span class="app-default-badge">Tavsiya etiladi</span>' : ''}
    `;

    item.addEventListener('click', () => {
      listEl.querySelectorAll('.app-picker-item').forEach(el => el.classList.remove('selected'));
      item.classList.add('selected');
    });

    listEl.appendChild(item);
  });

  openwithModalEl.hidden = false;
  document.getElementById('openwith-search').value = '';
  document.getElementById('openwith-search').focus();
}

function closeAppChooserModal() {
  openwithModalEl.hidden = true;
  currentAppChooserFile = null;
  appWindowEl.focus();
}

function confirmAppChooser() {
  const selectedItem = document.querySelector('.app-picker-item.selected');
  const appName = selectedItem ? selectedItem.dataset.appName : 'Default App';
  const always = document.getElementById('always-open-checkbox').checked;

  const file = currentAppChooserFile;
  closeAppChooserModal();

  if (always && file) {
    const ext = file.ext || 'fayllar';
    showToast(`🚀 ".${ext}" fayllari endi har doim "${appName}" orqali ochiladi!`);
  } else {
    showToast(`🚀 "${file?.name}" ${appName} orqali ochildi`);
  }
}

document.getElementById('close-openwith-modal').addEventListener('click', closeAppChooserModal);
document.getElementById('cancel-openwith-btn').addEventListener('click', closeAppChooserModal);
document.getElementById('confirm-openwith-btn').addEventListener('click', confirmAppChooser);
document.getElementById('openwith-browse-btn').addEventListener('click', () => {
  showToast('📁 /Applications papkasidan ilova tanlash oynasi ochildi');
});

openwithModalEl.addEventListener('click', (e) => {
  if (e.target === openwithModalEl) closeAppChooserModal();
});

// Search filter in App Chooser
document.getElementById('openwith-search').addEventListener('input', (e) => {
  const query = e.target.value.toLowerCase().trim();
  document.querySelectorAll('.app-picker-item').forEach(item => {
    const name = item.dataset.appName.toLowerCase();
    item.style.display = name.includes(query) ? 'flex' : 'none';
  });
});

document.querySelectorAll('.assoc-select').forEach(sel => {
  sel.addEventListener('change', (e) => {
    showToast(`✅ Saqlandi: ushbu turdagi fayllar doim "${e.target.options[e.target.selectedIndex].text}" orqali ochiladi`);
  });
});

document.getElementById('btn-add-assoc')?.addEventListener('click', () => {
  showToast('➕ Yangi kengaytma biriktirish');
});

// ==========================================================================
// In-App Settings & Paste Handlers
// ==========================================================================

function openSettingsModal() {
  closeContextMenu();
  pasteModalEl.hidden = true;
  quicklookModalEl.hidden = true;
  confirmDialogModalEl.hidden = true;
  settingsModalEl.hidden = false;
}

function closeSettingsModal() {
  settingsModalEl.hidden = true;
  appWindowEl.focus();
}

document.querySelectorAll('.set-tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.set-tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.set-pane').forEach(p => p.classList.remove('active'));
    btn.classList.add('active');
    const pane = document.getElementById(`tab-${btn.dataset.tab}`);
    if (pane) pane.classList.add('active');
  });
});

document.querySelectorAll('#theme-segmented .seg-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('#theme-segmented .seg-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    setTheme(btn.dataset.themeVal);
  });
});

document.querySelectorAll('#density-segmented .seg-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('#density-segmented .seg-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const density = btn.dataset.density;
    let height = '30px';
    if (density === 'compact') height = '24px';
    if (density === 'cozy') height = '36px';
    document.documentElement.style.setProperty('--row-height', height);
  });
});

// Hidden files toggle
document.getElementById('show-hidden-toggle').addEventListener('change', (e) => {
  state.showHidden = e.target.checked;
  renderAll();
  showToast(state.showHidden ? 'Yashirin fayllar ko\'rsatildi' : 'Yashirin fayllar berkitildi');
});

// Font size change
document.getElementById('set-font-size')?.addEventListener('change', (e) => {
  document.documentElement.style.setProperty('--font-size-base', e.target.value + 'px');
  showToast(`Shrift o'lchami: ${e.target.value} pt`);
});

// Behavior settings listeners
document.getElementById('set-backspace-act')?.addEventListener('change', (e) => {
  showToast(`⌫ Backspace: ${e.target.options[e.target.selectedIndex].text}`);
});
document.getElementById('set-space-advance')?.addEventListener('change', (e) => {
  showToast(`Space amali: ${e.target.options[e.target.selectedIndex].text}`);
});
document.getElementById('set-copy-confirm')?.addEventListener('change', (e) => {
  showToast(`F5/F6: ${e.target.options[e.target.selectedIndex].text}`);
});
document.getElementById('set-forward-del')?.addEventListener('change', (e) => {
  showToast(`Forward Delete (⌦): ${e.target.checked ? 'Yoqildi' : 'O\'chirildi'}`);
});
document.getElementById('set-restore-session')?.addEventListener('change', (e) => {
  showToast(`On launch: ${e.target.options[e.target.selectedIndex].text}`);
});

document.getElementById('close-settings-modal').addEventListener('click', closeSettingsModal);
document.getElementById('done-settings-btn').addEventListener('click', closeSettingsModal);
document.getElementById('open-settings-shortcut-btn').addEventListener('click', openSettingsModal);
document.getElementById('tb-settings-btn').addEventListener('click', openSettingsModal);

settingsModalEl.addEventListener('click', (e) => {
  if (e.target === settingsModalEl) closeSettingsModal();
});

// Paste modal handlers
function openPasteModalWithBlob(blob, customName = null) {
  state.pendingPasteBlob = blob;
  const imgUrl = URL.createObjectURL(blob);
  
  document.getElementById('paste-preview-img').src = imgUrl;

  const now = new Date();
  const timeStr = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}`;
  
  const nameInput = document.getElementById('paste-filename-input');
  nameInput.value = customName || `Pasted-Image-${timeStr}`;

  document.getElementById('paste-target-path').textContent = getActivePane().path;

  const sizeKb = Math.round(blob.size / 1024);
  document.getElementById('paste-img-meta').textContent = `PNG · ${sizeKb > 1000 ? (sizeKb/1024).toFixed(1) + ' MB' : sizeKb + ' KB'}`;

  closeContextMenu();
  settingsModalEl.hidden = true;
  quicklookModalEl.hidden = true;
  confirmDialogModalEl.hidden = true;

  pasteModalEl.hidden = false;
  nameInput.focus();
  nameInput.select();
}

function closePasteModal() {
  pasteModalEl.hidden = true;
  state.pendingPasteBlob = null;
  appWindowEl.focus();
}

function confirmPasteImage() {
  const nameInput = document.getElementById('paste-filename-input');
  const extSelect = document.getElementById('paste-ext-select');
  
  let baseName = nameInput.value.trim() || 'Pasted-Image';
  let ext = extSelect.value.replace('.', '');

  const active = getActivePane();
  const newFile = {
    name: baseName,
    ext: ext,
    size: state.pendingPasteBlob ? Math.round(state.pendingPasteBlob.size / 1024) + ' KB' : '1.4 MB',
    date: 'Hozirgina',
    type: 'image',
    isHidden: false
  };

  active.files.unshift(newFile);
  active.cursor = 0;
  renderAll();

  closePasteModal();
  showToast(`📋 "${baseName}.${ext}" faol panelga saqlandi! (Enter tasdiqladi)`);
}

document.getElementById('close-paste-modal').addEventListener('click', closePasteModal);
document.getElementById('cancel-paste-btn').addEventListener('click', closePasteModal);
document.getElementById('confirm-paste-btn').addEventListener('click', confirmPasteImage);

pasteModalEl.addEventListener('click', (e) => {
  if (e.target === pasteModalEl) closePasteModal();
});

document.getElementById('simulate-paste-btn').addEventListener('click', async () => {
  const blob = await generateSampleImageBlob();
  openPasteModalWithBlob(blob);
});
document.getElementById('tb-paste-btn').addEventListener('click', async () => {
  const blob = await generateSampleImageBlob();
  openPasteModalWithBlob(blob);
});
document.getElementById('act-paste').addEventListener('click', async () => {
  const blob = await generateSampleImageBlob();
  openPasteModalWithBlob(blob);
});

// Browser paste event listener
window.addEventListener('paste', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

  const items = (e.clipboardData || e.originalEvent.clipboardData).items;
  let imageFound = false;

  for (let index in items) {
    const item = items[index];
    if (item.kind === 'file' && item.type.startsWith('image/')) {
      const blob = item.getAsFile();
      openPasteModalWithBlob(blob);
      imageFound = true;
      e.preventDefault();
      break;
    }
  }

  if (!imageFound) {
    showToast('Clipboard tekshirildi (rasm topilmadi)');
  }
});

// ==========================================================================
// Master Keyboard Event Handler
// ==========================================================================

window.addEventListener('keydown', (e) => {
  // If typing in input fields, bypass commander shortcuts
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') {
    if (e.key === 'Escape') {
      if (!openwithModalEl.hidden) closeAppChooserModal();
      if (!pasteModalEl.hidden) closePasteModal();
      if (!settingsModalEl.hidden) closeSettingsModal();
    }
    if (e.key === 'Enter') {
      if (!openwithModalEl.hidden) {
        confirmAppChooser();
        e.preventDefault();
      } else if (!pasteModalEl.hidden) {
        confirmPasteImage();
        e.preventDefault();
      }
    }
    return;
  }

  // Esc: Close topmost modal or clear selection
  if (e.key === 'Escape') {
    e.preventDefault();
    if (!contextMenuEl.hidden) { closeContextMenu(); return; }
    if (!openwithModalEl.hidden) { closeAppChooserModal(); return; }
    if (!confirmDialogModalEl.hidden) { document.getElementById('dialog-cancel-btn').click(); return; }
    if (!quicklookModalEl.hidden) { closeQuickLook(); return; }
    if (!pasteModalEl.hidden) { closePasteModal(); return; }
    if (!settingsModalEl.hidden) { closeSettingsModal(); return; }

    getActivePane().marked.clear();
    renderAll();
    showToast('Barcha belgilar olib tashlandi (Esc)');
    return;
  }

  // Enter in Confirmation Dialog -> Default affirmative action!
  if (e.key === 'Enter') {
    if (!openwithModalEl.hidden) {
      e.preventDefault();
      confirmAppChooser();
      return;
    }
    if (!confirmDialogModalEl.hidden) {
      e.preventDefault();
      document.getElementById('dialog-confirm-btn').click();
      return;
    }
    if (!quicklookModalEl.hidden) {
      e.preventDefault();
      closeQuickLook();
      return;
    }
    if (!pasteModalEl.hidden) {
      e.preventDefault();
      confirmPasteImage();
      return;
    }
    if (!settingsModalEl.hidden) {
      e.preventDefault();
      closeSettingsModal();
      return;
    }
  }

  // ⌥↩ : Open With App Chooser Modal
  if (e.altKey && e.key === 'Enter') {
    e.preventDefault();
    openAppChooserModal();
    return;
  }

  // ⌥⌘T : Open in Terminal
  if (e.altKey && e.metaKey && e.key.toLowerCase() === 't') {
    e.preventDefault();
    openCurrentPathInTerminal();
    return;
  }

  // ⌘, : Open Settings
  if (e.metaKey && e.key === ',') {
    e.preventDefault();
    openSettingsModal();
    return;
  }

  // ⌘V : Paste
  if (e.metaKey && e.key.toLowerCase() === 'v') {
    generateSampleImageBlob().then(blob => openPasteModalWithBlob(blob));
    return;
  }

  // ⌘⌫ : Move to Trash with Affirmative Confirmation Dialog!
  if (e.metaKey && e.key === 'Backspace') {
    e.preventDefault();
    promptDeleteSelected();
    return;
  }

  // Space or F3: Quick Look Preview
  if (e.key === ' ' || e.key === 'F3') {
    e.preventDefault();
    if (!quicklookModalEl.hidden) {
      closeQuickLook();
    } else {
      openQuickLook();
    }
    return;
  }

  // Tab: Switch pane
  if (e.key === 'Tab') {
    e.preventDefault();
    switchPane(state.activePane === 'left' ? 'right' : 'left');
    return;
  }

  // Up / Down arrows
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    if (!quicklookModalEl.hidden) {
      navQuickLook(1);
    } else {
      const active = getActivePane();
      if (active.cursor < active.files.length - 1) {
        active.cursor++;
        renderAll();
        scrollCursorIntoView();
      }
    }
    return;
  }

  if (e.key === 'ArrowUp') {
    e.preventDefault();
    if (!quicklookModalEl.hidden) {
      navQuickLook(-1);
    } else {
      const active = getActivePane();
      if (active.cursor > 0) {
        active.cursor--;
        renderAll();
        scrollCursorIntoView();
      }
    }
    return;
  }

  // F7 or ⌘⇧N : New Folder (Windows Explorer Style)
  if (e.key === 'F7' || (e.metaKey && e.shiftKey && e.key.toLowerCase() === 'n')) {
    e.preventDefault();
    startInlineCreation('folder');
    return;
  }

  // ⌘N : New File (Windows Explorer Style)
  if (e.metaKey && !e.shiftKey && e.key.toLowerCase() === 'n') {
    e.preventDefault();
    startInlineCreation('file');
    return;
  }

  // F5 / F6
  if (e.key === 'F5') { e.preventDefault(); copyToOtherPane(); return; }
  if (e.key === 'F6') { e.preventDefault(); moveToOtherPane(); return; }

  // ⌫ Backspace: Parent folder
  if (e.key === 'Backspace') {
    e.preventDefault();
    showToast('↑ Ota papkaga o\'tildi (⌫)');
    return;
  }

  // Type-ahead letters (letters a-z, digits 0-9, dot '.')
  if (!e.metaKey && !e.ctrlKey && !e.altKey && e.key.length === 1 && !pasteModalEl.hidden && !settingsModalEl.hidden) {
    // only if no modal is open
  } else if (!e.metaKey && !e.ctrlKey && !e.altKey && e.key.length === 1 && quicklookModalEl.hidden && pasteModalEl.hidden && settingsModalEl.hidden && confirmDialogModalEl.hidden) {
    handleTypeAhead(e.key);
  }
});

function copyToOtherPane() {
  const src = getActivePane();
  const destSide = state.activePane === 'left' ? 'right' : 'left';
  const dest = state.panes[destSide];

  const itemsToCopy = src.marked.size 
    ? src.files.filter(f => src.marked.has(f.name + (f.ext ? '.' + f.ext : '')))
    : [src.files[src.cursor]].filter(Boolean);

  if (itemsToCopy.length) {
    itemsToCopy.forEach(item => dest.files.unshift({ ...item }));
    src.marked.clear();
    renderAll();
    showToast(`F5: ${itemsToCopy.length} ta element ikkinchi panelga nusxalandi`);
  }
}

function moveToOtherPane() {
  const src = getActivePane();
  const destSide = state.activePane === 'left' ? 'right' : 'left';
  const dest = state.panes[destSide];

  const itemsToMove = src.marked.size 
    ? src.files.filter(f => src.marked.has(f.name + (f.ext ? '.' + f.ext : '')))
    : [src.files[src.cursor]].filter(Boolean);

  if (itemsToMove.length) {
    itemsToMove.forEach(item => dest.files.unshift({ ...item }));
    src.files = src.files.filter(f => !itemsToMove.includes(f));
    src.marked.clear();
    src.cursor = Math.max(0, Math.min(src.cursor, src.files.length - 1));
    renderAll();
    showToast(`F6: ${itemsToMove.length} ta element ikkinchi panelga ko'chirildi`);
  }
}

// Context Menu Setup
function openContextMenu(x, y) {
  contextMenuEl.style.left = `${Math.min(x, window.innerWidth - 230)}px`;
  contextMenuEl.style.top = `${Math.min(y, window.innerHeight - 300)}px`;
  contextMenuEl.hidden = false;
}

function closeContextMenu() {
  contextMenuEl.hidden = true;
}

document.addEventListener('click', (e) => {
  if (!contextMenuEl.contains(e.target)) closeContextMenu();
});

document.querySelectorAll('.context-menu .ctx-item').forEach(btn => {
  btn.addEventListener('click', (e) => {
    if (btn.classList.contains('has-sub')) return;
    const action = btn.dataset.action;
    closeContextMenu();
    if (action === 'preview') openQuickLook();
    if (action === 'terminal') openCurrentPathInTerminal();
    if (action === 'new-folder') startInlineCreation('folder');
    if (action === 'new-file') startInlineCreation('file');
    if (action === 'copy') showToast('⌘C: Fayl nusxalandi');
    if (action === 'cut') showToast('⌘X: Fayl kesildi (✂)');
    if (action === 'paste') generateSampleImageBlob().then(b => openPasteModalWithBlob(b));
    if (action === 'telegram') shareToTelegram();
    if (action === 'copy-path') showToast('Yo\'l nusxalandi (⌘⇧C)');
    if (action === 'f5') copyToOtherPane();
    if (action === 'f6') moveToOtherPane();
    if (action === 'trash') promptDeleteSelected();
  });
});

// Theme switcher
function setTheme(theme) {
  state.theme = theme;
  document.documentElement.dataset.theme = theme;
  appWindowEl.dataset.theme = theme;
  const themeIcon = document.getElementById('theme-icon');
  themeIcon.innerHTML = theme === 'dark' ? '<use href="#i-sun"></use>' : '<use href="#i-moon"></use>';
}

document.getElementById('theme-toggle-btn').addEventListener('click', () => {
  setTheme(state.theme === 'light' ? 'dark' : 'light');
});

document.getElementById('toggle-sidebar-btn').addEventListener('click', () => {
  sidebarEl.classList.toggle('collapsed');
});

// Quick Action Bar click handlers
document.getElementById('act-copy').addEventListener('click', copyToOtherPane);
document.getElementById('act-move').addEventListener('click', moveToOtherPane);
document.getElementById('act-preview').addEventListener('click', openQuickLook);
document.getElementById('tb-quicklook-btn').addEventListener('click', openQuickLook);
document.getElementById('act-trash').addEventListener('click', promptDeleteSelected);

// Telegram Share handler
function shareToTelegram() {
  const active = getActivePane();
  const count = active.marked.size;
  const targetDesc = count 
    ? `<strong>${count} ta belgilangan fayl</strong>` 
    : `<strong>"${active.files[active.cursor]?.name}"</strong> fayli`;

  showToast(`✈️ ${targetDesc.replace(/<[^>]*>/g, '')} Telegram orqali yuborilmoqda...`);
}

document.getElementById('act-share-telegram').addEventListener('click', shareToTelegram);

// Initial Render
renderAll();
