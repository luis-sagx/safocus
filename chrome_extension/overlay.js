// ============================================================
// SaFocus – Cost Mirror overlay (content script)
//
// Injected by background.js into watched "distracting" domains
// (social/streaming/custom) while a focus session is active.
// Does NOT block navigation — the page loads normally. Instead
// it tracks cumulative time spent on the domain for this session
// and, once a grace threshold is crossed, drops a full-viewport
// overlay (shadow DOM, page stays intact underneath) showing the
// real cost of the time spent. Each repeat overlay this session
// raises the toll (dismiss delay), so lingering gets more costly,
// not just more annoying.
// ============================================================

(function () {
    if (window.__safocusOverlayActive) return;
    window.__safocusOverlayActive = true;

    const DOMAIN = location.hostname.replace(/^www\./, '');
    const TICK_MS = 1000;
    const GRACE_MS = 20000;       // time-on-site before the first overlay
    const BASE_TOLL_S = 15;
    const TOLL_STEP_S = 15;
    const MAX_TOLL_S = 60;

    const IDENTITY_LABELS = {
        study: { emoji: '📚', label: 'Estudiar' },
        gym: { emoji: '💪', label: 'Gym' },
        sleep: { emoji: '😴', label: 'Dormir temprano' },
        create: { emoji: '🎨', label: 'Crear' },
    };

    const CSS = `
        :host { all: initial; }
        .wrap {
            position: fixed;
            inset: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            background: rgba(10, 11, 16, 0.92);
            backdrop-filter: blur(6px);
            font-family: 'Inter', 'Segoe UI', system-ui, sans-serif;
            animation: sf-fade 0.25s ease both;
        }
        @keyframes sf-fade { from { opacity: 0; } to { opacity: 1; } }
        .card {
            width: min(420px, 88vw);
            background: #1a1d2e;
            border: 1px solid rgba(255,255,255,0.08);
            border-radius: 20px;
            padding: 2rem 1.75rem 1.75rem;
            text-align: center;
            box-shadow: 0 30px 70px rgba(0,0,0,0.6);
            color: #eaeaf0;
        }
        .identity { color: #9b9bb0; font-size: 0.9rem; margin-bottom: 0.5rem; }
        .domain {
            display: inline-block;
            background: rgba(108,99,255,0.18);
            color: #6c63ff;
            border: 1px solid rgba(108,99,255,0.35);
            border-radius: 99px;
            padding: 0.2rem 0.8rem;
            font-size: 0.8rem;
            font-weight: 600;
            margin-bottom: 1.1rem;
        }
        .counter-label { font-size: 0.78rem; color: #9b9bb0; text-transform: uppercase; letter-spacing: 0.06em; }
        .counter {
            font-size: 2.4rem;
            font-weight: 700;
            font-variant-numeric: tabular-nums;
            color: #fff;
            margin: 0.15rem 0 1rem;
        }
        .cost {
            font-size: 0.92rem;
            line-height: 1.55;
            color: #d6d6e6;
            background: rgba(0,212,170,0.08);
            border-left: 3px solid #00d4aa;
            border-radius: 0 10px 10px 0;
            padding: 0.6rem 0.9rem;
            text-align: left;
            margin-bottom: 1rem;
        }
        .cost strong { color: #00d4aa; }
        .streak { font-size: 0.88rem; margin-bottom: 1.25rem; color: #ffb84d; font-weight: 600; }
        .actions { display: flex; gap: 0.65rem; }
        button {
            flex: 1;
            border: none;
            cursor: pointer;
            border-radius: 10px;
            padding: 0.65rem 0.5rem;
            font-size: 0.88rem;
            font-weight: 600;
            transition: opacity 0.15s, transform 0.1s;
        }
        button:active { transform: scale(0.97); }
        .btn-back { background: transparent; color: #9b9bb0; border: 1px solid rgba(255,255,255,0.12); }
        .btn-back:hover { color: #eaeaf0; background: rgba(255,255,255,0.05); }
        .btn-continue { background: #6c63ff; color: #fff; }
        .btn-continue:disabled { opacity: 0.4; cursor: default; }
        .btn-continue:not(:disabled):hover { opacity: 0.88; }
    `;

    let tickInterval = null;
    let tollInterval = null;
    let overlayRoot = null;

    function getStorage(keys) {
        return new Promise(resolve => chrome.storage.local.get(keys, resolve));
    }
    function setStorage(obj) {
        return new Promise(resolve => chrome.storage.local.set(obj, resolve));
    }
    function notifyBackground(msg) {
        return new Promise(resolve => chrome.runtime.sendMessage(msg, resolve));
    }

    function escapeHtml(str) {
        return String(str).replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    }

    function fmtMMSS(ms) {
        const totalSec = Math.max(0, Math.floor(ms / 1000));
        const m = Math.floor(totalSec / 60).toString().padStart(2, '0');
        const s = (totalSec % 60).toString().padStart(2, '0');
        return `${m}:${s}`;
    }

    async function loadSiteState() {
        const { sessionSiteState } = await getStorage('sessionSiteState');
        return (sessionSiteState || {})[DOMAIN] || { elapsedMs: 0, overlayCount: 0 };
    }

    async function saveSiteState(state) {
        const { sessionSiteState } = await getStorage('sessionSiteState');
        const all = sessionSiteState || {};
        all[DOMAIN] = state;
        await setStorage({ sessionSiteState: all });
    }

    function nextThreshold(overlayCount) {
        return GRACE_MS * (overlayCount + 1);
    }

    function removeOverlay() {
        if (tollInterval) { clearInterval(tollInterval); tollInterval = null; }
        if (overlayRoot) { overlayRoot.remove(); overlayRoot = null; }
    }

    function teardown() {
        if (tickInterval) { clearInterval(tickInterval); tickInterval = null; }
        removeOverlay();
        window.__safocusOverlayActive = false;
    }

    async function tick() {
        const { focusSession } = await getStorage('focusSession');
        if (!focusSession) { teardown(); return; }
        if (overlayRoot) return; // overlay's own interval drives the live counter while shown

        const state = await loadSiteState();
        state.elapsedMs += TICK_MS;
        await saveSiteState(state);

        if (state.elapsedMs >= nextThreshold(state.overlayCount)) {
            await showOverlay(state);
        }
    }

    async function showOverlay(state) {
        state.overlayCount += 1;
        await saveSiteState(state);
        notifyBackground({ type: 'RECORD_OVERLAY_SHOWN', domain: DOMAIN });

        const { identity, scrollHoursPerDay, stats } = await getStorage(['identity', 'scrollHoursPerDay', 'stats']);
        const idInfo = identity && IDENTITY_LABELS[identity] ? IDENTITY_LABELS[identity] : null;
        const streakDays = (stats && stats.streakDays) || 0;
        const hoursPerDay = scrollHoursPerDay || 3;
        const hoursPerYear = Math.round(hoursPerDay * 7 * 52);
        const books = Math.max(1, Math.round(hoursPerYear / 8));
        const episodes = Math.max(1, Math.round(hoursPerYear / 0.75));
        const workouts = Math.max(1, Math.round(hoursPerYear / 1));
        const tollSeconds = Math.min(BASE_TOLL_S + TOLL_STEP_S * (state.overlayCount - 1), MAX_TOLL_S);

        const host = document.createElement('div');
        host.id = 'safocus-cost-mirror-host';
        host.style.cssText = 'all: initial; position: fixed; inset: 0; z-index: 2147483647; display: block;';
        document.documentElement.appendChild(host);
        const shadow = host.attachShadow({ mode: 'closed' });

        shadow.innerHTML = `
            <style>${CSS}</style>
            <div class="wrap">
                <div class="card">
                    ${idInfo ? `<p class="identity">Esto te aleja de ${escapeHtml(idInfo.emoji)} ${escapeHtml(idInfo.label)}</p>` : ''}
                    <div class="domain">${escapeHtml(DOMAIN)}</div>
                    <p class="counter-label">llevás acá esta sesión</p>
                    <p class="counter" id="sf-counter">${fmtMMSS(state.elapsedMs)}</p>
                    <p class="cost">${hoursPerYear}h/año así → <strong>${books} libros</strong> · ${episodes} episodios · ${workouts} entrenos</p>
                    ${streakDays > 0 ? `<p class="streak">🔥 ${streakDays} día${streakDays === 1 ? '' : 's'} en juego</p>` : ''}
                    <div class="actions">
                        <button class="btn-back" id="sf-back">← Volver</button>
                        <button class="btn-continue" id="sf-continue" disabled>Continuar en ${tollSeconds}s</button>
                    </div>
                </div>
            </div>
        `;

        overlayRoot = host;

        const counterEl = shadow.getElementById('sf-counter');
        const continueBtn = shadow.getElementById('sf-continue');
        const backBtn = shadow.getElementById('sf-back');

        let liveElapsed = state.elapsedMs;
        let tollRemaining = tollSeconds;

        tollInterval = setInterval(async () => {
            liveElapsed += 1000;
            tollRemaining -= 1;
            counterEl.textContent = fmtMMSS(liveElapsed);
            const s = await loadSiteState();
            s.elapsedMs = liveElapsed;
            await saveSiteState(s);

            if (tollRemaining > 0) {
                continueBtn.textContent = `Continuar en ${tollRemaining}s`;
            } else {
                continueBtn.textContent = 'Continuar igual';
                continueBtn.disabled = false;
                clearInterval(tollInterval);
                tollInterval = null;
            }
        }, 1000);

        backBtn.addEventListener('click', () => {
            if (history.length > 1) history.back();
            else window.close();
        });

        continueBtn.addEventListener('click', () => {
            if (continueBtn.disabled) return;
            removeOverlay();
        });
    }

    tickInterval = setInterval(tick, TICK_MS);
    tick();
})();
