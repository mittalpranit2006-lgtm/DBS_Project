export function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === 'class') node.className = value;
    else if (key === 'text') node.textContent = value ?? '';
    else if (key === 'value') node.value = value ?? '';
    else if (key === 'checked') node.checked = !!value;
    else if (key.startsWith('on') && typeof value === 'function') node.addEventListener(key.slice(2), value);
    else if (value !== null && value !== undefined) node.setAttribute(key, String(value));
  }
  for (const child of children.flat()) if (child != null) node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  return node;
}
export function clear(node, ...children) { node.replaceChildren(...children); return node; }
export function button(label, click, variant = 'quiet', small = false) {
  return el('button', { type: 'button', class: `button button-${variant}${small ? ' button-small' : ''}`, onclick: click }, label);
}
export function state(kind, title, detail = '') {
  return el('div', { class: `${kind}-card`, role: kind === 'error' ? 'alert' : 'status' },
    el('strong', {}, title), detail ? el('span', {}, detail) : null);
}
export function table(columns, rows, actions) {
  if (!rows.length) return state('empty', 'No records found', 'Try another search or add a record.');
  return el('div', { class: 'table-wrap' }, el('table', {},
    el('thead', {}, el('tr', {}, ...columns.map(c => el('th', { scope: 'col' }, c.label)), actions ? el('th', { scope: 'col' }, 'Actions') : null)),
    el('tbody', {}, ...rows.map(row => el('tr', {},
      ...columns.map(c => el('td', {}, String(c.display ? c.display(row[c.key], row) : row[c.key] ?? '—'))),
      actions ? el('td', { class: 'actions' }, ...actions(row)) : null)))));
}
export const money = value => value == null ? '—' : new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(Number(value));
export const dateText = value => value ? String(value).replace('T', ' ').slice(0, 19) : '—';
export const today = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`; };
export const nowLocal = () => { const d = new Date(); return `${today()}T${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`; };
export function field(name, label, type = 'text', value = '', options = [], required = true) {
  const id = 'field-' + name;
  const input = type === 'select'
    ? el('select', { id, name, required: required ? '' : null }, el('option', { value: '' }, 'Choose…'), ...options.map(o => el('option', { value: o.value }, o.label)))
    : el('input', { id, name, type, value: value == null ? '' : String(value), required: required ? '' : null,
        step: type === 'number' ? (/Id$|year/i.test(name) ? '1' : '0.01') : null });
  if (type === 'select') input.value = value == null ? '' : String(value);
  return el('div', { class: 'field' }, el('label', { for: id }, label), input);
}
