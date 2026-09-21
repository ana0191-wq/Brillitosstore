// Temporary upload access: kept in memory only, never in public source or storage.
(() => {
  let accessKey = '';
  let requestingKey;
  function requestKey() {
    if (accessKey) return Promise.resolve(accessKey);
    if (requestingKey) return requestingKey;
    requestingKey = new Promise(resolve => {
      const dialog = document.createElement('dialog');
      dialog.style.cssText = 'border:1px solid #ead7e5;border-radius:16px;padding:24px;max-width:420px;width:calc(100% - 48px);box-sizing:border-box;font-family:system-ui;color:#302039';
      dialog.innerHTML = '<form method="dialog"><h2 style="margin-top:0">Subir fotos</h2><p>Introduce la clave de almacenamiento de Bunny. Solo se conservará mientras esta pestaña esté abierta.</p><label for="bunny-upload-key">Clave de Bunny</label><input id="bunny-upload-key" type="password" autocomplete="off" required style="display:block;box-sizing:border-box;width:100%;padding:12px;margin:12px 0"><div style="display:flex;gap:12px;justify-content:flex-end"><button type="button" data-cancel>Cancelar</button><button type="submit">Continuar</button></div></form>';
      const input = dialog.querySelector('input');
      dialog.querySelector('form').addEventListener('submit', event => {
        event.preventDefault();
        accessKey = input.value.trim();
        if (accessKey) dialog.close();
      });
      dialog.querySelector('[data-cancel]').addEventListener('click', () => dialog.close());
      dialog.addEventListener('close', () => {
        input.value = '';
        dialog.remove();
        requestingKey = null;
        resolve(accessKey);
      }, {once:true});
      document.body.append(dialog);
      dialog.showModal();
      input.focus();
    });
    return requestingKey;
  }
  window.brlUploadPhoto = async (filename, file) => {
    // The destination is fixed so callers cannot send the key to another host.
    if (!/^productos\/[a-zA-Z0-9_.-]+$/.test(filename)) throw Error('Nombre de archivo inválido');
    const key = await requestKey();
    if (!key) throw Error('Subida cancelada');
    const response = await fetch('https://storage.bunnycdn.com/brillitos/' + filename, {
      method:'PUT', headers:{AccessKey:key, 'Content-Type':file.type || 'image/jpeg'}, body:file
    });
    if (response.status === 401 || response.status === 403) accessKey = '';
    return response;
  };
})();
