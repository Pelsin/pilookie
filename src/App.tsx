import { useState, useEffect } from "react";
import "./App.css";

const fileNameToDateString = (filename: string): string =>
  new Date(
    Number(filename.split(".")[0].replace("snapshot-", "")),
  ).toLocaleString();

function App() {
  const [imageUrl, setImageUrl] = useState<string>("");
  const [timelapseList, setTimelapseList] = useState<string[]>([]);
  const [snapshotList, setSnapshotList] = useState<string[]>([]); 
  const [timestamp, setTimestamp] = useState<string>("");
  const [lastUpdate, setLastUpdate] = useState<number>(() => Date.now());
  const [isCapturing, setIsCapturing] = useState<boolean>(false);
  const [autoLoadLatest, setAutoLoadLatest] = useState<boolean>(true);

  const [config, setConfig] = useState<{
    refreshInterval: number;
    timelapseEnabled: boolean;
  }>({
    refreshInterval: 5,
    timelapseEnabled: true,
  });

  useEffect(() => {
    const fetchConfig = async () => {
      try {
        const response = await fetch("/api/get-state");
        if (response.ok) {
          const data = await response.json();
          setConfig({
            refreshInterval: data.timelapse.interval,
            timelapseEnabled: data.timelapse.enabled,
          });
        } else {
          console.error("Failed to fetch config");
        }
      } catch (error) {
        console.error("Error fetching config:", error);
      }
    };

    fetchConfig();
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      setLastUpdate(Date.now());
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    const fetchImage = async () => {
      try {
        const response = await fetch(`/api/images`);
        if (response.ok) {
          const data = await response.json();
          if (autoLoadLatest) {
            setImageUrl(`/api/images/${data.latest}`);
            setTimestamp(fileNameToDateString(data.latest));
          }
          setTimelapseList(data.timelapse);
          setSnapshotList(data.snapshot);
        }
      } catch (error) {
        console.error("Error fetching image:", error);
      }
    };

    fetchImage();
  }, [lastUpdate, autoLoadLatest]);

  const takePhoto = async () => {
    setIsCapturing(true);
    try {
      const response = await fetch("/api/capture-photo", {
        method: "POST",
      });

      if (response.ok) {
        setLastUpdate(Date.now());
      } else {
        console.error("Failed to capture photo");
      }
    } catch (error) {
      console.error("Error capturing photo:", error);
    } finally {
      setIsCapturing(false);
    }
  };

  const saveConfig = async () => {
    try {
      const response = await fetch("/api/update-state", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          timelapse: {
            enabled: config.timelapseEnabled,
            interval: config.refreshInterval,
          },
        }),
      });

      if (!response.ok) {
        console.error("Failed to save config");
      }
    } catch (error) {
      console.error("Error saving config:", error);
    }
  };

  return (
    <div className="app">
      <header className="header">
        <h1>PiLookie</h1>
        <p className="subtitle">Live Camera Feed</p>
      </header>

      <main className="main-content">
        <div className="content-wrapper">
          <div className="photo-container">
            {imageUrl ? (
              <>
                {timestamp && <div className="photo-timestamp">{timestamp}</div>}
                <img src={imageUrl} alt="Latest photo" className="photo" />
              </>
            ) : (
              <div className="photo-placeholder">
                <p>No photo yet...</p>
              </div>
            )}
          </div>

          <div className="image-list-sidebar">
            <div className="image-list-section">
              <button
                onClick={() => setAutoLoadLatest(!autoLoadLatest)}
                className={`image-list-button ${autoLoadLatest ? 'active' : ''}`}
              >
                Automatically load latest
              </button>
            </div>

            <div className="image-list-section">
              <h3>Snapshots ({snapshotList.length})</h3>
              {snapshotList.length > 0 ? (
                <ul className="image-list">
                  {snapshotList.map((filename) => (
                    <li key={filename} className="image-list-item">
                      <button
                        onClick={() => {
                          setAutoLoadLatest(false);
                          setImageUrl(`/api/images/${filename}`);
                          setTimestamp(fileNameToDateString(filename));
                        }}
                        className={`image-list-button ${imageUrl.includes(filename) ? 'active' : ''}`}
                      >
                        {fileNameToDateString(filename)}
                      </button>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="image-list-empty">No snapshots yet</p>
              )}
            </div>

            <div className="image-list-section">
              <h3>Timelapse ({timelapseList.length})</h3>
              {timelapseList.length > 0 ? (
                <ul className="image-list">
                  {timelapseList.map((filename) => (
                    <li key={filename} className="image-list-item">
                      <button
                        onClick={() => {
                          setAutoLoadLatest(false);
                          setImageUrl(`/api/images/${filename}`);
                          setTimestamp(fileNameToDateString(filename));
                        }}
                        className={`image-list-button ${imageUrl.includes(filename) ? 'active' : ''}`}
                      >
                        {fileNameToDateString(filename)}
                      </button>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="image-list-empty">No timelapse images yet</p>
              )}
            </div>
          </div>
        </div>

        <div className="controls">
          <div className="settings">
            <label>
              Image capture Interval (seconds):
              <input
                type="number"
                min="3"
                max="60"
                value={config.refreshInterval}
                onChange={(e) =>
                  setConfig((prev) => ({
                    ...prev,
                    refreshInterval: Number(e.target.value),
                  }))
                }
                className="interval-input"
              />
            </label>
            <label>
              <input
                type="checkbox"
                checked={config.timelapseEnabled}
                onChange={(e) =>
                  setConfig((prev) => ({
                    ...prev,
                    timelapseEnabled: e.target.checked,
                  }))
                }
              />
              Enable Timelapse
            </label>
            <button onClick={saveConfig} className="save-btn">
              Save Settings
            </button>
          </div>

          <button
            onClick={takePhoto}
            disabled={isCapturing}
            className="capture-btn"
          >
            {isCapturing ? "⏳ Capturing..." : "📷 Capture Photo"}
          </button>
        </div>
      </main>
    </div>
  );
}

export default App;
