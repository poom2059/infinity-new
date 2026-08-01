import { createApp } from './app.mjs';
import { dbDriver } from './db.mjs';

const port = Number(process.env.PORT || 8787);
const host = process.env.HOST || '0.0.0.0';

const app = await createApp();
app.listen(port, host, () => {
  console.log(`Infinity API http://${host}:${port} (db=${dbDriver()})`);
});
