const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const icon = (name, className = '') => `<svg class="${className}" aria-hidden="true"><use href="#i-${name}"></use></svg>`;
const escapeText = text => String(text).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
const file = (name, size, date, type = 'file') => ({name, size, date, type});
const initialLeft = [
  file('Design assets', '—', 'Today, 10:42', 'folder'),
  file('Projects', '—', 'Yesterday', 'folder'),
  file('Screenshots', '—', 'Yesterday', 'folder'),
  file('Archive', '—', '18 Oct 2026', 'folder'),
  file('brand-guidelines.pdf', '4.8 MB', 'Today, 10:26', 'pdf'),
  file('project-assets.zip', '36.4 MB', 'Today, 09:54', 'archive'),
  file('meeting-notes.md', '12 KB', 'Today, 09:12', 'code'),
  file('hero-image.png', '2.6 MB', 'Yesterday', 'image'),
  file('invoice-october.pdf', '185 KB', '19 Oct 2026', 'pdf'),
  file('README.txt', '2 KB', '18 Oct 2026', 'file'),
  file('release-notes.md', '8 KB', '17 Oct 2026', 'code'),
  file('workspace-backup.zip', '148 MB', '15 Oct 2026', 'archive')
];
const initialRight = [
  file('Backups', '—', 'Today, 08:00', 'folder'),
  file('Documents', '—', 'Yesterday', 'folder'),
  file('Shared', '—', '20 Oct 2026', 'folder'),
  file('Websites', '—', '18 Oct 2026', 'folder'),
  file('app-release.zip', '24.6 MB', '19 Oct 2026', 'archive'),
  file('deployment.md', '6 KB', '18 Oct 2026', 'code'),
  file('server-notes.txt', '3 KB', '17 Oct 2026', 'file'),
  file('team-assets.zip', '82.1 MB', '16 Oct 2026', 'archive'),
  file('welcome.pdf', '1.2 MB', '15 Oct 2026', 'pdf')
];
const bindingDefaults = {parent:'⌫',mark:'Space',copy:'F5',move:'F6',folder:'F7',trash:'⌘⌫',copyPath:'⌘⇧C',preview:'⌘Y'};
const actionNames = {parent:'Go to parent folder',mark:'Toggle mark',copy:'Copy to other pane',move:'Move to other pane',folder:'Create folder',trash:'Move to Trash',copyPath:'Copy folder path',preview:'Quick Look'};
const layoutPresets = {a:{font:12,icons:18,rows:31},b:{font:11,icons:16,rows:26},c:{font:13,icons:21,rows:37}};
const descriptions = {
  a:['A · Native balance','A familiar places sidebar, clear file lists, and just the actions you need.'],
  b:['B · Commander compact','More rows and more room for files. Places stay tucked away; shortcuts stay visible.'],
  c:['C · Quiet focus','A slim places rail and more breathing room. Easier to scan, with fewer rows on screen.']
};
const state = {
  layout:'a', active:'left', theme:'light', font:12, icons:18, rows:31,
  advance:true, instant:true, forwardDelete:true, historyBack:false,
  bindings:{...bindingDefaults}, recording:null, settingPage:'appearance',
  panes:{
    left:{path:'/Users/sanjar/Downloads',provider:'local',files:[...initialLeft],marked:new Set(['brand-guidelines.pdf','project-assets.zip','hero-image.png']),cursor:4,history:[]},
    right:{path:'/home/sanjar/files',provider:'sftp',files:[...initialRight],marked:new Set(),cursor:0,history:[]}
  }
};
let toastTimer;
function notify(message) {
  clearTimeout(toastTimer);
  $('#toast-text').textContent = message;
  $('#toast').hidden = false;
  toastTimer = setTimeout(() => { $('#toast').hidden = true; }, 3200);
}
function currentPane() { return state.panes[state.active]; }
function focusedItems() {
  const pane = currentPane();
  return pane.marked.size ? pane.files.filter(item => pane.marked.has(item.name)) : pane.files.slice(pane.cursor, pane.cursor + 1);
}
function setActive(side) {
  state.active = side;
  $$('.pane').forEach(el => el.classList.toggle('is-active', el.dataset.side === side));
  updateSelection();
}
function updateSelection() {
  const pane = currentPane();
  const amount = pane.marked.size;
  $('#selection-summary').innerHTML = amount ? `<strong>${amount} marked</strong> <span>in ${state.active} pane</span>` : '<strong>No marks</strong> <span>· focused item is active</span>';
  for(const side of ['left','right']) {
    const current = state.panes[side];
    $(`#${side}-count`).textContent = `${current.files.length} items${current.marked.size ? ` · ${current.marked.size} marked` : ''}`;
  }
}
function renderPane(side) {
  const pane = state.panes[side];
  pane.cursor = Math.max(0, Math.min(pane.cursor, pane.files.length - 1));
  const list = $(`#${side}-files`);
  list.innerHTML = pane.files.map((item,index) => {
    const marked = pane.marked.has(item.name);
    const glyph = item.type === 'pdf' || item.type === 'code' ? 'file' : item.type;
    return `<div class="file-row ${marked?'marked':''} ${pane.cursor===index?'focused':''}" role="row" aria-selected="${marked}" data-index="${index}" id="${side}-row-${index}">
      <div class="filename" role="gridcell"><button class="mark-button" tabindex="-1" aria-label="${marked?'Unmark':'Mark'} ${escapeText(item.name)}" data-mark="${index}">${icon('check')}</button>${icon(glyph,`file-icon ${item.type}-icon`)}<span class="file-label">${escapeText(item.name)}</span></div>
      <span class="file-size" role="gridcell">${item.size}</span><span class="file-date" role="gridcell">${item.date}</span></div>`;
  }).join('') || '<div class="file-empty">This sample folder is empty.</div>';
  if(pane.files.length) list.setAttribute('aria-activedescendant',`${side}-row-${pane.cursor}`);
  else list.removeAttribute('aria-activedescendant');
  $(`#${side}-path`).value = pane.path;
  $(`#${side}-tab-name`).textContent = pane.path.split('/').filter(Boolean).at(-1) || 'Root';
  $(`[data-side="${side}"] .active-indicator`).textContent = pane.provider === 'local' ? 'Local' : pane.provider === 'smb' ? 'Home NAS' : 'Studio server';
  const badge = $(`[data-side="${side}"] .connection-badge`);
  if(badge) {badge.hidden = pane.provider === 'local'; badge.textContent = pane.provider.toUpperCase();}
  if(side === 'right') $('#right-connection-name').textContent = pane.provider === 'local' ? 'Macintosh HD' : pane.provider === 'smb' ? 'Home NAS' : 'Studio server';
  updateSelection();
}
function toggleMark(side,index,advance = false) {
  const pane = state.panes[side];
  const item = pane.files[index];
  if(!item) return;
  if(pane.marked.has(item.name)) pane.marked.delete(item.name); else pane.marked.add(item.name);
  pane.cursor = advance ? Math.min(index + 1,pane.files.length - 1) : index;
  renderPane(side);
}
function sampleFolder(name) {
  if(name === 'Downloads') return [...initialLeft];
  if(name === 'files') return [...initialRight];
  if(name === 'sanjar') return [file('Desktop','—','Today','folder'),file('Documents','—','Yesterday','folder'),file('Downloads','—','Today','folder'),file('Projects','—','Yesterday','folder')];
  return [file('Assets','—','Today','folder'),file('Notes','—','Yesterday','folder'),file('overview.pdf','2.1 MB','Today','pdf'),file('README.md','4 KB','Yesterday','code')];
}
function navigate(side,path,saveHistory = true) {
  const pane = state.panes[side];
  if(saveHistory) pane.history.push({path:pane.path,provider:pane.provider,files:pane.files,marked:new Set(pane.marked),cursor:pane.cursor});
  pane.path = path;
  pane.files = sampleFolder(path.split('/').filter(Boolean).at(-1));
  pane.marked = new Set(); pane.cursor = 0;
  renderPane(side);
}
function goParent(side) {
  const pane = state.panes[side];
  if(state.historyBack && pane.history.length) {Object.assign(pane,pane.history.pop());renderPane(side);return;}
  const parts = pane.path.split('/').filter(Boolean);
  if(!parts.length) return;
  parts.pop(); navigate(side,'/' + parts.join('/'));
}
function applyAppearance() {
  state.rows = Math.max(state.rows,state.icons + 6,state.font + 10);
  const theme = state.theme === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light') : state.theme;
  for(const el of [$('#app-window'),$('#settings-dialog')]) {
    el.dataset.theme = theme;
    el.style.setProperty('--font-size',state.font+'px');
    el.style.setProperty('--icon-size',state.icons+'px');
    el.style.setProperty('--row-height',state.rows+'px');
  }
  $('#font-size').value=state.font; $('#font-output').textContent=state.font+' px';
  $('#icon-size').value=state.icons; $('#icon-output').textContent=state.icons+' px';
  $('#row-height').value=state.rows; $('#row-output').textContent=state.rows+' px';
  $$('[data-theme-choice]').forEach(button=>button.classList.toggle('active',button.dataset.themeChoice===state.theme));
}
function selectLayout(layout) {
  state.layout=layout;
  Object.assign(state,layoutPresets[layout]);
  $('#app-window').dataset.layout=layout;
  $('#app-window').classList.remove('sidebar-hidden');
  $$('[data-layout-choice]').forEach(button=>button.setAttribute('aria-selected',String(button.dataset.layoutChoice===layout)));
  $('#direction-name').textContent=descriptions[layout][0];
  $('#direction-description').textContent=descriptions[layout][1];
  $('#choose-direction').dataset.choice='layout-'+layout;
  $('#choose-label').textContent='Choose '+layout.toUpperCase();
  $('#choice-status').textContent='Compare layouts above. Settings work in every direction.';
  applyAppearance();
}
function openSettings() {
  state.recording=null;
  $('#settings-dialog').showModal();
  selectSettingPage(state.settingPage);
}
function selectSettingPage(page) {
  state.settingPage=page; state.recording=null;
  $$('[data-setting-page]').forEach(button=>button.setAttribute('aria-selected',String(button.dataset.settingPage===page)));
  $$('.settings-page').forEach(section=>section.hidden=section.id!=='settings-'+page);
  if(page==='shortcuts') renderShortcuts();
}
function syncBehavior() {
  $('#space-behavior').value=state.advance?'advance':'stay';
  $('#backspace-behavior').value=state.historyBack?'history':'parent';
  $('#transfer-behavior').value=state.instant?'instant':'ask';
  $('#forward-delete').checked=state.forwardDelete;
  syncShortcutHints();
}
function syncShortcutHints() {
  $$('[data-shortcut-for]').forEach(el=>{el.textContent=state.bindings[el.dataset.shortcutFor];});
  $('#mark-hint').textContent=state.advance?'Mark & next':'Toggle mark';
  $('#parent-hint').textContent=state.historyBack?'Previous folder':'Parent folder';
}
function renderShortcuts() {
  const query=$('#shortcut-search').value.toLowerCase();
  $('#shortcut-rows').innerHTML=Object.entries(actionNames).filter(([,name])=>name.toLowerCase().includes(query)).map(([id,name])=>`<div class="shortcut-row"><span>${name}</span><button class="shortcut-key ${state.recording===id?'recording':''}" data-record="${id}" aria-label="Change shortcut for ${name}">${state.recording===id?'Press keys…':escapeText(state.bindings[id])}</button></div>`).join('');
}
function keyLabel(event) {
  const aliases={' ':'Space',Backspace:'⌫',Delete:'⌦',ArrowUp:'↑',ArrowDown:'↓',ArrowLeft:'←',ArrowRight:'→',Enter:'↵',Tab:'⇥',Escape:'Esc'};
  return (event.metaKey?'⌘':'')+(event.ctrlKey?'⌃':'')+(event.altKey?'⌥':'')+(event.shiftKey?'⇧':'')+(aliases[event.key]||event.key.toUpperCase());
}
function runAction(action) {
  const pane=currentPane();
  const items=focusedItems();
  const side=state.active;
  if(action==='mark') {toggleMark(side,pane.cursor,state.advance);return;}
  if(action==='parent') {goParent(side);return;}
  if(action==='copyPath') {
    navigator.clipboard.writeText(pane.path).then(()=>notify('Sample folder path copied')).catch(()=>notify('Sample path: '+pane.path));return;
  }
  if(action==='copy'||action==='move') {
    if(!items.length) return;
    const target=side==='left'?'right':'left';
    if(!state.instant) {notify('Preview: destination dialog before '+action);return;}
    const existing=state.panes[target].files;
    if(items.some(item=>existing.some(other=>other.name===item.name))) {notify('Conflict preview: choose Replace, Keep Both, or Skip');return;}
    state.panes[target].files.push(...items.map(item=>({...item})));
    if(action==='move') {const names=new Set(items.map(item=>item.name));pane.files=pane.files.filter(item=>!names.has(item.name));pane.marked.clear();renderPane(side);}
    renderPane(target);notify(`Preview: ${items.length} ${items.length===1?'item':'items'} ${action==='copy'?'copied':'moved'} to ${target} pane`);return;
  }
  if(action==='folder') {notify('Preview: name your new folder');return;}
  if(action==='trash') {notify(pane.provider!=='local'?'Server deletion preview: confirmation is required':`Trash preview: ${items.length} ${items.length===1?'item':'items'} selected`);return;}
  if(action==='preview') {notify(items[0]?'Quick Look preview: '+items[0].name:'Select a file first');return;}
  if(action==='compress') {notify(`ZIP preview: ${items.length} ${items.length===1?'item':'items'} → Archive.zip`);return;}
}
for(const side of ['left','right']) {
  const list=$(`#${side}-files`);
  list.addEventListener('focus',()=>setActive(side));
  list.addEventListener('click',event=>{
    const row=event.target.closest('[data-index]');
    if(!row) return;
    setActive(side);list.focus();
    const index=Number(row.dataset.index);
    if(event.target.closest('[data-mark]')||event.metaKey) toggleMark(side,index);
    else if(event.shiftKey) {const pane=state.panes[side];const start=Math.min(pane.cursor,index);const end=Math.max(pane.cursor,index);for(let i=start;i<=end;i++)pane.marked.add(pane.files[i].name);pane.cursor=index;renderPane(side);}
    else {state.panes[side].cursor=index;renderPane(side);}
  });
  list.addEventListener('dblclick',event=>{const row=event.target.closest('[data-index]');if(!row)return;const item=state.panes[side].files[Number(row.dataset.index)];if(item.type==='folder')navigate(side,state.panes[side].path+'/'+item.name);else runAction('preview');});
  $(`#${side}-parent`).addEventListener('click',()=>{setActive(side);goParent(side);list.focus();});
  $(`#${side}-copy-path`).addEventListener('click',()=>{setActive(side);runAction('copyPath');});
  $(`#${side}-path`).addEventListener('keydown',event=>{if(event.key==='Enter'){const path=event.target.value.trim();if(!path.startsWith('/')){notify('Enter an absolute sample path starting with /');return;}navigate(side,path.replace(/\/$/,'')||'/');list.focus();}if(event.key==='Escape'){event.target.value=state.panes[side].path;list.focus();}});
}
$$('[data-layout-choice]').forEach(button=>button.addEventListener('click',()=>selectLayout(button.dataset.layoutChoice)));
$$('[data-theme-choice]').forEach(button=>button.addEventListener('click',()=>{state.theme=button.dataset.themeChoice;applyAppearance();}));
$$('[data-setting-page]').forEach(button=>button.addEventListener('click',()=>selectSettingPage(button.dataset.settingPage)));
$$('[data-action]').forEach(button=>button.addEventListener('click',()=>runAction(button.dataset.action)));
$('#open-settings').addEventListener('click',openSettings);
$$('[data-close-settings]').forEach(button=>button.addEventListener('click',()=>$('#settings-dialog').close()));
$('#settings-dialog').addEventListener('close',()=>{state.recording=null;});
$('#font-size').addEventListener('input',event=>{state.font=Number(event.target.value);applyAppearance();});
$('#icon-size').addEventListener('input',event=>{state.icons=Number(event.target.value);applyAppearance();});
$('#row-height').addEventListener('input',event=>{state.rows=Number(event.target.value);applyAppearance();});
$('#space-behavior').addEventListener('change',event=>{state.advance=event.target.value==='advance';syncShortcutHints();});
$('#backspace-behavior').addEventListener('change',event=>{state.historyBack=event.target.value==='history';syncShortcutHints();});
$('#transfer-behavior').addEventListener('change',event=>{state.instant=event.target.value==='instant';});
$('#forward-delete').addEventListener('change',event=>{state.forwardDelete=event.target.checked;});
$('#shortcut-search').addEventListener('input',renderShortcuts);
$('#shortcut-rows').addEventListener('click',event=>{const button=event.target.closest('[data-record]');if(!button)return;state.recording=button.dataset.record;$('#shortcut-status').textContent='Press a new shortcut. Esc cancels. Browser and system shortcuts may be reserved.';$('#shortcut-status').classList.remove('error');renderShortcuts();});
$('#restore-defaults').addEventListener('click',()=>{Object.assign(state,layoutPresets[state.layout],{theme:'light',advance:true,instant:true,forwardDelete:true,historyBack:false,bindings:{...bindingDefaults},recording:null});applyAppearance();syncBehavior();renderShortcuts();$('#shortcut-status').textContent='Default shortcuts restored.';});
$('#toggle-sidebar').addEventListener('click',()=>$('#app-window').classList.toggle('sidebar-hidden'));
$('#open-search').addEventListener('click',()=>{notify('Search flow will be explored in the next design screen');});
$$('[data-sample-path]').forEach(button=>button.addEventListener('click',()=>{const side=button.dataset.remote?'right':button.dataset.tabSide||state.active;setActive(side);state.panes[side].provider=button.dataset.remote||'local';navigate(side,button.dataset.samplePath);$(`#${side}-files`).focus();}));
$('#share-button').addEventListener('click',()=>{$('#share-popover').hidden=!$('#share-popover').hidden;});
$('#telegram-share').addEventListener('click',()=>{$('#share-popover').hidden=true;notify('Share preview: continue in Telegram to choose a chat');});
$('#system-share').addEventListener('click',()=>{$('#share-popover').hidden=true;notify('Share preview: macOS sharing options');});
$('#choose-direction').addEventListener('click',()=>{$('#choice-status').textContent='Direction '+state.layout.toUpperCase()+' selected. Tell me your feedback in the chat.';$('#choose-label').textContent=state.layout.toUpperCase()+' selected';});
$$('[data-add-tab]').forEach(button=>button.addEventListener('click',()=>notify('Tab design preview: each pane keeps its own folders')));
document.addEventListener('keydown',event=>{
  if(state.recording) {
    event.preventDefault();
    if(event.key==='Escape'){state.recording=null;renderShortcuts();$('#shortcut-status').textContent='Shortcut change cancelled.';return;}
    if(['Meta','Control','Alt','Shift','Fn'].includes(event.key))return;
    const combo=keyLabel(event);
    const conflict=Object.entries(state.bindings).find(([id,key])=>id!==state.recording&&key===combo);
    if(conflict){$('#shortcut-status').textContent=`Already assigned to “${actionNames[conflict[0]]}”. Try another shortcut, or press Esc.`;$('#shortcut-status').classList.add('error');return;}
    state.bindings[state.recording]=combo;state.recording=null;renderShortcuts();syncShortcutHints();$('#shortcut-status').classList.remove('error');$('#shortcut-status').textContent='Shortcut updated for this preview.';return;
  }
  if($('#settings-dialog').open)return;
  if(event.target.matches('input,textarea,select')||event.target.isContentEditable)return;
  const list=event.target.closest('.file-list');
  if(!list)return;
  const pane=currentPane();
  if(event.metaKey&&event.key===','){event.preventDefault();openSettings();return;}
  if(event.key==='ArrowUp'||event.key==='ArrowDown') {event.preventDefault();pane.cursor=Math.max(0,Math.min(pane.files.length-1,pane.cursor+(event.key==='ArrowUp'?-1:1)));renderPane(state.active);$(`#${state.active}-row-${pane.cursor}`)?.scrollIntoView({block:'nearest'});return;}
  if(event.key==='Tab'){event.preventDefault();const next=state.active==='left'?'right':'left';setActive(next);$(`#${next}-files`).focus();return;}
  if(event.metaKey&&event.key.toLowerCase()==='a'){event.preventDefault();pane.files.forEach(item=>pane.marked.add(item.name));renderPane(state.active);return;}
  if(event.key==='Escape'){event.preventDefault();pane.marked.clear();renderPane(state.active);return;}
  if(event.key==='Enter'){event.preventDefault();const item=pane.files[pane.cursor];if(item?.type==='folder')navigate(state.active,pane.path+'/'+item.name);else runAction('preview');return;}
  if(event.key==='Delete'&&state.forwardDelete){event.preventDefault();runAction('trash');return;}
  const match=Object.entries(state.bindings).find(([,key])=>key===keyLabel(event));
  if(match){event.preventDefault();runAction(match[0]);}
});
renderPane('left');renderPane('right');applyAppearance();syncBehavior();
