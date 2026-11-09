# Kiosk mode

Turns an unlocked, rooted frame into a standalone wall display: a web dashboard
and a Google Photos slideshow, with a long-press to switch between them and a
daily on/off schedule — all running **on the frame**, no computer attached.

## Prerequisites

- ADB open (the unlock in this repo) and `su` on the device.
- **Fully Kiosk Browser** (`de.ozerov.fully`) installed and set as the display
  app, with **Remote Administration** enabled + a password set.

## Pieces

| File | Runs on | Job |
|------|---------|-----|
| `config.sh` | frame | your URLs, schedule times, Fully password (copy from `.example`) |
| `httpd.sh` | frame | `busybox httpd` serving `www/slideshow.html` on `127.0.0.1:8089` |
| `scheduler.sh` | frame | slot state machine: dashboard / slideshow / screen-off by time |
| `toggle.sh` | frame | flips dashboard ⇄ slideshow (via Fully `loadUrl`) |
| `touchd.sh` | frame | watches the touchscreen; a **long-press (~1.2 s)** runs `toggle.sh` |
| `kiosk-cron.rc` | frame | init service that starts the three daemons on boot |
| `gen_slideshow.py` | host | scrape a public Google Photos album → `www/slideshow.html` |
| `www/slideshow.tpl` | host | the slideshow page (crossfade, blurred fill, shuffle) |

## Install

```bash
cp config.sh.example config.sh      # edit: DASH_URL, DASH_ENC, FULLY_PW, times
./install-kiosk.sh "https://photos.app.goo.gl/XXXXXXXX"
```

The album must be a **public shared** Google Photos album. `gen_slideshow.py`
pulls the `lh3.googleusercontent.com/pw/...` image URLs out of the share page and
bakes them into the page; images are then shown at `=w1920-h1080`. The page needs
no Google login and no third-party service. **Note:** shared-album image URLs can
rotate over months — re-run the generator to refresh (and whenever you add
photos):

```bash
python3 gen_slideshow.py "$ALBUM" www/slideshow.html && adb push www/slideshow.html /data/local/kiosk/www/
```

## The schedule model

`config.sh` defines three slots by minutes-since-midnight. The default:

- `06:00–08:00` **MORNING** → screen on, dashboard
- `08:00–20:30` **DAY** → slideshow (resting view); long-press toggles to dashboard
- `20:30–06:00` **NIGHT** → screen off

Content is applied on slot **change** (so a manual toggle sticks until the next
boundary); screen on/off is enforced every tick. Edit the `T_*` values and the
`cur_slot` logic to taste.

## Gesture

`touchd.sh` reads the raw touchscreen with `getevent` and treats a **press-and-
hold ≥1.2 s** as the toggle — deliberate enough not to fire when you tap
dashboard buttons. Change the threshold in `touchd.sh`.
