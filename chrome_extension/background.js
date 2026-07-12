// ============================================================
// SaFocus – Background Service Worker (Manifest V3)
// Handles: focus sessions, alarms, session-gated blocking, stats
//
// Two block paths, both gated to "blocking only while a focus
// session is active" — nothing is blocked at rest:
//   - Sensitive sites (porn/gambling): DNR static ruleset,
//     instant redirect to blocked.html. Exposure itself is the
//     harm, so no grace period.
//   - Distracting sites (social/streaming/custom): page loads
//     normally; a content script (overlay.js) is injected and
//     tracks cumulative time-on-domain for the session, showing
//     an escalating "cost mirror" overlay once a grace threshold
//     is crossed. Time wasted is the harm, not the visit itself.
// ============================================================

const ALARM_FOCUS_END = 'safocus_focus_end';
const ALARM_FOCUS_TICK = 'safocus_focus_tick';
const DNR_SET_DEFAULT = 'default_block_rules';

const DEFAULT_STATS = {
    totalFocusSessions: 0,
    totalFocusMinutes: 0,
    totalBlockedAttempts: 0,
    weeklyBlocks: {},
    streakDays: 0,
    lastCompletedDate: null,
};

let defaultWatchedSitesCache = null;

// ── Initialise on install ────────────────────────────────────
chrome.runtime.onInstalled.addListener(async (details) => {
    if (details.reason === 'install') {
        await chrome.storage.local.set({
            focusSession: null,   // { endTime, durationMinutes, startTime }
            blockingEnabled: true,
            userSites: [],        // [{ id, domain, category, active }]
            defaultSitesActive: true,
            stats: { ...DEFAULT_STATS },
            language: 'es',
            identity: null,           // 'study' | 'gym' | 'sleep' | 'create' | null
            scrollHoursPerDay: null,
            onboardingDone: false,
            sessionSiteState: {},     // { [domain]: { elapsedMs, overlayCount } } — reset per session
        });
        // Blocking starts OFF — only activates when a focus session starts.
        await enableDefaultRules(false);
        console.log('[SaFocus] Installed and initialised.');
    }
});

// ── Listen for alarms ────────────────────────────────────────
chrome.alarms.onAlarm.addListener(async (alarm) => {
    if (alarm.name === ALARM_FOCUS_END) {
        await endFocusSession(true);
    } else if (alarm.name === ALARM_FOCUS_TICK) {
        // Persist remaining time so popup can read it without calculating
        const { focusSession } = await chrome.storage.local.get('focusSession');
        if (focusSession) {
            const remaining = Math.max(0, focusSession.endTime - Date.now());
            await chrome.storage.local.set({ focusSessionRemaining: remaining });
        }
    }
});

// ── Message handler (popup/content ↔ background) ─────────────
chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    handleMessage(msg).then(sendResponse).catch((err) => {
        console.error('[SaFocus] Message error:', err);
        sendResponse({ ok: false, error: err.message });
    });
    return true; // keep channel open for async
});

async function handleMessage(msg) {
    switch (msg.type) {
        case 'START_FOCUS': return startFocusSession(msg.minutes);
        case 'STOP_FOCUS': return endFocusSession(false);
        case 'GET_STATE': return getState();
        case 'ADD_SITE': return addUserSite(msg.domain, msg.category);
        case 'REMOVE_SITE': return removeUserSite(msg.domain);
        case 'TOGGLE_SITE': return toggleUserSite(msg.domain, msg.active);
        case 'SET_DEFAULT_SITES_ACTIVE': return setDefaultSitesActive(msg.active);
        case 'GET_STATS': return getStats();
        case 'RECORD_BLOCK': return recordBlockedAttempt(msg.domain);
        case 'SAVE_ONBOARDING': return saveOnboarding(msg.identity, msg.scrollHoursPerDay);
        case 'RECORD_OVERLAY_SHOWN': return recordBlockedAttempt(msg.domain);
        case 'SET_BLOCKING_ENABLED': return setBlockingEnabled(msg.active);
        default: return { ok: false, error: `Unknown message type: ${msg.type}` };
    }
}

