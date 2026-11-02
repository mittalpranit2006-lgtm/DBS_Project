import { request, query } from './api.js';
import { el, clear, button, state, table, money, dateText, today, nowLocal, field } from './ui.js';

const main = document.querySelector('#main');
const notice = document.querySelector('#notice');
const dialog = document.querySelector('#record-dialog');
const form = document.querySelector('#record-form');
const fieldsBox = document.querySelector('#dialog-fields');
const dialogError = document.querySelector('#dialog-error');
const submitButton = document.querySelector('#dialog-submit');
const titles = { dashboard: 'Dashboard', customers: 'Customers & phones', fleet: 'Fleet & organization', rentals: 'Rentals & returns', payments: 'Payments & reports' };
const viewState = { screen: 'dashboard', fleet: 'vehicles', limit: 50, search: '', rentalStatus: '', rentalCustomer: '', rentalVehicle: '', paymentRental: '', selected: null };
let generation = 0;

const config = {
  customers: { title: 'Customers', id: 'customerId', columns: ['customerId','firstName','lastName','email','licenseNo'], fields: [
    ['firstName','First name'],['lastName','Last name'],['email','Email','email'],['licenseNo','Licence number'],['address','Address'],['registrationDate','Registration date','date'] ] },
  'vehicle-types': { title: 'Vehicle types', id: 'typeId', columns: ['typeId','typeName','dailyRate','securityDeposit'], fields: [
    ['typeName','Type name'],['dailyRate','Daily rate','number'],['securityDeposit','Security deposit','number'] ] },
  branches: { title: 'Branches', id: 'branchId', columns: ['branchId','branchName','location','phone'], fields: [
    ['branchName','Branch name'],['location','Location'],['phone','Phone','tel'] ] },
  vehicles: { title: 'Vehicles', id: 'vehicleId', columns: ['vehicleId','registrationNo','brand','model','availabilityStatus','typeId','branchId'], fields: [
    ['registrationNo','Registration number'],['brand','Brand'],['model','Model'],['purchaseYear','Purchase year','number'],
    ['availabilityStatus','Availability','select','statuses'],['typeId','Vehicle type','select','types'],['branchId','Branch','select','branches'] ] },
  employees: { title: 'Employees', id: 'employeeId', columns: ['employeeId','name','email','phone','role','branchId'], fields: [
    ['name','Name'],['email','Email','email'],['phone','Phone','tel'],['role','Role'],['branchId','Branch','select','branches'] ] }
};
const label = key => key.replace(/([A-Z])/g, ' $1').replace(/^./, c => c.toUpperCase());
const singular = kind => ({customers:'customer',branches:'branch',vehicles:'vehicle',employees:'employee','vehicle-types':'vehicle type'})[kind];
const dateValue = value => value ? String(value).slice(0,10) : '';
const timestamp = value => value ? (value.length === 16 ? value + ':00' : value.slice(0,19)) : '';
const refresh = () => render();
function flash(message, error = false) { notice.textContent = message; notice.classList.toggle('error', error); notice.hidden = false; }
function hideNotice() { notice.hidden = true; }
function askConfirm(message) {
  const box = document.querySelector('#confirm-dialog');
  document.querySelector('#confirm-message').textContent = message;
  return new Promise(resolve => {
    const finish = answer => { box.close(); resolve(answer); };
    document.querySelector('#confirm-cancel').onclick = () => finish(false);
    document.querySelector('#confirm-accept').onclick = () => finish(true);
    box.oncancel = event => { event.preventDefault(); finish(false); };
    box.showModal();
    document.querySelector('#confirm-cancel').focus();
  });
}
function section(title, description, ...actions) { return el('div', { class: 'section-heading' }, el('div', {}, el('h2', {}, title), el('p', {}, description)), el('div', { class: 'section-actions' }, ...actions)); }
function card(title, ...content) { return el('section', { class: 'card card-pad' }, el('h3', {}, title), ...content); }
function detail(row) { return el('dl', { class: 'detail-grid' }, ...Object.entries(row).map(([key, value]) => el('div', {}, el('dt', {}, label(key)), el('dd', {}, /amount|rate|deposit|balance/i.test(key) ? money(value) : /date/i.test(key) ? dateText(value) : String(value ?? '—'))))); }
function asColumns(keys) { return keys.map(key => ({ key, label: label(key), display: value => /amount|rate|deposit|balance/i.test(key) ? money(value) : /date/i.test(key) ? dateText(value) : value ?? '—' })); }
function linkList(items, idKey, name) { return items.map(row => ({ value: row[idKey], label: `${row[idKey]} · ${row[name]}` })); }
async function choices() {
  const [types, branches] = await Promise.all([request('/vehicle-types?limit=100'), request('/branches?limit=100')]);
  return { types: linkList(types.items,'typeId','typeName'), branches: linkList(branches.items,'branchId','branchName'), statuses: ['Available','Rented','Maintenance'].map(value => ({ value, label: value })) };
}
function openDialog(title, fields, onSave, submitText = 'Save') {
  document.querySelector('#dialog-title').textContent = title;
  clear(fieldsBox, ...fields);
  dialogError.hidden = true;
  submitButton.textContent = submitText;
  submitButton.disabled = false;
  form.onsubmit = async event => {
    event.preventDefault();
    if (submitButton.disabled) return;
    if (!form.reportValidity()) return;
    const values = Object.fromEntries(new FormData(form).entries());
    submitButton.disabled = true;
    dialogError.hidden = true;
    try { await onSave(values); dialog.close(); refresh(); }
    catch (error) { dialogError.textContent = error.message; dialogError.hidden = false; }
    finally { submitButton.disabled = false; }
  };
  dialog.showModal();
  fieldsBox.querySelector('input,select')?.focus();
}
document.querySelector('#dialog-close').onclick = () => dialog.close();
document.querySelector('#dialog-cancel').onclick = () => dialog.close();
document.querySelector('#refresh-page').onclick = refresh;
document.querySelector('#primary-nav').addEventListener('click', event => {
  const target = event.target.closest('[data-screen]'); if (!target) return;
  viewState.screen = target.dataset.screen; viewState.selected = null; viewState.search = ''; hideNotice(); render();
});
function nav() {
  document.querySelector('#page-title').textContent = titles[viewState.screen];
  document.querySelectorAll('[data-screen]').forEach(button => button.setAttribute('aria-current', button.dataset.screen === viewState.screen ? 'page' : 'false'));
}
async function render() {
  const ticket = ++generation; nav(); clear(main, state('loading', 'Loading records…'));
  try {
    const view = await ({ dashboard, customers: () => master('customers'), fleet, rentals, payments })[viewState.screen]();
    if (ticket === generation) clear(main, view);
  } catch (error) { if (ticket === generation) clear(main, state('error', 'Could not load this view', error.message)); }
}
async function databaseStatus() {
  try {
    const db = await request('/health/database');
    document.querySelector('#connection-label').textContent = `${db.account} · ${db.pdb}`;
    document.querySelector('.sidebar-foot').className = 'sidebar-foot ok';
    document.querySelector('#db-pill').textContent = 'Database connected';
    document.querySelector('#db-pill').className = 'pill';
  } catch {
    document.querySelector('#connection-label').textContent = 'Database unavailable';
    document.querySelector('.sidebar-foot').className = 'sidebar-foot error';
    document.querySelector('#db-pill').textContent = 'Database unavailable';
    document.querySelector('#db-pill').className = 'pill error';
  }
}
async function dashboard() {
  const [, d] = await Promise.all([databaseStatus(), request('/dashboard')]);
  const metrics = [['Customers',d.customerCount],['Vehicles',d.vehicleCount],['Active rentals',d.activeRentals],['Cash collected',money(d.cashCollected)]];
  return el('div', {}, section('Operations overview','Live totals from the project database.'),
    el('div', { class: 'metrics' }, ...metrics.map(([name, value]) => el('div', { class: 'card metric' }, el('span', { class: 'label' }, name), el('strong', {}, String(value))))),
    el('div', { class: 'grid grid-2' },
      card('Fleet availability', el('p', {}, `${d.availableVehicles} of ${d.vehicleCount} vehicles are available.`), button('View vehicles', () => { viewState.screen='fleet'; viewState.fleet='vehicles'; render(); })),
      card('Rental activity', el('p', {}, `${d.rentalCount} total rentals · ${d.overdueRentals} currently overdue · ${d.paymentCount} payments recorded.`), button('View rentals', () => { viewState.screen='rentals'; render(); }))));
}
function toolbar(searchValue, onSearch) {
  const searchInput = field('search', 'Search', 'search', searchValue, [], false);
  searchInput.classList.add('grow');
  const limit = field('limit', 'Show up to', 'select', viewState.limit, [10,25,50,100].map(n => ({ value:n, label:String(n) })));
  limit.querySelector('select').onchange = e => { viewState.limit = Number(e.target.value); render(); };
  return el('form', { class: 'toolbar', onsubmit: e => { e.preventDefault(); onSearch(searchInput.querySelector('input').value.trim()); } }, searchInput, button('Search', () => onSearch(searchInput.querySelector('input').value.trim()), 'primary'), limit);
}
async function master(kind) {
  const cfg = config[kind];
  const results = await request(`/${kind}${query({q:viewState.search,limit:viewState.limit})}`);
  const root = el('div', {}, section(cfg.title, 'Search, inspect and maintain project records.', button('Add ' + singular(kind), () => editMaster(kind), 'primary')));
  root.append(toolbar(viewState.search, value => {viewState.search=value;viewState.selected=null;render();}));
  root.append(table(asColumns(cfg.columns), results.items, row => [button('View', () => showMasterDetail(kind,row[cfg.id]), 'quiet', true), button('Edit', () => editMaster(kind,row), 'quiet', true), button('Delete', () => deleteMaster(kind,row), 'danger', true)]));
  root.append(el('p', { class:'table-caption' }, `Showing up to ${viewState.limit} records. Search narrows the results; this API does not offer page offsets.`));
  if (viewState.selected?.kind === kind) root.append(await masterDetail(kind,viewState.selected.id));
  return root;
}
async function fleet() {
  const root = el('div', {}, el('div', { class:'subnav', role:'group', 'aria-label':'Fleet sections' },
    ...['vehicles','vehicle-types','branches','employees'].map(kind => button(config[kind].title, () => {viewState.fleet=kind;viewState.search='';viewState.selected=null;render();}, viewState.fleet===kind?'primary':'quiet'))));
  root.append(await master(viewState.fleet)); return root;
}
async function masterDetail(kind,id) {
  const row = await request(`/${kind}/${id}`);
  const root = card(`${config[kind].title} · ${id}`, detail(row)); root.classList.add('detail-card');
  if (kind === 'customers') {
    const phones = await request(`/customers/${id}/phones`);
    root.append(el('h4', {class:'subheading'}, 'Phone numbers'), button('Add phone', () => editPhone(id), 'primary', true),
      phones.items.length ? el('ul', {class:'inline-list'}, ...phones.items.map(p => el('li', {}, el('span', {}, p.phoneNo), el('div', {},
        button('Edit', () => editPhone(id,p.phoneNo), 'quiet', true), button('Remove', () => deletePhone(id,p.phoneNo), 'danger', true))))) : state('empty','No phone numbers'));
  }
  return root;
}
function showMasterDetail(kind,id) { viewState.selected={kind,id}; render(); }
async function editMaster(kind, row) {
  const cfg = config[kind];
  try {
    const opts = (kind === 'vehicles' || kind === 'employees') ? await choices() : {};
    const fields = [row ? null : field(cfg.id, label(cfg.id), 'number'),
      ...cfg.fields.map(([name, title, type='text', optionKey]) => field(name,title,type,
        name.endsWith('Date') && type==='date' ? dateValue(row?.[name]) || today() : row?.[name] ?? (name==='availabilityStatus' ? 'Available' : ''),
        type==='select' ? opts[optionKey] : []))].filter(Boolean);
    openDialog(`${row ? 'Edit' : 'Add'} ${singular(kind)}`, fields, async values => {
      const body = {};
      for (const [name,,type] of cfg.fields) body[name] = type==='number' || /Id$/.test(name) ? Number(values[name]) : values[name];
      if (!row) body[cfg.id]=Number(values[cfg.id]);
      await request(row ? `/${kind}/${row[cfg.id]}` : `/${kind}`, {method:row?'PUT':'POST',body});
      if (!row) viewState.search = '';
      flash(`${cfg.title} record ${row ? 'updated' : 'created'}.`);
    });
  } catch (error) { flash(error.message,true); }
}
async function deleteMaster(kind,row) {
  const cfg=config[kind];
  if (!await askConfirm(`Delete ${cfg.title.toLowerCase()} #${row[cfg.id]}? Referenced records cannot be deleted.`)) return;
  try { await request(`/${kind}/${row[cfg.id]}`,{method:'DELETE'}); viewState.selected=null; flash('Record deleted.'); render(); }
  catch (error) { flash(error.message,true); }
}
function editPhone(customerId, oldPhone) {
  openDialog(oldPhone?'Edit phone':'Add phone', [field('phoneNo','Phone number','tel',oldPhone||'')], async values => {
    const path=`/customers/${customerId}/phones`+(oldPhone?`/${encodeURIComponent(oldPhone)}`:'');
    await request(path,{method:oldPhone?'PUT':'POST',body:oldPhone?{newPhoneNo:values.phoneNo}:{phoneNo:values.phoneNo}});
    flash('Phone number saved.');
  });
}
async function deletePhone(customerId,phone) {
  if (!await askConfirm(`Remove phone ${phone}?`)) return;
  try { await request(`/customers/${customerId}/phones/${encodeURIComponent(phone)}`,{method:'DELETE'}); flash('Phone removed.'); render(); }
  catch(error){flash(error.message,true);}
}

