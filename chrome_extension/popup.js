// ── SaFocus Popup ─────────────────────────────────────────────
// Communicates with background.js via chrome.runtime.sendMessage

const RING_CIRCUMFERENCE = 301.6; // 2π × 48

// ── State ─────────────────────────────────────────────────────
let state = {
    focusSession: null,
    focusSessionRemaining: 0,
    blockingEnabled: true,
    userSites: [],
    defaultSitesActive: true,
    stats: {},
};
let selectedMinutes = 25;
let timerInterval = null;

// ── DOM refs ──────────────────────────────────────────────────
const masterToggle = document.getElementById('masterToggle');
const defaultSitesToggle = document.getElementById('defaultSitesToggle');
const btnStartFocus = document.getElementById('btnStartFocus');
const btnStopFocus = document.getElementById('btnStopFocus');
const sessionActiveEl = document.getElementById('sessionActive');
const sessionStartEl = document.getElementById('sessionStart');
const ringTime = document.getElementById('ringTime');
const ringProg = document.getElementById('ringProg');
const chips = document.querySelectorAll('#durationChips .chip');
const customMinutesEl = document.getElementById('customMinutes');
const addSiteInput = document.getElementById('addSiteInput');
const btnAddSite = document.getElementById('btnAddSite');
const siteList = document.getElementById('siteList');

// Stats
const statSessions = document.getElementById('statSessions');
const statMinutes = document.getElementById('statMinutes');
const statBlocked = document.getElementById('statBlocked');
const miniChart = document.getElementById('miniChart');

// ── Utilities ─────────────────────────────────────────────────
function send(msg) {
    return new Promise((resolve) => chrome.runtime.sendMessage(msg, resolve));
}

function fmtTime(ms) {
    const sec = Math.max(0, Math.ceil(ms / 1000));
    const m = Math.floor(sec / 60).toString().padStart(2, '0');
    const s = (sec % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
}

// ── Tab switching ─────────────────────────────────────────────
document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById(`tab-${tab.dataset.tab}`)?.classList.add('active');

        // Refresh stats on tab open
        if (tab.dataset.tab === 'stats') renderStats();
        if (tab.dataset.tab === 'sites') renderSites();
    });
});

// ── Master toggle ─────────────────────────────────────────────
masterToggle.addEventListener('change', async () => {
    const active = masterToggle.checked;
    await chrome.storage.local.set({ blockingEnabled: active });
    if (active) {
        if (state.defaultSitesActive) await send({ type: 'SET_DEFAULT_SITES_ACTIVE', active: true });
        await send({ type: 'TOGGLE_SITE', domain: '__all__', active: true }); // re-apply all
    } else {
        // Disable blocking completely (not during a session – session always blocks)
        if (!state.focusSession) {
            await send({ type: 'SET_DEFAULT_SITES_ACTIVE', active: false });
        }
    }
});

// ── Default sites toggle ──────────────────────────────────────
defaultSitesToggle.addEventListener('change', async () => {
    await send({ type: 'SET_DEFAULT_SITES_ACTIVE', active: defaultSitesToggle.checked });
    state.defaultSitesActive = defaultSitesToggle.checked;
});

// ── Duration chips ────────────────────────────────────────────
chips.forEach(chip => {
    chip.addEventListener('click', () => {
        chips.forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        selectedMinutes = parseInt(chip.dataset.min, 10);
        customMinutesEl.value = '';
    });
});

customMinutesEl.addEventListener('input', () => {
    const v = parseInt(customMinutesEl.value, 10);
    if (!isNaN(v) && v > 0) {
        chips.forEach(c => c.classList.remove('active'));
        selectedMinutes = v;
    }
});

// ── Focus session ─────────────────────────────────────────────
btnStartFocus.addEventListener('click', async () => {
    const mins = parseInt(customMinutesEl.value, 10) || selectedMinutes;
    if (!mins || mins < 1) return;
    const res = await send({ type: 'START_FOCUS', minutes: mins });
    if (res?.ok) {
        state.focusSession = res.session;
        state.focusSessionRemaining = mins * 60 * 1000;
        showSessionActive(mins);
    }
});

btnStopFocus.addEventListener('click', async () => {
    const res = await send({ type: 'STOP_FOCUS' });
    if (res?.ok) {
        state.focusSession = null;
        state.focusSessionRemaining = 0;
        showSessionStart();
        clearInterval(timerInterval);
        timerInterval = null;
    }
});

function showSessionActive(durationMinutes) {
    sessionStartEl.classList.add('hidden');
    sessionActiveEl.classList.remove('hidden');
    startTimerUI(durationMinutes * 60 * 1000, durationMinutes * 60 * 1000);
}

function showSessionStart() {
    sessionStartEl.classList.remove('hidden');
    sessionActiveEl.classList.add('hidden');
    if (ringProg) ringProg.style.strokeDashoffset = RING_CIRCUMFERENCE;
    if (ringTime) ringTime.textContent = '--:--';
}

