import 'dotenv/config';
import { readFileSync, readdirSync, statSync, writeFileSync } from 'fs';
import { join } from 'path';
import { capturePhoto, IMAGES_DIR, startCamera, state, stopCamera, STATE_FILE } from './camera';
import { Hono } from 'hono';
import { basicAuth } from 'hono/basic-auth';
import { cors } from 'hono/cors';

const USERNAME = process.env.USERNAME;
const PASSWORD = process.env.PASSWORD;

if(!USERNAME || !PASSWORD) {
  console.error('Error: USERNAME and PASSWORD must be set in environment variables.');
  process.exit(1);
}

const app = new Hono();

startCamera();

process.on('SIGTERM', () => {
  stopCamera();
  process.exit(0);
});

process.on('SIGINT', () => {
  stopCamera();
  process.exit(0);
});

app.use('*', cors());

app.use('/api/*', basicAuth({
  username: USERNAME,
  password: PASSWORD,
}));

app.get('/api/get-state', (c) => {
  console.log('API: Get state');
  return c.json(state);
});

app.get('/api/images', (c) => {
  const files = readdirSync(IMAGES_DIR)
    .filter(file => /\.(jpg|jpeg|png)$/i.test(file))
    .map(file => ({
      name: file,
      time: statSync(join(IMAGES_DIR, file)).mtime.getTime()
    }))
    .sort((a, b) => b.time - a.time);

  const timelapse = files.filter(f => !f.name.startsWith('snapshot-')).map(f => f.name);
  const snapshot = files.filter(f => f.name.startsWith('snapshot-')).map(f => f.name);
  const latest = files.length > 0 ? files[0].name : null;

  return c.json({ 
    timelapse,
    snapshot,
    latest
  });
});

app.get('/api/images/:filename', (c) => {
  const filename = c.req.param('filename');
  console.log('API: Getting image:', filename);

  if (!/\.(jpg|jpeg|png)$/i.test(filename)) {
    return c.json({ error: 'Invalid file type' }, 400);
  }

  const photoPath = join(IMAGES_DIR, filename);

  try {
    const photoContent = readFileSync(photoPath);
    console.log('Serving image:', filename, 'Size:', photoContent.length, 'bytes');

    return c.body(photoContent, 200, {
      'Content-Type': 'image/jpeg',
      'Content-Disposition': `inline; filename="${filename}"`,
      'X-Filename': filename,
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0'
    });
  } catch (error) {
    console.error('Error reading photo:', error);
    return c.json({ error: 'Image not found' }, 404);
  }
});

app.post('/api/update-state', async (c) => {
  console.log('API: Update state');
  try {
    const newState = await c.req.json();
    console.log('Received state update:', newState);

    const stateToWrite = {
      timelapse: {
        enabled: newState.timelapse.enabled,
        interval: newState.timelapse.interval
      }
    };

    writeFileSync(STATE_FILE, JSON.stringify(stateToWrite, null, 2), 'utf-8');
    console.log('State file updated');

    return c.json({ status: 'State updated' });
  } catch (error) {
    console.error('Error parsing state update:', error);
    return c.json({ error: 'Invalid JSON' }, 400);
  }
});

app.post('/api/capture-photo', (c) => {
  console.log('API: Capture photo');
  capturePhoto(false);
  return c.json({ status: 'Photo capture initiated' });
});


export default app;

// Start server when run directly (production)
if (process.env.NODE_ENV === 'production') {
  const { serve } = await import('@hono/node-server');
  const { serveStatic } = await import('@hono/node-server/serve-static');
  const port = Number(process.env.PORT) || 3001;
  
  app.use('/*', serveStatic({ root: './dist' }));
  app.get('/*', serveStatic({ path: './dist/index.html' }));
  
  console.log(`Starting production server on port ${port}`);
  serve({
    fetch: app.fetch,
    port
  });
}