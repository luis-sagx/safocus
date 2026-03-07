// ============================================================
// SaFocus – Background Service Worker (Manifest V3)
// Handles: focus sessions, alarms, custom block rules, stats
// ============================================================

const ALARM_FOCUS_END = 'safocus_focus_end';
const ALARM_FOCUS_TICK = 'safocus_focus_tick';
const DNR_SET_DEFAULT = 'default_block_rules';
const DNR_SET_USER = 'user_block_rules';
const MAX_USER_RULE_ID = 10000;  // user rules use IDs 1000–10000
const BASE_USER_RULE_ID = 1000;

// ── Initialise on install ────────────────────────────────────
chrome.runtime.onInstalled.addListener(async (details) => {
    if (details.reason === 'install') {
        await chrome.storage.local.set({
            focusSession: null,   // { endTime, durationMinutes, startTime }
            blockingEnabled: true,
            userSites: [],        // [{ id, domain, category, active }]
            defaultSitesActive: true,
            stats: {
                totalFocusSessions: 0,
                totalFocusMinutes: 0,
                totalBlockedAttempts: 0,
                weeklyBlocks: {},   // { 'YYYY-MM-DD': count }
            },
            language: 'es',
        });
        // Enable the default rule-set
        await enableDefaultRules(true);
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

// ── Message handler (popup ↔ background) ────────────────────
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
        default: return { ok: false, error: `Unknown message type: ${msg.type}` };
    }
}

// ── Focus Session ────────────────────────────────────────────
async function startFocusSession(minutes) {
    const now = Date.now();
    const endTime = now + minutes * 60 * 1000;
    const session = { startTime: now, endTime, durationMinutes: minutes };

    await chrome.storage.local.set({ focusSession: session, focusSessionRemaining: minutes * 60 * 1000 });
    await chrome.alarms.create(ALARM_FOCUS_END, { when: endTime });
    await chrome.alarms.create(ALARM_FOCUS_TICK, { delayInMinutes: 1 / 60, periodInMinutes: 1 / 60 }); // every ~1s

    // Ensure all blocking is active for the session
    await enableDefaultRules(true);
    await applyUserRules();

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
    const newStats = stats || { totalFocusSessions: 0, totalFocusMinutes: 0, totalBlockedAttempts: 0, weeklyBlocks: {} };
    newStats.totalFocusSessions += 1;
    newStats.totalFocusMinutes += focusSession.durationMinutes;

    await chrome.storage.local.set({ focusSession: null, focusSessionRemaining: 0, stats: newStats });
    await chrome.alarms.clear(ALARM_FOCUS_END);
    await chrome.alarms.clear(ALARM_FOCUS_TICK);

    chrome.action.setBadgeText({ text: '' });

    if (byAlarm) {
        chrome.notifications.create('focus_end', {
            type: 'basic',
            iconUrl: 'icons/icon48.png',
            title: 'SaFocus — ¡Sesión completada! 🎉',
            message: `¡Excelente! Completaste ${focusSession.durationMinutes} minutos de enfoque.`,
        });
    }

    const { blockingEnabled } = await chrome.storage.local.get('blockingEnabled');
    if (!blockingEnabled) {
        await enableDefaultRules(false);
    }

    console.log('[SaFocus] Focus session ended.');
    return { ok: true };
}

// ── DNR helpers ──────────────────────────────────────────────
async function enableDefaultRules(enabled) {
    await chrome.declarativeNetRequest.updateEnabledRulesets({
        enableRulesetIds: enabled ? [DNR_SET_DEFAULT] : [],
        disableRulesetIds: enabled ? [] : [DNR_SET_DEFAULT],
    });
}

async function applyUserRules() {
    const { userSites } = await chrome.storage.local.get('userSites');
    const sites = (userSites || []).filter(s => s.active);

    // Build dynamic rules (IDs in range [BASE_USER_RULE_ID, MAX_USER_RULE_ID])
    const newRules = sites.map((site, i) => ({
        id: BASE_USER_RULE_ID + i,
        priority: 1,
        action: { type: 'redirect', redirect: { extensionPath: '/blocked.html' } },
        condition: { urlFilter: `||${site.domain}^`, resourceTypes: ['main_frame'] },
    }));

    // Remove existing dynamic rules then add new ones
    const existingRules = await chrome.declarativeNetRequest.getDynamicRules();
    const removeIds = existingRules.map(r => r.id);
    await chrome.declarativeNetRequest.updateDynamicRules({ removeRuleIds: removeIds, addRules: newRules });
}

// ── User site management ─────────────────────────────────────
async function addUserSite(domain, category = 'custom') {
    const { userSites } = await chrome.storage.local.get('userSites');
    const sites = userSites || [];

    // Normalise domain
    const clean = domain.replace(/^https?:\/\//, '').replace(/\/.*$/, '').toLowerCase().trim();
    if (!clean) return { ok: false, error: 'Dominio inválido' };
    if (sites.find(s => s.domain === clean)) return { ok: false, error: 'Ya existe' };

    sites.push({ id: Date.now(), domain: clean, category, active: true });
    await chrome.storage.local.set({ userSites: sites });
    await applyUserRules();
    return { ok: true, sites };
}

async function removeUserSite(domain) {
    const { userSites } = await chrome.storage.local.get('userSites');
    const sites = (userSites || []).filter(s => s.domain !== domain);
    await chrome.storage.local.set({ userSites: sites });
    await applyUserRules();
    return { ok: true, sites };
}

async function toggleUserSite(domain, active) {
    const { userSites } = await chrome.storage.local.get('userSites');
    const sites = (userSites || []).map(s => s.domain === domain ? { ...s, active } : s);
    await chrome.storage.local.set({ userSites: sites });
    await applyUserRules();
    return { ok: true, sites };
}

async function setDefaultSitesActive(active) {
    await chrome.storage.local.set({ defaultSitesActive: active });
    await enableDefaultRules(active);
    return { ok: true };
}

// ── Stats ────────────────────────────────────────────────────
async function recordBlockedAttempt(domain) {
    const { stats } = await chrome.storage.local.get('stats');
    const s = stats || { totalFocusSessions: 0, totalFocusMinutes: 0, totalBlockedAttempts: 0, weeklyBlocks: {} };
    s.totalBlockedAttempts += 1;
    const today = new Date().toISOString().slice(0, 10);
    s.weeklyBlocks[today] = (s.weeklyBlocks[today] || 0) + 1;
    await chrome.storage.local.set({ stats: s });
    return { ok: true };
}

async function getStats() {
    const { stats } = await chrome.storage.local.get('stats');
    return { ok: true, stats };
}

async function getState() {
    const data = await chrome.storage.local.get(['focusSession', 'focusSessionRemaining', 'blockingEnabled', 'userSites', 'defaultSitesActive', 'stats', 'language']);
    return { ok: true, ...data };
}

// ── webNavigation: track blocks for stats ───────────────────
chrome.webNavigation.onBeforeNavigate.addListener(async (details) => {
    if (details.frameId !== 0) return;
    const url = details.url;
    // Check if navigating to our blocked page
    if (url && url.includes(chrome.runtime.id) && url.includes('blocked.html')) {
        const source = new URL(url).searchParams.get('from') || '';
        if (source) await recordBlockedAttempt(source);
    }
});