async function rentals() {
  const result = await request('/rentals' + query({customerId:viewState.rentalCustomer,vehicleId:viewState.rentalVehicle,status:viewState.rentalStatus,limit:viewState.limit}));
  const root = el('div', {}, section('Rentals', 'Historical records are read only. Start and return actions use the installed Oracle workflow.', button('Start rental', startRental, 'primary')));
  const customer = field('rentalCustomer','Customer ID','number',viewState.rentalCustomer,[],false);
  const vehicle = field('rentalVehicle','Vehicle ID','number',viewState.rentalVehicle,[],false);
  const status = field('rentalStatus','Status','select',viewState.rentalStatus,['Active','Completed','Cancelled'].map(value=>({value,label:value})),false);
  const limit = field('rentalLimit','Show up to','select',viewState.limit,[10,25,50,100].map(n=>({value:n,label:String(n)})));
  root.append(el('form',{class:'toolbar',onsubmit:e=>{e.preventDefault();viewState.rentalCustomer=customer.querySelector('input').value;viewState.rentalVehicle=vehicle.querySelector('input').value;viewState.rentalStatus=status.querySelector('select').value;viewState.limit=Number(limit.querySelector('select').value);viewState.selected=null;render();}},customer,vehicle,status,limit,el('button',{type:'submit',class:'button button-primary'},'Filter')));
  root.append(table(asColumns(['rentalId','customerId','vehicleId','startDate','expectedReturnDate','statusName','totalAmount']),result.items,row=>[
    button('View',()=>{viewState.selected={kind:'rental',id:row.rentalId};render();},'quiet',true),
    row.statusName==='Active'?button('Return',()=>returnRental(row),'primary',true):null]));
  root.append(el('p',{class:'table-caption'},`Showing up to ${viewState.limit} rentals.`));
  if(viewState.selected?.kind==='rental') root.append(await rentalDetail(viewState.selected.id));
  return root;
}
async function rentalDetail(id) {
  const row=await request(`/rentals/${id}`);
  const root=card(`Rental · ${id}`,detail(row));root.classList.add('detail-card');
  const balance=await request('/reports/outstanding'+query({rentalId:id}));
  root.append(el('p',{},`Outstanding balance: ${money(balance.outstandingBalance)}`));
  if(row.statusName==='Active')root.append(button('Record return',()=>returnRental(row),'primary'));
  return root;
}
async function startRental() {
  try {
    const [customers,vehicles,employees,types]=await Promise.all([
      request('/customers?limit=100'),request('/vehicles?limit=100'),request('/employees?limit=100'),request('/vehicle-types?limit=100')]);
    const available=vehicles.items.filter(v=>v.availabilityStatus==='Available');
    const vehicleOptions=available.map(v=>({value:v.vehicleId,label:`${v.vehicleId} · ${v.registrationNo} · ${v.brand} ${v.model}`}));
    const start=field('startDate','Start (local date and time)','datetime-local',nowLocal());
    const expected=field('expectedReturnDate','Expected return (local date and time)','datetime-local','');
    const vehicle=field('vehicleId','Available vehicle','select','',vehicleOptions);
    const estimate=el('p',{class:'hint',role:'status'},'Select a vehicle and dates to see the database charge estimate.');
    const rateByType=new Map(types.items.map(t=>[String(t.typeId),t.dailyRate]));
    const vehicleById=new Map(vehicles.items.map(v=>[String(v.vehicleId),v]));
    let estimateTicket=0;
    const updateEstimate=async()=>{
      const ticket=++estimateTicket;
      const v=vehicleById.get(vehicle.querySelector('select').value);
      const a=start.querySelector('input').value,b=expected.querySelector('input').value;
      if(!v||!a||!b){estimate.textContent='Select a vehicle and dates to see the database charge estimate.';return;}
      try {const result=await request('/reports/charge-estimate'+query({start:timestamp(a),end:timestamp(b),rate:rateByType.get(String(v.typeId))}));if(ticket===estimateTicket)estimate.textContent=`Estimated rental charge: ${money(result.charge)}. Final charge is calculated when the vehicle is returned.`;}
      catch(error){if(ticket===estimateTicket)estimate.textContent=`Estimate unavailable: ${error.message}`;}
    };
    [vehicle,start,expected].forEach(group=>group.querySelector('input,select').addEventListener('change',updateEstimate));
    openDialog('Start rental',[
      field('customerId','Customer','select','',linkList(customers.items,'customerId','firstName')),
      vehicle,field('employeeId','Employee','select','',linkList(employees.items,'employeeId','name')),start,expected,estimate],async values=>{
        if(timestamp(values.expectedReturnDate)<=timestamp(values.startDate))throw new Error('Expected return must follow start.');
        const created=await request('/rentals/start',{method:'POST',body:{customerId:Number(values.customerId),vehicleId:Number(values.vehicleId),employeeId:Number(values.employeeId),startDate:timestamp(values.startDate),expectedReturnDate:timestamp(values.expectedReturnDate)}});
        if (created.rolledBack) flash(`Rental start validated as #${created.rentalId}; test transaction rolled back.`);
        else { viewState.selected={kind:'rental',id:created.rentalId}; flash(`Rental #${created.rentalId} started.`); }
      },'Start rental');
  } catch(error){flash(error.message,true);}
}
function returnRental(row) {
  openDialog(`Return rental #${row.rentalId}`,[field('actualReturnDate','Actual return (local date and time)','datetime-local',nowLocal())],async values=>{
    const returned=await request(`/rentals/${row.rentalId}/return`,{method:'POST',body:{actualReturnDate:timestamp(values.actualReturnDate)}});
    viewState.selected={kind:'rental',id:row.rentalId};
    flash(returned.rolledBack ? `Return validated with final charge ${money(returned.finalAmount ?? returned.totalAmount)}; test transaction rolled back.` : `Return recorded. Final charge: ${money(returned.finalAmount ?? returned.totalAmount)}.`);
  },'Record return');
}

