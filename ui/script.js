let Locales = {};

function _T(key, ...args) {
    if (!Locales || Object.keys(Locales).length === 0) return key;
    let str = Locales[key] || key;
    if (args.length) {
        let i = 0;
        str = str.replace(/%[sd]/g, () => {
            const val = args[i++];
            return val !== undefined && val !== null ? String(val) : '';
        });
    }
    return str;
}

function updateUIText(root) {
    const scope = root || document;
    scope.querySelectorAll('[data-locale]').forEach(el => {
        const key = el.getAttribute('data-locale');
        if (key) el.textContent = _T(key);
    });
}

async function loadLocales() {
    try {
        const result = await nuiFetch('cityrentals:getLocales');
        if (result && result.locales) {
            Locales = result.locales;
            updateUIText();
        }
    } catch (e) {}
}

function getResourceName() {
    if (globalThis.resourceName) return globalThis.resourceName;
    if (typeof GetParentResourceName === 'function') return GetParentResourceName();
    return 'm-carrental';
}

async function nuiFetch(event, data) {
    if (typeof globalThis.fetchNui === 'function') {
        const result = await globalThis.fetchNui(event, data);
        if (result !== undefined) return result;
    }
    const res = await fetch(`https://${getResourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data ?? {}),
    });
    if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
    return res.json();
}

const State = {
    catalog: null,
    category: 'all',
    selectedVehicle: null,
    durationType: 'hour',
    durationValue: 1,
    paymentMethod: 'bank',
    renewDurationType: 'hour',
    renewDurationValue: 1,
    renewPayment: 'bank',
    activeRental: null,
    tab: 'browse',
};

function $(id) { return document.getElementById(id); }

function showToast(msg) {
    const t = $('toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(t._t);
    t._t = setTimeout(() => t.classList.remove('show'), 2800);
}

function formatMoney(n) {
    return '$' + Number(n || 0).toLocaleString('en-US');
}

function calcPrice(vehicle, durationType, durationValue) {
    if (!vehicle || !vehicle.prices) return 0;
    const unit = vehicle.prices[durationType] || vehicle.prices.minute || 0;
    return Math.floor(unit * Math.max(1, Number(durationValue) || 1));
}

function categoryLabel(id) {
    const cat = (State.catalog?.categories || []).find(c => c.id === id);
    return cat ? cat.label : id;
}

function setTab(tab) {
    State.tab = tab;
    document.querySelectorAll('.nav-item').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
    if (tab === 'browse') {
        $('view-browse').classList.add('active');
    } else if (tab === 'active') {
        $('view-active').classList.add('active');
        refreshActive();
    } else if (tab === 'history') {
        $('view-history').classList.add('active');
        loadHistory();
    }
}

const CATEGORY_DRAG_THRESHOLD = 10;

function initCategoryScroll() {
    const row = $('category-row');
    if (!row || row._scrollReady) return;
    row._scrollReady = true;

    const endDrag = () => {
        row.classList.remove('is-dragging');
        row._drag = null;
    };

    row.addEventListener('pointerdown', (e) => {
        if (e.button !== 0) return;
        row._drag = {
            startX: e.clientX,
            startY: e.clientY,
            scrollLeft: row.scrollLeft,
            dragging: false,
        };
    });

    row.addEventListener('pointermove', (e) => {
        const d = row._drag;
        if (!d) return;

        const dx = e.clientX - d.startX;
        const dy = e.clientY - d.startY;

        if (!d.dragging) {
            if (Math.abs(dx) < CATEGORY_DRAG_THRESHOLD && Math.abs(dy) < CATEGORY_DRAG_THRESHOLD) return;
            if (Math.abs(dy) > Math.abs(dx)) {
                row._drag = null;
                return;
            }
            d.dragging = true;
            row.classList.add('is-dragging');
        }

        e.preventDefault();
        row.scrollLeft = d.scrollLeft - dx;
    });

    row.addEventListener('pointerup', (e) => {
        const d = row._drag;
        if (!d) return;

        if (!d.dragging) {
            const chip = e.target.closest('.cat-chip');
            if (chip && chip.dataset.id) {
                selectCategory(chip.dataset.id, chip);
            }
        }

        endDrag();
    });

    row.addEventListener('pointercancel', endDrag);
}

function selectCategory(catId, chipEl) {
    State.category = catId;
    renderCategories();
    renderVehicles();
    if (chipEl) {
        chipEl.blur();
        chipEl.scrollIntoView({ behavior: 'smooth', inline: 'nearest', block: 'nearest' });
    }
}

function renderCategories() {
    const row = $('category-row');
    row.innerHTML = '';
    (State.catalog?.categories || []).forEach(cat => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.dataset.id = cat.id;
        btn.className = 'cat-chip' + (State.category === cat.id ? ' active' : '');
        btn.textContent = cat.label;
        row.appendChild(btn);
    });
}

function renderVehicles() {
    const grid = $('vehicle-grid');
    const vehicles = State.catalog?.vehicles || [];
    const filtered = State.category === 'all'
        ? vehicles
        : vehicles.filter(v => v.category === State.category);

    if (!filtered.length) {
        grid.innerHTML = `<div class="loading">${_T('no_vehicles_category')}</div>`;
        return;
    }

    grid.innerHTML = filtered.map(v => `
        <article class="vehicle-card">
            <div class="vehicle-image">
                <img src="${v.image}" alt="${v.label}" onerror="this.parentElement.style.display='none'" />
            </div>
            <div class="vehicle-card-body">
                <h3>${v.label}</h3>
                <div class="vehicle-meta">
                    <span class="badge">${categoryLabel(v.category)}</span>
                    <span class="price-tag">${_T('price_from_hr', formatMoney(v.prices?.hour || v.prices?.minute))}</span>
                </div>
                <button class="btn-rent" data-key="${v.key}">${_T('btn_rent')}</button>
            </div>
        </article>
    `).join('');

    grid.querySelectorAll('.btn-rent').forEach(btn => {
        btn.onclick = () => openRent(btn.dataset.key);
    });
}

function formatChipLabel(item) {
    if (item.label) return item.label;
    const id = String(item.id || '');
    return id.charAt(0).toUpperCase() + id.slice(1);
}

function paymentMethodItems() {
    return (State.catalog?.paymentMethods || ['bank', 'cash']).map(p => ({
        id: p,
        label: p === 'bank' ? _T('payment_bank') : p === 'cash' ? _T('payment_cash') : formatChipLabel({ id: p }),
    }));
}

function renderChips(containerId, items, getSelected, setSelected, onChange) {
    const el = $(containerId);
    if (!el) return;
    const list = items || [];
    el.innerHTML = '';

    list.forEach(item => {
        const chip = document.createElement('button');
        chip.type = 'button';
        chip.dataset.id = item.id;
        chip.textContent = formatChipLabel(item);

        const syncActive = () => {
            const selected = getSelected();
            el.querySelectorAll('.chip').forEach(node => {
                node.classList.toggle('active', node.dataset.id === selected);
            });
        };

        chip.className = 'chip' + (getSelected() === item.id ? ' active' : '');
        chip.addEventListener('click', () => {
            setSelected(item.id);
            syncActive();
            if (onChange) onChange(item.id);
        });
        el.appendChild(chip);
    });
}

function paintRentDurationChips() {
    renderChips(
        'duration-units',
        State.catalog?.durationUnits || [],
        () => State.durationType,
        id => { State.durationType = id; },
        () => updateRentTotal()
    );
}

function paintRentPaymentChips() {
    renderChips(
        'payment-methods',
        paymentMethodItems(),
        () => State.paymentMethod,
        id => { State.paymentMethod = id; }
    );
}

function paintRenewDurationChips() {
    renderChips(
        'renew-units',
        State.catalog?.durationUnits || [],
        () => State.renewDurationType,
        id => { State.renewDurationType = id; }
    );
}

function paintRenewPaymentChips() {
    renderChips(
        'renew-payment',
        paymentMethodItems(),
        () => State.renewPayment,
        id => { State.renewPayment = id; }
    );
}

function openRent(vehicleKey) {
    const vehicle = (State.catalog?.vehicles || []).find(v => v.key === vehicleKey);
    if (!vehicle) return;
    State.selectedVehicle = vehicle;
    State.durationType = 'hour';
    State.durationValue = 1;
    State.paymentMethod = 'bank';

    $('view-browse').classList.remove('active');
    $('view-rent').classList.add('active');

    $('rent-hero').innerHTML = `
        <div class="vehicle-image">
            <img src="${vehicle.image}" alt="${vehicle.label}" onerror="this.parentElement.style.display='none'" />
        </div>`;
    $('rent-title').textContent = vehicle.label;

    paintRentDurationChips();
    paintRentPaymentChips();

    $('duration-value').value = State.durationValue;
    $('duration-value').oninput = () => {
        State.durationValue = Math.max(1, parseInt($('duration-value').value, 10) || 1);
        updateRentTotal();
    };

    updateRentTotal();
}

function updateRentTotal() {
    if (!State.selectedVehicle) return;
    $('rent-total').textContent = formatMoney(calcPrice(State.selectedVehicle, State.durationType, State.durationValue));
}

function closeRent() {
    $('view-rent').classList.remove('active');
    $('view-browse').classList.add('active');
    State.selectedVehicle = null;
}

async function confirmRent() {
    if (!State.selectedVehicle) return;
    const btn = $('btn-confirm-rent');
    btn.disabled = true;
    btn.textContent = _T('btn_processing');

    try {
        const res = await nuiFetch('cityrentals:createRental', {
            vehicleKey: State.selectedVehicle.key,
            durationType: State.durationType,
            durationValue: State.durationValue,
            paymentMethod: State.paymentMethod,
        });

        if (!res?.success) {
            showToast(res?.message || _T('toast_rental_failed'));
            return;
        }

        showToast(res.message || _T('toast_delivery_way'));
        State.activeRental = res.rental;
        updateDeliveryBanner(true);
        closeRent();
        setTab('active');
    } catch (e) {
        showToast(_T('toast_connection_error'));
    } finally {
        btn.disabled = false;
        btn.textContent = _T('btn_confirm_pay');
    }
}

function updateDeliveryBanner(show) {
    $('delivery-banner').style.display = show ? 'flex' : 'none';
}

function parseExpiry(expiresAt) {
    if (!expiresAt) return null;
    const d = new Date(expiresAt);
    return isNaN(d.getTime()) ? null : d;
}

function formatCountdown(ms) {
    if (ms <= 0) return _T('timer_expired');
    const m = Math.floor(ms / 60000);
    const h = Math.floor(m / 60);
    const rm = m % 60;
    if (h > 0) return `${h}h ${rm}m`;
    return `${rm}m`;
}

function refreshActive() {
    nuiFetch('cityrentals:getActiveRental').then(rental => {
        State.activeRental = rental;
        const delivering = rental && (rental.status === 'delivering' || rental.status === 'pending_delivery');
        updateDeliveryBanner(delivering);

        if (!rental) {
            $('active-empty').style.display = 'block';
            $('active-content').style.display = 'none';
            return;
        }

        $('active-empty').style.display = 'none';
        $('active-content').style.display = 'block';

        if (rental.paymentMethod) {
            State.renewPayment = rental.paymentMethod;
        }

        const statusClass = rental.status === 'active' ? 'active' : 'delivering';
        $('active-card').innerHTML = `
            <h3>${rental.vehicleLabel}</h3>
            <p>${_T('active_plate', rental.plate)}</p>
            <p>${_T('active_paid', formatMoney(rental.pricePaid), rental.paymentMethod)}</p>
            <span class="status-pill ${statusClass}">${rental.status}</span>
        `;

        const exp = parseExpiry(rental.expiresAt);
        if (rental.status === 'active' && exp) {
            const tick = () => {
                const left = exp.getTime() - Date.now();
                $('active-timer').textContent = formatCountdown(left);
                if (left <= (10 * 60000) && left > 0) {
                    $('active-timer').style.color = 'var(--cr-warning)';
                }
            };
            tick();
            clearInterval(window._crTimer);
            window._crTimer = setInterval(tick, 1000);
        } else {
            $('active-timer').textContent = delivering ? _T('timer_delivering') : _T('timer_placeholder');
        }

        setupRenewUI();
    }).catch(() => {});
}

function setupRenewUI() {
    if (!State.catalog) return;

    paintRenewDurationChips();
    paintRenewPaymentChips();

    const renewInput = $('renew-value');
    if (!renewInput) return;
    renewInput.value = State.renewDurationValue;
    if (!renewInput._bound) {
        renewInput._bound = true;
        renewInput.addEventListener('input', () => {
            State.renewDurationValue = Math.max(1, parseInt(renewInput.value, 10) || 1);
        });
    }
}

async function renewRental() {
    if (!State.activeRental) return showToast(_T('toast_no_active'));
    const res = await nuiFetch('cityrentals:renewRental', {
        rentalId: State.activeRental.id,
        durationType: State.renewDurationType,
        durationValue: State.renewDurationValue,
        paymentMethod: State.renewPayment,
    });
    if (res?.success) {
        showToast(res.message || _T('toast_renewed'));
        State.activeRental = res.rental;
        refreshActive();
    } else {
        showToast(res?.message || _T('toast_renew_failed'));
    }
}

async function returnVehicle() {
    if (!State.activeRental) return showToast(_T('toast_no_active'));
    const res = await nuiFetch('cityrentals:returnVehicle', {
        rentalId: State.activeRental.id,
        pickup: false,
    });
    if (res?.success) {
        let msg = res.message || _T('toast_returned');
        if (res.fees) {
            const total = (res.fees.damageFee || 0) + (res.fees.lateFee || 0);
            if (total > 0) msg += _T('toast_fees', formatMoney(total));
        }
        showToast(msg);
        State.activeRental = null;
        updateDeliveryBanner(false);
        refreshActive();
    } else {
        showToast(res?.message || _T('toast_return_failed'));
    }
}

async function loadHistory() {
    const list = $('history-list');
    list.innerHTML = `<div class="loading">${_T('loading')}</div>`;
    try {
        const rows = await nuiFetch('cityrentals:getHistory', { limit: 25 });
        if (!rows?.length) {
            list.innerHTML = `<div class="empty-state"><p>${_T('history_empty')}</p></div>`;
            return;
        }
        list.innerHTML = rows.map(r => `
            <div class="history-item">
                <h4>${r.vehicleLabel} · ${r.plate}</h4>
                <p>${r.status} · ${formatMoney(r.pricePaid)} · ${r.durationType} x${r.durationValue}</p>
            </div>
        `).join('');
    } catch (e) {
        list.innerHTML = `<div class="loading">${_T('history_failed')}</div>`;
    }
}

async function loadCatalog() {
    $('vehicle-grid').innerHTML = `<div class="loading">${_T('loading_fleet')}</div>`;
    try {
        const data = await nuiFetch('cityrentals:getCatalog');
        if (!data || !Array.isArray(data.vehicles)) {
            throw new Error('Invalid catalog response');
        }
        State.catalog = data;
        renderCategories();
        renderVehicles();
        setupRenewUI();
        refreshActive();
    } catch (e) {
        console.error('[cityrentals] catalog load failed', e);
        $('vehicle-grid').innerHTML = `<div class="loading">${_T('catalog_error')}</div>`;
    }
}

function wait(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function playSplash() {
    const splash = $('app-splash');
    const titleEl = $('splash-title');
    const typeEl = $('splash-typewriter');
    const cursor = document.querySelector('.splash-cursor');
    if (!splash || !titleEl || !typeEl) return;

    const title = _T('app_name');
    const tagline = _T('app_tagline');

    splash.classList.remove('splash-hide');
    splash.style.display = 'flex';
    splash.setAttribute('aria-hidden', 'false');
    titleEl.textContent = '';
    titleEl.classList.remove('splash-title-show');
    typeEl.textContent = '';
    if (cursor) cursor.classList.remove('splash-cursor-done');

    await wait(350);

    titleEl.textContent = title;
    titleEl.classList.add('splash-title-show');
    await wait(700);

    const speed = 42;
    for (let i = 0; i <= tagline.length; i++) {
        typeEl.textContent = tagline.slice(0, i);
        await wait(speed);
    }

    await wait(350);
    if (cursor) cursor.classList.add('splash-cursor-done');
    await wait(550);

    splash.classList.add('splash-hide');
    splash.setAttribute('aria-hidden', 'true');
    await wait(520);
    splash.style.display = 'none';
    splash.style.pointerEvents = 'none';
}

async function initApp() {
    initCategoryScroll();
    await loadLocales();

    const getSettingsFn = typeof getSettings === 'function' ? getSettings
        : (typeof GetSettings === 'function' ? GetSettings : null);
    const onSettingsChangeFn = typeof onSettingsChange === 'function' ? onSettingsChange
        : (typeof OnSettingsChange === 'function' ? OnSettingsChange : null);

    const applyTheme = (settings) => {
        if (!settings) return;
        const theme = (settings.display && settings.display.theme) || settings.theme;
        if (theme !== 'light' && theme !== 'dark') return;
        document.querySelector('.app')?.setAttribute('data-theme', theme);
        document.body?.setAttribute('data-theme', theme);
    };

    // Dark UI — white status-bar icons on sd-phone
    const c = globalThis.components;
    if (c?.setStatusLight) c.setStatusLight(true);
    else if (c?.setStatusLightOverride) c.setStatusLightOverride(true);
    else if (c?.fetchPhone) c.fetchPhone('SetStatusLight', true);

    if (getSettingsFn) {
        try {
            if (onSettingsChangeFn) onSettingsChangeFn(applyTheme);
            applyTheme(await getSettingsFn());
        } catch (_) {}
    }

    const catalogPromise = loadCatalog();
    await playSplash();
    await catalogPromise;

    setInterval(() => {
        if (State.tab === 'active') refreshActive();
    }, 15000);
}

document.querySelectorAll('.nav-item').forEach(btn => {
    btn.onclick = () => {
        setTab(btn.dataset.tab);
        btn.blur();
    };
});

$('rent-back').onclick = closeRent;
$('btn-confirm-rent').onclick = confirmRent;
$('btn-renew').onclick = renewRental;
$('btn-return').onclick = () => returnVehicle();

if (!window.invokeNative) {
    window.addEventListener('load', () => {
        if (typeof GetParentResourceName === 'function') return;
        setTimeout(() => initApp(), 300);
    });
}