function startTimerUI(remainingMs, totalMs) {
    clearInterval(timerInterval);
    let remaining = remainingMs;
    const total = totalMs;

    function tick() {
        if (remaining <= 0) {
            clearInterval(timerInterval);
            timerInterval = null;
            showSessionStart();
            return;
        }
        // Sync from storage every ~5s
        ringTime.textContent = fmtTime(remaining);
        const progress = remaining / total;
        const offset = RING_CIRCUMFERENCE * (1 - progress);
        ringProg.style.strokeDashoffset = offset;
        remaining -= 1000;
    }

    tick();
    timerInterval = setInterval(tick, 1000);
    // Also sync from storage regularly
    setInterval(syncRemaining, 5000);
}

function syncRemaining() {
    chrome.storage.local.get('focusSessionRemaining', ({ focusSessionRemaining }) => {
        if (focusSessionRemaining != null) {
            state.focusSessionRemaining = focusSessionRemaining;
        }
    });
}

// ── Site management ───────────────────────────────────────────
btnAddSite.addEventListener('click', async () => {
    const domain = addSiteInput.value.trim();
    if (!domain) return;
    const res = await send({ type: 'ADD_SITE', domain });
    if (res?.ok) {
        state.userSites = res.sites;
        addSiteInput.value = '';
        renderSites();
    } else {
        addSiteInput.style.borderColor = '#FF6B6B';
        setTimeout(() => { addSiteInput.style.borderColor = ''; }, 1500);
    }
});

addSiteInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') btnAddSite.click();
});

function renderSites() {
    const sites = state.userSites || [];
    siteList.innerHTML = '';

    if (sites.length === 0) {
        const li = document.createElement('li');
        li.className = 'empty-hint';
        li.textContent = 'No hay sitios personalizados.';
        siteList.appendChild(li);
        return;
    }

    sites.forEach(site => {
        const li = document.createElement('li');
        li.className = `site-item${site.active ? '' : ' inactive'}`;

        const domSpan = document.createElement('span');
        domSpan.className = 'site-domain';
        domSpan.textContent = site.domain;

        // Toggle
        const label = document.createElement('label');
        label.className = 'toggle-wrap';
        const input = document.createElement('input');
        input.type = 'checkbox';
        input.checked = !!site.active;
        input.addEventListener('change', async () => {
            await send({ type: 'TOGGLE_SITE', domain: site.domain, active: input.checked });
            site.active = input.checked;
            li.classList.toggle('inactive', !input.checked);
        });
        const track = document.createElement('span');
        track.className = 'toggle-track';
        const thumb = document.createElement('span');
        thumb.className = 'toggle-thumb';
        track.appendChild(thumb);
        label.appendChild(input);
        label.appendChild(track);

        // Delete
        const del = document.createElement('button');
        del.className = 'site-del';
        del.title = 'Eliminar';
        del.innerHTML = '✕';
        del.addEventListener('click', async () => {
            const res = await send({ type: 'REMOVE_SITE', domain: site.domain });
            if (res?.ok) {
                state.userSites = res.sites;
                renderSites();
            }
        });

        li.appendChild(domSpan);
        li.appendChild(label);
        li.appendChild(del);
        siteList.appendChild(li);
    });
}

// ── Statistics ────────────────────────────────────────────────
function renderStats() {
    const s = state.stats || {};
    if (statSessions) statSessions.textContent = s.totalFocusSessions || 0;
    if (statMinutes) statMinutes.textContent = s.totalFocusMinutes || 0;
    if (statBlocked) statBlocked.textContent = s.totalBlockedAttempts || 0;

    // Mini bar chart — last 7 days
    if (!miniChart) return;
    miniChart.innerHTML = '';
    const weekBlocks = s.weeklyBlocks || {};
    const today = new Date();
    const days = [];
    for (let i = 6; i >= 0; i--) {
        const d = new Date(today);
        d.setDate(d.getDate() - i);
        const key = d.toISOString().slice(0, 10);
        days.push({ key, count: weekBlocks[key] || 0, isToday: i === 0 });
    }
    const max = Math.max(1, ...days.map(d => d.count));
    days.forEach(day => {
        const bar = document.createElement('div');
        bar.className = 'chart-bar';
        const pct = Math.round((day.count / max) * 100);
        bar.style.height = `${Math.max(5, pct)}%`;
        bar.title = `${day.key}: ${day.count} bloqueos`;
        if (day.isToday) bar.dataset.today = '1';
        miniChart.appendChild(bar);
    });
}

// ── Initialisation ────────────────────────────────────────────
async function init() {
    const res = await send({ type: 'GET_STATE' });
    if (!res?.ok) return;

    state = { ...state, ...res };

    // Master toggle
    masterToggle.checked = !!state.blockingEnabled;
    defaultSitesToggle.checked = !!state.defaultSitesActive;

    // Focus session
    if (state.focusSession && state.focusSessionRemaining > 0) {
        const totalMs = state.focusSession.durationMinutes * 60 * 1000;
        showSessionActive(state.focusSession.durationMinutes);
        // Override timer with actual remaining
        clearInterval(timerInterval);
        let remaining = state.focusSessionRemaining;
        const tick = () => {
            ringTime.textContent = fmtTime(remaining);
            const progress = remaining / totalMs;
            ringProg.style.strokeDashoffset = RING_CIRCUMFERENCE * (1 - progress);
            if (remaining <= 0) { clearInterval(timerInterval); showSessionStart(); }
            remaining -= 1000;
        };
        tick();
        timerInterval = setInterval(tick, 1000);
    } else {
        showSessionStart();
    }

    renderSites();
    renderStats();
}

init();