async function payments() {
  const [result,cash,recognized,overdue]=await Promise.all([
    request('/payments'+query({rentalId:viewState.paymentRental,limit:viewState.limit})),
    request('/reports/revenue'+query({basis:'cash',limit:viewState.limit})),
    request('/reports/revenue'+query({basis:'recognized',limit:viewState.limit})),
    request('/reports/overdue'+query({asOf:timestamp(nowLocal()),limit:viewState.limit}))]);
  const root=el('div',{},section('Payments & reports','Completed payments count toward cash revenue; completed rental bills count toward recognized revenue.',button('Record payment',recordPayment,'primary')));
  const rental=field('paymentRental','Rental ID','number',viewState.paymentRental,[],false);
  const limit=field('paymentLimit','Show up to','select',viewState.limit,[10,25,50,100].map(n=>({value:n,label:String(n)})));
  root.append(el('form',{class:'toolbar',onsubmit:e=>{e.preventDefault();viewState.paymentRental=rental.querySelector('input').value;viewState.limit=Number(limit.querySelector('select').value);viewState.selected=null;render();}},rental,limit,el('button',{type:'submit',class:'button button-primary'},'Filter')));
  root.append(card('Payment history',table(asColumns(['paymentId','rentalId','amount','paymentMethod','paymentDate','paymentStatus']),result.items,row=>[button('View',()=>{viewState.selected={kind:'payment',id:row.paymentId};render();},'quiet',true)])));
  if(viewState.selected?.kind==='payment'){
    const row=await request(`/payments/${viewState.selected.id}`);
    const balance=await request('/reports/outstanding'+query({rentalId:row.rentalId}));
    const panel=card(`Payment · ${row.paymentId}`,detail(row),el('p',{},`Rental #${row.rentalId} outstanding: ${money(balance.outstandingBalance)}`));panel.classList.add('detail-card');root.append(panel);
  }
  root.append(el('div',{class:'grid grid-2'},
    card('Cash collected by branch',table(asColumns(['branchId','branchName','amount','recordCount']),cash.items)),
    card('Recognized rental charges by branch',table(asColumns(['branchId','branchName','amount','recordCount']),recognized.items))));
  root.append(card('Overdue rentals',el('p',{},`${overdue.count} active rentals overdue as of ${dateText(overdue.asOf)}. Estimated outstanding: ${money(overdue.estimatedOutstanding)}.`),
    table(asColumns(['rentalId','customerId','vehicleId','expectedReturnDate','estimatedBalance']),overdue.items)));
  return root;
}
async function recordPayment() {
  try{
    const rentals=await request('/rentals?limit=100');
    openDialog('Record payment',[
      field('rentalId','Rental','select',viewState.paymentRental,rentals.items.filter(r=>r.statusName!=='Cancelled').map(r=>({value:r.rentalId,label:`${r.rentalId} · ${r.statusName} · ${money(r.totalAmount)}`}))),
      field('amount','Amount (INR)','number'),
      field('paymentMethod','Payment method','select','',["Card","UPI","Cash","Bank Transfer"].map(value=>({value,label:value}))),
      field('paymentDate','Payment date and time (local)','datetime-local',nowLocal())],async values=>{
        const created=await request('/payments',{method:'POST',body:{rentalId:Number(values.rentalId),amount:Number(values.amount),paymentMethod:values.paymentMethod,paymentDate:timestamp(values.paymentDate)}});
        if (created.rolledBack) flash(`Payment validated as #${created.paymentId}; test transaction rolled back.`);
        else { viewState.selected={kind:'payment',id:created.paymentId};flash(`Payment #${created.paymentId} recorded.`); }
      },'Record payment');
  }catch(error){flash(error.message,true);}
}

render();
