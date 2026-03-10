import { existsSync, mkdirSync, readFileSync } from 'fs';
import { join } from 'path';
import { exec } from 'child_process';

export const STATE_FILE = join(process.cwd(), 'state.json');
export const IMAGES_DIR = join(process.cwd(), 'images');

if (!existsSync(IMAGES_DIR)) {
  mkdirSync(IMAGES_DIR, { recursive: true });
}

export let state = JSON.parse(readFileSync(STATE_FILE, 'utf-8'));
let timelapseInterval: NodeJS.Timeout | null = null;
let isCapturing = false;

export function configCamera() {
  return new Promise<void>((resolve, reject) => {
    exec('gphoto2 --set-config imageformat=0 --set-config imageformatsd=0', (error) => {
      if (error) {
        reject(error);
      } else {
        resolve();
      }
    });
  });
}

export function resetCamera() {
  return new Promise<void>((resolve, reject) => {
    exec('gphoto2 --reset', (error) => {
      if (error) {
        reject(error);
      } else {
        resolve();
      }
    });
  });
}

// Kill macOS PTPCamera process that conflicts with gphoto2
function killPTPCamera() {
  return new Promise<void>((resolve) => {
    exec('pkill PTPCamera', (error) => {
      resolve();
    });
  });
}

export function capturePhoto(isTimelapse = true) {
  if (isCapturing) {
    console.log('Already capturing, skipping...');
    return;
  }

  isCapturing = true;
  console.log('Capturing photo...');

  const fileName = join(IMAGES_DIR, isTimelapse ? `${Date.now()}.jpg` : `snapshot-${Date.now()}.jpg`);
  exec(`gphoto2 --capture-image-and-download --filename "${fileName}"`, (error, stdout, stderr) => {
    isCapturing = false;

    if (error) {
      console.error(`Error executing gphoto2: ${error.message}`);
      return;
    }
    if (stderr && stderr.includes('Error')) {
      console.error(`gphoto2 stderr: ${stderr}`);
      return;
    }
    console.log(`Photo captured: ${stdout}`);
  });
}

function startTimelapse(interval: number) {
  if (timelapseInterval) return;

  console.log(`Starting timelapse with interval of ${interval} seconds`);
  timelapseInterval = setInterval(() => {
    capturePhoto();
  }, interval * 1000);
}

function stopTimelapse() {
  if (timelapseInterval) {
    console.log('Stopping timelapse');
    clearInterval(timelapseInterval);
    timelapseInterval = null;
  }
}

function checkStateAndUpdateTimelapse() {
  const newState = JSON.parse(readFileSync(STATE_FILE, 'utf-8'));
  const wasEnabled = state.timelapse?.enabled;
  const isEnabled = newState.timelapse?.enabled;
  const oldInterval = state.timelapse?.interval;
  const newInterval = newState.timelapse?.interval;

  state = newState;

  if (isEnabled && newInterval) {
    if (!wasEnabled || oldInterval !== newInterval || !timelapseInterval) {
      stopTimelapse();
      startTimelapse(newInterval);
    }
  } else if (!isEnabled && wasEnabled) {
    stopTimelapse();
  }
}

export async function startCamera() {
  console.log('Initializing camera on startup...');
  await configCamera();
  await killPTPCamera();
  await resetCamera();

  setTimeout(() => {
    console.log('Camera ready, starting state monitoring');
    setInterval(checkStateAndUpdateTimelapse, 5000);
    checkStateAndUpdateTimelapse();
  }, 2000);
}

export function stopCamera() {
  stopTimelapse();
}