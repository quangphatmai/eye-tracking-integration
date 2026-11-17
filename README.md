# UVU Eye Tracking – Integration (Python)

The Python side of the UVU eye-tracking system: it talks to the **Tobii Pro Nano**
eye tracker, opens Chrome for each task, records the screen, and turns every
recording into a heatmap video and a scanpath video.

The web app (the pages the researcher and the participant see) is a separate
repository, **eye-tracking-app**. It is plain HTML, CSS and JavaScript. This
repository is mostly **Python**. The two meet in one place: the helper in
`bridge/`, which the web app talks to over a WebSocket.

> Installing on a new computer? Follow `SETUP-NEW-COMPUTER.txt` in this folder.
> It goes from Python and the venv to the first run, step by step.

---

## What is in this repository

| Part | What it is |
|---|---|
| `bridge/` | **The helper.** A Python program that the web app talks to. It controls the eye tracker, Chrome and the recording, and makes the videos. This is what runs every day. |
| `start-helper.bat` | One double-click start: the helper, a small web server for the web app, and Chrome. |
| `recordings/` | Everything the helper records (one folder per study / participant / task). Created by the helper. |
| `PyGazeAnalyser/` | Library used to detect fixations when making the scanpath video. |
| `step1` … `step7_*.py`, `test_*.py`, `generate_mock_data*.py`, ... | The original lab scripts, built one step at a time. Kept for reference (see the end of this file). |
| `requirements.txt` | The Python packages, with exact versions (from the working venv). |
| `SETUP-NEW-COMPUTER.txt` | Installation guide for a new computer. |

## Requirements

- Windows (the helper uses Windows-only parts: display scaling, window placement)
- **Python 3.10.11** in a venv at `C:\pyenvs\eye-tracking-integration\venv`
  (`start-helper.bat` looks for it there)
- Tobii Pro Nano and its Tobii software
- Google Chrome
- Two monitors: screen 1 for the participant, screen 2 for the researcher
- ffmpeg is **not** installed separately: the `imageio-ffmpeg` package brings it

## Quick start

On a computer that is already set up:

1. Double-click `start-helper.bat`. It starts the helper, serves the web app at
   `http://127.0.0.1:5500/index.html`, and opens it in Chrome (the
   `eye-tracking-app` folder must sit next to this one).
2. To stop: press **Ctrl+C** in the "Eye Tracking Helper" window.

Without the eye tracker, use test mode (no real gaze, no videos):

```
start-helper.bat --mode mock
```

By hand, from this folder (venv turned on):

```
cd bridge
python bridge_server.py --mode tobii
```

## The helper (bridge)

```
web app (browser) <--WebSocket ws://127.0.0.1:8766, JSON--> bridge_server.py
                                                              |
                                                              +-- worker.py  (separate process)
                                                              |     +-- hardware_tobii.py: Tobii + Chrome + recording
                                                              +-- process_task_fast.py (videos, after each task)
                                                              +-- thumbnail.py (study card pictures)
                  <--HTTP http://127.0.0.1:8767 (videos)--  file_server.py
```

A web page cannot drive an eye tracker or record the screen, so the web app only
sends commands ("start the calibration", "run task 2") and listens to events
("task finished", "videos ready"). The helper does the real work.

### Modes

| `--mode` | What happens |
|---|---|
| `mock` | Everything is pretended inside the server. For working on the web app without hardware. |
| `fake` | The real worker process runs, with a pretend eye tracker. Tests the plumbing. |
| `tobii` | The real thing: Tobii Pro Nano + PsychoPy/Titta calibration + Chrome + screen recording. |

### Options

```
python bridge_server.py --mode tobii [--port 8766] [--files-port 8767]
                                     [--data-dir <folder>] [--speed 10]
                                     [--origin https://my-site.example]
```

- `--data-dir`: where recordings are saved (default: `recordings/` next to `bridge/`)
- `--speed`: mock and fake only; `10` makes everything ten times faster
- `--origin`: allow one more web page to connect. Allowed by default:
  `http://localhost:5500` and `http://127.0.0.1:5500`, plus `http://localhost` on
  ports 3000, 5173 and 8000.

### Files in `bridge/`

| File | Job |
|---|---|
| `bridge_server.py` | The front door: WebSocket server, the message protocol (documented at the top of the file), origin check. |
| `worker_backend.py` | Runs one session: starts the worker process, forwards its events, starts the video processing after each task. |
| `worker.py` | The worker process that owns the hardware, so a problem there does not take the server down. |
| `hardware_tobii.py` | The real hardware: Tobii gaze, calibration, one Chrome window per task, screen recording, head window. Based on `step6_browser_session.py`. |
| `hardware_fake.py` | A pretend eye tracker for `--mode fake`. |
| `participant_overlay.js` | Script that Chrome runs on every page of a task (intro and task screens, scroll and navigation tracking). |
| `process_task_fast.py` | Makes `heatmap.mp4` and `scanpath.mp4` quickly (about 720p). This is the one used. |
| `process_task.py` | The original, full-size version of the video processing. Used only when `ET_FULL_VIDEOS=1` is set. |
| `file_server.py` | Lets the web page play the `.mp4` files from `recordings/` (only `.mp4`, only this computer). |
| `thumbnail.py` | Takes a screenshot of a task's URL in a hidden Chrome, for the study card picture. |
| `window_mover.py` | Moves the web app window to the second screen before the calibration. |
| `test_bridge.py` | Small test client: start the server in `mock` mode, then run `python test_bridge.py` in a second terminal. |

