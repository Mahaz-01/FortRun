# 📱 Getting FortRun onto your Android phone — full walkthrough

This guide takes you from "code on my PC" to "app running on my Android phone."
It's written for **Windows** and assumes you're a beginner. Follow it top to bottom.

Your setup (already detected):
- Flutter `3.41.6` at `C:\flutter\flutter` ✅
- Android SDK at `C:\Users\rajas\AppData\Local\Android\sdk` ✅
- Android Studio installed ✅
- **Missing:** Android *command-line tools* + accepted *licenses* (we fix this in Step 1)

There are two ways to get the app on your phone:

- **Path A — Build an APK file and install it** (no cable needed; easiest to understand). ⭐ Recommended for you.
- **Path B — Plug in the phone and run live** (auto-installs + lets you hot-reload while coding).

Do **Step 1** first (one time), then pick a path.

---

## ✅ Step 1 — One-time setup (do this once)

### 1.1 Install the Android "Command-line Tools"

1. Open **Android Studio**.
2. On the welcome screen click **More Actions** (or the **⋮** menu) → **SDK Manager**.
   - If a project is open instead: **File → Settings → Languages & Frameworks → Android SDK**.
3. Click the **SDK Tools** tab.
4. Tick these boxes:
   - ✅ **Android SDK Command-line Tools (latest)**  ← the missing piece
   - ✅ **Android SDK Platform-Tools** (gives you `adb`)
   - ✅ **Android SDK Build-Tools**
5. Click **Apply** → **OK** and let it download.

### 1.2 Accept the Android licenses

Open a **new** PowerShell window (so it sees the new tools) and run:

```powershell
flutter doctor --android-licenses
```

Press **y** and **Enter** for every prompt until it says all licenses accepted.

### 1.3 Confirm everything is green

```powershell
flutter doctor
```

You want the **Android toolchain** line to show `[√]` (a checkmark). The
"Visual Studio not installed" warning is fine — that's only for Windows desktop
apps, not Android. Ignore it.

> 💡 If `flutter` isn't recognized, use the full path `C:\flutter\flutter\bin\flutter` instead, or add `C:\flutter\flutter\bin` to your PATH.

---

## ⭐ Path A — Build an APK and install it on your phone

This produces a single `.apk` file you can copy to your phone and tap to install.
No USB debugging needed.

### A.1 Prepare the project

In PowerShell, from the project folder (`f:\fortrun`):

```powershell
cd f:\fortrun
flutter clean
flutter pub get
```

### A.2 Build the APK

```powershell
flutter build apk --release
```

- The **first** build is slow (5–15 min): it downloads Gradle 8.14 and
  dependencies. You need internet. Later builds are much faster.
