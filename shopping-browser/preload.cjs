const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('brillitosDesktop', {
  saveJson: payload => ipcRenderer.invoke('save-json', payload),
  openExternal: url => ipcRenderer.invoke('open-external', url)
});
