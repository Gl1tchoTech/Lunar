# 🌙 Installing Lunar via SideStore

Once you've built the unsigned `Lunar.ipa`, you can sideload it to your iPhone using
[SideStore](https://sidestore.io/) — no paid Apple Developer account needed.

---

## Prerequisites

1. **An Apple ID** (free is fine; paid stretches re-sign cadence to a year).
2. **SideStore installed** on your iPhone. Install it once via the official
   [sidestore.io](https://sidestore.io/) onboarding — that needs
   AltServer on a Mac/PC for the *first* install of SideStore *itself*.
3. **`Lunar.ipa`** — either built locally or downloaded from the
   GitHub Action artifact **Lunar-unsigned-ipa**.

---

## Steps

### 1. Download or build the unsigned IPA

**Local build (macOS, Xcode 15.4+):**

```bash
brew install xcodegen
bash Scripts/build-ipa.sh           # builds Release
# Output: build/Lunar.ipa
```

**CI build (no macOS needed):**

1. In GitHub, go to **Actions → "Build iOS IPA (unsigned)" → Run workflow**
2. After the run, download the **Lunar-unsigned-ipa** artifact

### 2. Transfer the IPA to your iPhone

Easiest path: **AirDrop** the `.ipa` from your Mac. The iPhone offers
**Open in SideStore** on receipt.

Alternative: drop the `.ipa` into the *Files* app, then point SideStore at
that file via **My Apps → ⋯ → Import**.

### 3. In SideStore → *My Apps* → **+** → **Import IPA**

- Choose the transferred `Lunar.ipa`
- SideStore signs it with your Apple ID and installs it on-device

### 4. Trust the developer certificate (first launch only)

On your iPhone:

> **Settings → General → VPN & Device Management**

Locate your Apple ID profile and tap **Trust**.

### 5. Open Lunar

The installed app is named **Lunar** and is ready to use.

---

## Re-signing cadence

| Apple ID type | Valid for |
|---|---|
| Free | 7 days |
| Paid (any tier) | 1 year (sideload cap 90 days) |

SideStore can **auto-refresh** over Wi-Fi so you don't have to remember.
In SideStore: **Settings → Auto-refresh apps**.

---

## Troubleshooting

- **"Untrusted Developer"** on launch → see step 4 above.
- **"Could not verify"** when importing → confirm your Apple ID is signed in
  inside SideStore, and **Anisette data** is reachable
  (*Settings → Account → Refresh Sources*).
- **Bundle ID mismatch** → confirm `com.gl1tchotech.lunar` matches your
  local project.yml (no other Lunar-prefixed apps should exist).
- **App expired** → SideStore will prompt you, or manually:
  *Settings → Apps → Lunar → Refresh*.

---

## Where to from here?

After install, Lunar launches into the `Library` tab showing the
**No music yet** placeholder. From here, the typical user journey is:

1. **Import** tab → *Open Files…* / *Wi-Fi Drive* → bring in your library
2. **Library** → Songs / Artists / Albums populate
3. Tap a song → **Now Playing** (Cyber Neon Player Style by default)
4. **Settings → Player Style** to switch between the 6 themes
5. **Settings → Equalizer** for 10-band DSP
