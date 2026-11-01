const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path = require('node:path');
let mainWindow;
const devURL = process.env.AINBW_WEB_URL || `http://127.0.0.1:${process.env.AINBW_WEB_PORT || 5273}`;
const coreURL = process.env.AINBW_CORE_URL || 'http://127.0.0.1:4177';
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1320, height: 840, minWidth: 820, minHeight: 550,
    frame: false, autoHideMenuBar: true, show: true, backgroundColor: '#151515',
    title: 'AI原生业务工作台',
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true, nodeIntegration: false, sandbox: true,
      webSecurity: true, allowRunningInsecureContent: false,
    },
  });
  const serverURL = app.isPackaged ? coreURL : devURL;
  const allowedOrigin = new URL(serverURL).origin;
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith(allowedOrigin + '/')) return { action: 'allow' };
    if (/^https:\/\//.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
  mainWindow.webContents.on('will-navigate',(event, url)=>{if(new URL(url).origin !== allowedOrigin)event.preventDefault();});
  mainWindow.loadURL(serverURL);
  mainWindow.on('closed',()=>{mainWindow=null;});
}
app.whenReady().then(()=>{
  ipcMain.on('ainbw.windowAction',(event,action)=>{
    if(!['minimize','maximize','close'].includes(action))return;
    const win=BrowserWindow.fromWebContents(event.sender);
    if(!win || win.isDestroyed())return;
    if(action==='minimize')win.minimize();
    if(action==='maximize')win.isMaximized()?win.unmaximize():win.maximize();
    if(action==='close')win.close();
  });
  createWindow();
  app.on('activate',()=>{if(BrowserWindow.getAllWindows().length===0)createWindow();});
});
app.on('window-all-closed',()=>{if(process.platform!=='darwin')app.quit();});
// First milestone: the desktop app connects to a separate, already-running Go process.
// A signed release bundle will supervise and package that process in a future milestone.