- "Release" here is signed with a **debug key** automatically (the project is
  already set up this way), so you do **not** need to create a keystore. Perfect
  for personal testing. (You'd only need a real keystore to publish on Google Play.)

When it finishes you'll see a line like:
`✓ Built build\app\outputs\flutter-apk\app-release.apk`

Your file is here:

```
f:\fortrun\build\app\outputs\flutter-apk\app-release.apk
```

> 💡 **Smaller APK (optional):** `flutter build apk --release --split-per-abi`
> then use `app-arm64-v8a-release.apk` (works on virtually all modern phones).

### A.3 Get the APK onto your phone

Pick whatever's easiest:
- **USB cable:** plug in the phone, copy `app-release.apk` to its storage.
- **Google Drive / email / WhatsApp to yourself:** upload the file, open it on the phone.

### A.4 Install it

1. On the phone, open the APK (Files app → tap it, or from the Drive/WhatsApp download).
2. Android will warn "For your security…". Tap **Settings** → enable
   **Allow from this source** (this is the "install unknown apps" permission for
   the app you're installing from). Go back and tap **Install**.
3. Open **FortRun** from your app drawer.

✅ Done. Jump to **Step 3 — First login & testing**.

---

## 🔌 Path B — Run live over USB (best while developing)

This installs the app *and* lets you hot-reload code changes instantly.

### B.1 Turn on Developer Mode + USB Debugging on the phone

1. **Settings → About phone**.
2. Tap **Build number** 7 times (it says "You are now a developer!").
3. Go back → **System → Developer options** (location varies by brand;
   on Xiaomi/Realme it may be **Additional settings → Developer options**).
4. Turn on **USB debugging**.

### B.2 Connect and verify

1. Plug the phone into the PC with a USB cable.
2. On the phone, a popup asks **"Allow USB debugging?"** → tick *Always allow* → **OK**.
3. On the PC:

```powershell
flutter devices
```

You should now see your phone listed (e.g. `SM-A536 (mobile) • <id> • android-arm64`).
If you only see Windows/Chrome/Edge, see Troubleshooting → "Phone not detected".

### B.3 Run the app

```powershell
flutter run
```

If multiple devices are listed, target the phone explicitly:

```powershell
flutter run -d <device-id-from-flutter-devices>
```

While it's running:
- Press **r** = hot reload (instant UI changes)
- Press **R** = hot restart
- Press **q** = quit

> For a performance-true build use `flutter run --release` (no hot reload, but
> behaves exactly like the installed app).

---

## 🔑 Step 3 — First login & testing on the phone

### Logging in
Use the **email/password** option with one of the test accounts you created:

- `runner1@fortrun.app` / `Password123!`
- `runner2@fortrun.app` / `Password123!`

> ⚠️ **Google sign-in** needs extra one-time config (the OAuth redirect
> `io.supabase.fortrun://login-callback/` must be registered in your Supabase
> dashboard and Google Cloud console). It's already wired in the app's manifest,
> but until you configure the dashboard side, **use email/password**. Ask me when
> you want to set Google up.

### Testing the real features (this is why a phone matters)
GPS only works properly on a real device (not in Chrome). To test the full loop:

1. Allow the **location permission** when prompted (choose *While using the app*;
   "Allow all the time" if you want background — see note below).
2. Go outside (or anywhere with GPS), tap **GO**, walk/run a bit, tap **FINISH RUN**.
3. You should see the **Run Summary** with points — those points are now computed
   **server-side** by the `process_run` function you just deployed (Stage 2). The
   phone can no longer fake them.
4. Check the **map** fills your sector, and the **leaderboard** reflects your points.

> 📍 **Background GPS note:** Android may pause GPS when the screen is off, so a
> run can stop tracking if you lock the phone. That's the **P3** item on our
> roadmap (proper foreground-service background tracking) — not done yet. For now,
> keep the screen on during a test run.

---

## 🔁 Rebuilding after I change the code

Whenever you pull new code/changes:

- **Path A:** re-run `flutter build apk --release`, reinstall the new APK
  (installing over the old one keeps your login).
- **Path B:** just press **R** (hot restart) in the running terminal, or re-run
  `flutter run`.

---

## 🧯 Troubleshooting

**"You have not accepted the license agreements…"**
→ You skipped Step 1.2. Run `flutter doctor --android-licenses` and accept all.

**`flutter` is not recognized**
→ Use `C:\flutter\flutter\bin\flutter ...`, or add `C:\flutter\flutter\bin` to your
PATH (Windows search → "Edit the system environment variables" → Environment
Variables → Path → New).

**Phone not detected by `flutter devices` (Path B)**
- Make sure **USB debugging** is on and you tapped **Allow** on the phone.
- Try a different USB cable/port (some cables are charge-only).
- Set the USB mode on the phone to **File transfer (MTP)**, not "Charging only".
- Check `adb`: run `adb devices`. If it says *unauthorized*, re-accept the popup
  on the phone. (`adb` lives in `C:\Users\rajas\AppData\Local\Android\sdk\platform-tools`.)

**Build fails mentioning `cmdline-tools` or `sdkmanager`**
→ Step 1.1 didn't complete. Reopen SDK Manager → SDK Tools → ensure
**Android SDK Command-line Tools (latest)** is installed.

**Build fails about NDK or a missing SDK platform**
→ In SDK Manager → **SDK Platforms** tab, tick **Android 14 (API 34)** (the app's
`compileSdk`/`targetSdk`). Apply. Rebuild.

**App installs but crashes immediately on launch**
→ Almost always the `env` file. Confirm `f:\fortrun\env` still exists and contains
`SUPABASE_URL` and `SUPABASE_ANON_KEY` (it's bundled as an app asset and the app
won't start without it). Don't delete it.

**"MISSING_KEY" anywhere / Google Maps**
→ Harmless. The app uses OpenStreetMap, not Google Maps. There's a leftover
`GOOGLE_MAPS_API_KEY` placeholder in the Android build config that defaults to
`MISSING_KEY`; nothing in the app reads it.

**App opens but the map is blank**
→ The phone needs internet (map tiles come from OpenStreetMap servers). Check
Wi-Fi/data. The location dot needs GPS enabled.

**Gradle "ambiguous build file" or weird Kotlin/Groovy errors**
→ Already fixed: I removed the duplicate `.gradle.kts` files so only the Groovy
Gradle setup remains. If they ever reappear, delete `settings.gradle.kts`,
`build.gradle.kts`, and `app/build.gradle.kts` under `android/`.

---

## 📋 Quick command reference

```powershell
# one-time
flutter doctor --android-licenses
flutter doctor

# build an installable APK (Path A)
cd f:\fortrun
flutter clean
flutter pub get
flutter build apk --release
# → build\app\outputs\flutter-apk\app-release.apk

# run live on a connected phone (Path B)
flutter devices
flutter run            # debug + hot reload
flutter run --release  # production-like
```

That's everything. Start with **Step 1**, then **Path A**. Ping me at any step that
errors and paste the message — most failures are one of the items above.
