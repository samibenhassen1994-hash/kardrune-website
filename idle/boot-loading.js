(() => {
  const root = document.getElementById('kr-loading');
  const label = document.getElementById('kr-loading-text');
  const retry = document.getElementById('kr-retry');
  let language = navigator.language;
  try { language = localStorage.getItem('idle-language-v1') || language; } catch (_) {}
  const texts = {
    en: ['Loading...', 'Loading is taking longer. Check your connection.', 'Retry'],
    it: ['Caricamento...', 'Il caricamento richiede più tempo. Controlla la connessione.', 'Riprova'],
    es: ['Cargando...', 'La carga tarda más de lo esperado. Revisa tu conexión.', 'Reintentar'],
    ja: ['読み込み中...', '読み込みに時間がかかっています。接続を確認してください。', '再試行'],
    ko: ['불러오는 중...', '로딩이 지연되고 있습니다. 연결을 확인하세요.', '다시 시도'],
    zh: ['加载中...', '加载时间较长，请检查网络连接。', '重试'],
    de: ['Wird geladen...', 'Das Laden dauert länger. Prüfe deine Verbindung.', 'Erneut versuchen'],
  }[(language || 'en').split(/[-_]/)[0]] || ['Loading...', 'Check your connection.', 'Retry'];
  label.textContent = texts[0]; retry.textContent = texts[2];
  retry.addEventListener('click', () => location.reload());
  let finished = false;
  window.kardruneLoadingError = () => {
    if (finished) return;
    label.textContent = texts[1]; retry.hidden = false;
  };
  const timeout = setTimeout(window.kardruneLoadingError, 20000);
  window.addEventListener('flutter-first-frame', () => {
    if (finished) return;
    finished = true; clearTimeout(timeout);
    root.style.opacity = '0'; root.style.pointerEvents = 'none';
    setTimeout(() => root.remove(), 220);
  }, {once:true});
})();