// ── Focus Session ────────────────────────────────────────────
async function startFocusSession(minutes) {
    const now = Date.now();
    const endTime = now + minutes * 60 * 1000;
    const session = { startTime: now, endTime, durationMinutes: minutes };

    await chrome.storage.local.set({
        focusSession: session,
        focusSessionRemaining: minutes * 60 * 1000,
        sessionSiteState: {},
    });
    await chrome.alarms.create(ALARM_FOCUS_END, { when: endTime });
    await chrome.alarms.create(ALARM_FOCUS_TICK, { delayInMinutes: 1 / 60, periodInMinutes: 1 / 60 }); // every ~1s

    // Activate blocking for the session (sensitive sites only — distracting
    // sites are handled live by webNavigation + the overlay content script).
    const { blockingEnabled, defaultSitesActive } = await chrome.storage.local.get(['blockingEnabled', 'defaultSitesActive']);
    if (blockingEnabled !== false && defaultSitesActive !== false) {
        await enableDefaultRules(true);
    }

    // Badge
    chrome.action.setBadgeText({ text: '' + minutes });
    chrome.action.setBadgeBackgroundColor({ color: '#6C63FF' });

    // Notify
    chrome.notifications.create('focus_start', {
        type: 'basic',
        iconUrl: 'icons/icon48.png',
        title: 'SaFocus — Sesión iniciada ✓',
        message: `Sesión de enfoque de ${minutes} minutos activa.`,
    });

    console.log(`[SaFocus] Focus session started: ${minutes} min`);
    return { ok: true, session };
}

async function endFocusSession(byAlarm = false) {
    const { focusSession, stats } = await chrome.storage.local.get(['focusSession', 'stats']);
    if (!focusSession) return { ok: false, error: 'No active session' };

    // Update stats
    const newStats = stats ? { ...DEFAULT_STATS, ...stats } : { ...DEFAULT_STATS };
    newStats.totalFocusSessions += 1;
    newStats.totalFocusMinutes += focusSession.durationMinutes;

    if (byAlarm) {
        // Streak only counts sessions completed naturally, not stopped early.
        const today = todayStr();
        if (newStats.lastCompletedDate !== today) {
            newStats.streakDays = newStats.lastCompletedDate === yesterdayStr()
                ? (newStats.streakDays || 0) + 1
                : 1;
            newStats.lastCompletedDate = today;
        }
    }

    await chrome.storage.local.set({
        focusSession: null,
        focusSessionRemaining: 0,
        stats: newStats,
        sessionSiteState: {},
    });
    await chrome.alarms.clear(ALARM_FOCUS_END);
    await chrome.alarms.clear(ALARM_FOCUS_TICK);

    chrome.action.setBadgeText({ text: '' });
    await enableDefaultRules(false);

    if (byAlarm) {
        chrome.notifications.create('focus_end', {
            type: 'basic',
            iconUrl: 'icons/icon48.png',
            title: 'SaFocus — ¡Sesión completada! 🎉',
            message: `¡Excelente! Completaste ${focusSession.durationMinutes} minutos de enfoque.`,
        });
    }

    console.log('[SaFocus] Focus session ended.');
    return { ok: true };
}

function todayStr(d = new Date()) {
    return d.toISOString().slice(0, 10);
}

function yesterdayStr(d = new Date()) {
    const y = new Date(d);
    y.setDate(y.getDate() - 1);
    return y.toISOString().slice(0, 10);
}

// ── DNR helpers (sensitive sites only) ───────────────────────
async function enableDefaultRules(enabled) {
    await chrome.declarativeNetRequest.updateEnabledRulesets({
        enableRulesetIds: enabled ? [DNR_SET_DEFAULT] : [],
        disableRulesetIds: enabled ? [] : [DNR_SET_DEFAULT],
    });
}

