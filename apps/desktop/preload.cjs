const { contextBridge, ipcRenderer } = require('electron');
const allowed = new Set(['minimize','maximize','close']);
contextBridge.exposeInMainWorld('electronAPI', Object.freeze({
  isElectron: true,
  windowAction(action) { if (allowed.has(action)) ipcRenderer.send('ainbw.windowAction', action); },
}));