### Messages

The full list (with the fields of each message) is in the comment at the top of
`bridge/bridge_server.py`. In short:

- web app -> helper: `start_session`, `start_calibration`, `start_familiarization`,
  `start_task`, `finish_task`, `end_session`, `process_participants`,
  `capture_thumbnail`
- helper -> web app: `ready`, `session_started`, `calibration_progress`,
  `calibration_done`, `task_started`, `task_finished`, `task_processing`,
  `task_processed`, `session_ended`, `thumbnail_ready`, `error`, and more

## What happens in a session

1. **Calibration** (Titta/PsychoPy). The app window moves to screen 2 first.
2. **Familiarization:** the participant explores the first website for 60 seconds.
   No eye tracking, no recording.
3. **Each task:** the participant reads the task and presses Start Task. Chrome
   opens as a normal window; closing it means "I have finished". The task also
   ends when its time runs out or the researcher presses Next. During the task
   the helper records the gaze, the head position, the screen, the page scroll
   and every page change.
4. **Right after the task:** the heatmap and scanpath videos are made in the
   background, so the researcher and the participant can watch them straight
   away (retrospective think-aloud) while the next task can already start.
5. **End of the session:** everything is saved and the session is closed. If a
   task's videos are missing, the web app's Results page asks the helper to make
   them when it opens.

## Recordings

```
recordings/
  study_<id>/
    participant_<n>_<code>/
      task_<n>/
        session_recording.mp4   the raw screen recording
        gaze_data.csv           gaze samples
        head_position.csv       head position samples
        frame_log.csv           the time of every recorded frame
        scroll_log.csv          page scroll over time
        nav_log.csv             page changes (links the participant clicked)
        screen_info.json        screen size and display scaling
        heatmap.mp4             made by process_task_fast.py
        scanpath.mp4            made by process_task_fast.py
```

The raw recording is large (about 90 MB for one task); each of the two videos is
about 20 MB.

## Video processing

- **Heatmap:** gaze heat is added up over time on a canvas that restarts at every
  page change, and is laid on top of the recording.
- **Scanpath:** fixations (found with PyGazeAnalyser) and the lines between them.
- `process_task_fast.py` writes both at up to 1280 px wide, with fast H.264
  encoding. The heat is still added up in full precision; only the blending onto
  the picture is done with whole numbers, which looks the same and is much
  cheaper. It runs automatically after each task and takes a fraction of the task
  length.
- `process_task.py` is the original, full-size version. Set the environment
  variable `ET_FULL_VIDEOS=1` before starting the helper to use it.

Run one task by hand:

```
cd bridge
python process_task_fast.py <path to a task folder>
```

## The original lab scripts

The scripts in the root of this folder came first. The helper in `bridge/` is
built from them; they are kept for reference and are not needed to run the
system (apart from `PyGazeAnalyser/`):

| Script | Purpose (from its name; see the file header) |
|---|---|
| `step1_connection_test.py` | check that the eye tracker is found |
| `step2_calibration_recording.py` | calibration and a first recording |
| `step3_4_analyze_and_plot.py` | analyse a recording and plot it |
| `step5_websocket_server.py`, `step5_mock_websocket_server.py`, `test_client.py` | the first live gaze WebSocket server and a test client |
| `step6_browser_session.py` | a full browser session with recording (the base of `hardware_tobii.py`) |
| `step7_analyze_browser_session.py` | analysis and videos of a browser session (the base of `process_task.py`) |
| `test_selenium.py`, `test_live_overlay.py`, `test_gaze_overlay_dot.py` | small experiments |
| `generate_mock_data*.py`, `convert_h5_to_tsv.py`, `patch_gazeplotter*.py` | helper scripts for mock data and conversions |

The `participant_01` … `participant_16` folders are recordings from these older
scripts. New recordings from the helper go to `recordings/`.

## Working rules

- Do not change the original lab scripts for web-app features. New work goes
  into `bridge/`.
- The only change in an original file is in `bridge/process_task.py`: the page
  scroll is interpolated only inside one page, so the heat of the previous page
  disappears right at the link click.
- Parts that can only be tested with the eye tracker plugged in are marked
  `# CHECK` in `hardware_tobii.py`.

## Participant data and Git

Recordings contain participants' gaze, head position and screen captures (the
screen can show personal information). Treat them as confidential research data.

- `.gitignore` ignores `venv/`, `__pycache__/` and `participant_*/*.mp4`.
  **It does not ignore `recordings/`.** Add `recordings/` to `.gitignore` before
  committing, and check with `git status` that no recording or video is staged.
- Keep this repository private, and do not share the recordings without
  permission.
- Back up `recordings/` somewhere safe (it is not in Git).
