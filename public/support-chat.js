(() => {
  const chat = document.querySelector('[data-support-url]');
  if (!chat) return;
  const list = document.getElementById('support-messages');
  const connection = document.getElementById('support-connection');
  let running = false;
  const poll = async () => {
    if (running || document.hidden) return;
    running = true;
    try {
      const response = await fetch(`${chat.dataset.supportUrl}?after_id=${chat.dataset.lastId}`, { credentials: 'same-origin', headers: { Accept: 'application/json' }, signal: AbortSignal.timeout(12000) });
      if (!response.ok || !response.headers.get('content-type')?.includes('application/json')) throw new Error();
      const data = await response.json();
      // HTML produzido pelo partial ERB com escape padrão, nunca conteúdo HTML enviado pelo usuário.
      if (data.html) list.insertAdjacentHTML('beforeend', data.html);
      if (data.last_id) chat.dataset.lastId = String(data.last_id);
      document.getElementById('support-status').textContent = { open: 'Aguardando equipe', answered: 'Em atendimento', closed: 'Encerrado' }[data.status] || data.status;
      connection.textContent = data.status === 'closed' ? 'Atendimento encerrado.' : 'Conversa atualizada.';
      if (data.status === 'closed') document.querySelectorAll('#responder input, #responder textarea, #responder button').forEach(field => { field.disabled = true; });
    } catch { connection.textContent = 'Não foi possível atualizar. Tentaremos novamente; sua mensagem não foi alterada.'; }
    finally { running = false; }
  };
  const timer = window.setInterval(poll, 4000);
  window.addEventListener('pagehide', () => window.clearInterval(timer), { once: true });
})();