// ── User site management (distracting / overlay path) ───────
async function addUserSite(domain, category = 'custom') {
    const { userSites } = await chrome.storage.local.get('userSites');
    const sites = userSites || [];

    // Normalise domain
    const clean = domain.replace(/^https?:\/\//, '').replace(/\/.*$/, '').toLowerCase().trim();
    if (!clean) return { ok: false, error: 'Dominio inválido' };
    if (sites.find(s => s.domain === clean)) return { ok: false, error: 'Ya existe' };

    sites.push({ id: Date.now(), domain: clean, category, active: true });
    await chrome.storage.local.set({ userSites: sites });
    return { ok: true, sites };
}

async function removeUserSite(domain) {
    const { userSites } = await chrome.storage.local.get('userSites');
    const sites = (userSites || []).filter(s => s.domain !== domain);
    await chrome.storage.local.set({ userSites: sites });
    return { ok: true, sites };
}

async function toggleUserSite(domain, active) {
    const { userSites } = await chrome.storage.local.get('userSites');
    const sites = (userSites || []).map(s => s.domain === domain ? { ...s, active } : s);
    await chrome.storage.local.set({ userSites: sites });
    return { ok: true, sites };
}

async function setBlockingEnabled(active) {
    // Can't be flipped off mid-session — a running session always blocks.
    const { focusSession } = await chrome.storage.local.get('focusSession');
    if (focusSession) return { ok: false, error: 'No se puede cambiar durante una sesión activa' };
    await chrome.storage.local.set({ blockingEnabled: active });
    return { ok: true };
}

async function setDefaultSitesActive(active) {
    await chrome.storage.local.set({ defaultSitesActive: active });
    // If a session is currently running, apply immediately; otherwise it
    // just takes effect the next time a session starts.
    const { focusSession, blockingEnabled } = await chrome.storage.local.get(['focusSession', 'blockingEnabled']);
    if (focusSession && blockingEnabled !== false) {
        await enableDefaultRules(active);
    }
    return { ok: true };
}

// ── Onboarding (identity + scroll hours, powers the cost mirror) ─
async function saveOnboarding(identity, scrollHoursPerDay) {
    await chrome.storage.local.set({
        identity: identity || null,
        scrollHoursPerDay: typeof scrollHoursPerDay === 'number' && scrollHoursPerDay > 0 ? scrollHoursPerDay : null,
        onboardingDone: true,
    });
    return { ok: true };
}

// ── Stats ────────────────────────────────────────────────────
async function recordBlockedAttempt(domain) {
    const { stats } = await chrome.storage.local.get('stats');
    const s = stats ? { ...DEFAULT_STATS, ...stats } : { ...DEFAULT_STATS };
    s.totalBlockedAttempts += 1;
    const today = todayStr();
    s.weeklyBlocks[today] = (s.weeklyBlocks[today] || 0) + 1;
    await chrome.storage.local.set({ stats: s });
    return { ok: true };
}

async function getStats() {
    const { stats } = await chrome.storage.local.get('stats');
    return { ok: true, stats };
}

async function getState() {
    const data = await chrome.storage.local.get([
        'focusSession', 'focusSessionRemaining', 'blockingEnabled', 'userSites',
        'defaultSitesActive', 'stats', 'language', 'identity', 'scrollHoursPerDay',
        'onboardingDone',
    ]);
    return { ok: true, ...data };
}

// ── Watched domains (distracting path) ───────────────────────
async function loadDefaultWatchedSites() {
    if (defaultWatchedSitesCache) return defaultWatchedSitesCache;
    const res = await fetch(chrome.runtime.getURL('rules/watched_sites.json'));
    defaultWatchedSitesCache = await res.json();
    return defaultWatchedSitesCache;
}

async function getWatchedDomains() {
    const { defaultSitesActive, userSites } = await chrome.storage.local.get(['defaultSitesActive', 'userSites']);
    const domains = new Set();
    if (defaultSitesActive !== false) {
        const defaults = await loadDefaultWatchedSites();
        defaults.forEach(s => domains.add(s.domain));
    }
    (userSites || []).filter(s => s.active).forEach(s => domains.add(s.domain));
    return [...domains];
}

function hostnameMatchesWatched(hostname, watchedDomains) {
    return watchedDomains.some(d => hostname === d || hostname.endsWith(`.${d}`));
}

// ── webNavigation: inject overlay tracker + record sensitive blocks ──
chrome.webNavigation.onCommitted.addListener(async (details) => {
    if (details.frameId !== 0) return;

    const { focusSession, blockingEnabled } = await chrome.storage.local.get(['focusSession', 'blockingEnabled']);
    if (!focusSession || blockingEnabled === false) return;

    let url;
    try { url = new URL(details.url); } catch { return; }
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return;

    const watchedDomains = await getWatchedDomains();
    if (!hostnameMatchesWatched(url.hostname, watchedDomains)) return;

    try {
        await chrome.scripting.executeScript({ target: { tabId: details.tabId }, files: ['overlay.js'] });
    } catch (err) {
        console.warn('[SaFocus] Could not inject overlay:', err.message);
    }
});

chrome.webNavigation.onBeforeNavigate.addListener(async (details) => {
    if (details.frameId !== 0) return;
    const url = details.url;
    // Check if navigating to our blocked page (sensitive-site instant path)
    if (url && url.includes(chrome.runtime.id) && url.includes('blocked.html')) {
        const source = new URL(url).searchParams.get('from') || '';
        if (source) await recordBlockedAttempt(source);
    }
});
