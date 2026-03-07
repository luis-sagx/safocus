// ── SaFocus blocked page script ──────────────────────────────

const PHRASES = [
    'La disciplina es elegir entre lo que quieres ahora y lo que más quieres.',
    'El éxito es la suma de pequeños esfuerzos repetidos día tras día.',
    'Cada minuto que pierdes en distracciones es un minuto robado a tu futuro.',
    'Focus on being productive instead of busy. — Tim Ferriss',
    'You don\'t have to be great to start, but you have to start to be great.',
    'La concentración es la raíz de todas las habilidades humanas más altas.',
    'El único modo de hacer un gran trabajo es amar lo que haces.',
    'Do the hard jobs first. The easy jobs will take care of themselves.',
    'Pequeñas acciones consistentes crean grandes resultados.',
    'Tu atención es tu bien más preciado — invierte sabiamente.',
];

// Show a random phrase
const quoteEl = document.getElementById('quoteText');
if (quoteEl) {
    quoteEl.textContent = `"${PHRASES[Math.floor(Math.random() * PHRASES.length)]}"`;
}

// Show blocked domain from URL param
const params = new URLSearchParams(location.search);
const fromUrl = params.get('from') || document.referrer;
const badge = document.getElementById('domainBadge');
if (badge && fromUrl) {
    try {
        const host = new URL(fromUrl.startsWith('http') ? fromUrl : 'https://' + fromUrl).hostname;
        badge.textContent = host;
    } catch (_) {
        badge.textContent = fromUrl;
    }
}

// Buttons
document.getElementById('btnGoBack')?.addEventListener('click', () => {
    if (history.length > 1) history.back();
    else window.close();
});

document.getElementById('btnNewTab')?.addEventListener('click', () => {
    chrome.tabs.create({ url: 'chrome://newtab' });
});

// Focus session timer
function updateTimer() {
    chrome.storage.local.get(['focusSession', 'focusSessionRemaining'], ({ focusSession, focusSessionRemaining }) => {
        const infoEl = document.getElementById('sessionInfo');
        const timerEl = document.getElementById('sessionTimer');
        if (!infoEl || !timerEl) return;

        if (focusSession && focusSessionRemaining > 0) {
            infoEl.classList.remove('hidden');
            const totalSec = Math.ceil(focusSessionRemaining / 1000);
            const min = Math.floor(totalSec / 60).toString().padStart(2, '0');
            const sec = (totalSec % 60).toString().padStart(2, '0');
            timerEl.textContent = `${min}:${sec}`;
        } else {
            infoEl.classList.add('hidden');
        }
    });
}

updateTimer();
setInterval(updateTimer, 1000);
