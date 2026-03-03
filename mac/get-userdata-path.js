const { app } = require('electron');

app.whenReady().then(() => {
  console.log('userData =', app.getPath('userData'));
  app.quit();
});
