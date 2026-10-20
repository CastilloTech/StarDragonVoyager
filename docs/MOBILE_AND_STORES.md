# Shipping Star Dragon Voyager to Google Play and the App Store

Store policies change often, so check the linked official pages before each
submission. The figures below were correct as of 2025–2026.

## One-time setup (Windows PC)
1. In Godot: **Editor > Manage Export Templates > Download** (4.7.2).
2. Install **Android Studio** (it includes the Android SDK) and **OpenJDK 17**.
3. Godot: **Editor Settings > Export > Android**. Set the *Java SDK Path* and the *Android SDK Path*.
4. **Project > Install Android Build Template** (needed to build `.aab` files for Play).

## Android test build (your own phone)
1. On the phone, turn on Developer options and then USB debugging. Plug it in.
2. In Godot, click the Android icon in the top-right. It installs and runs the game.

## Google Play release
1. Create a Play Console developer account (one-time US$25 fee). Identity verification is required.
2. Create a **release keystore** and back it up. If you lose it, you can't update the app.
   ```
   keytool -genkeypair -v -keystore sdv-release.keystore -alias sdv -keyalg RSA -keysize 2048 -validity 10000
   ```
3. **Project > Export > Add... > Android**:
   - Package: `com.<yourname>.stardragonvoyager` (permanent, can't change later)
   - Use Gradle Build: on. Export format: **AAB**.
   - Version code: increase it every upload.
   - Release keystore, user and password: from step 2.
   - Screen orientation: sensor landscape (already set in project settings).
   - Target SDK: whatever Play currently requires. New apps must target a recent API level, and the minimum rises every August.
4. Upload the `.aab` to a **closed testing** track. New personal accounts must have
   at least 12 testers opted in for 14 days before production access is granted.
5. Fill in the store listing, content rating questionnaire, Data safety form and privacy policy URL. Then promote to production.

## iOS / App Store
**You need a Mac with Xcode** (or a cloud Mac service such as Codemagic,
MacStadium or GitHub Actions macOS runners). Windows can't sign or upload iOS builds.
1. Join the Apple Developer Program (US$99/year).
2. Create an App ID (bundle identifier, e.g. `com.<yourname>.stardragonvoyager`) and an app in App Store Connect.
3. Godot on the Mac: **Project > Export > Add... > iOS**. Set the bundle ID, Team ID and icons (1024×1024), then export the Xcode project.
4. In Xcode: set signing to your team. Choose **Product > Archive**, then **Distribute App** to App Store Connect.
5. Test with **TestFlight**. Then fill in App Privacy, age rating and screenshots, and submit for review.

## Assets the stores require (not made yet)
- App icon: 1024×1024 PNG with no transparency (iOS). For Android, an adaptive icon with a 432×432 foreground and background.
- Screenshots: phone landscape. iPad too, if you support iPad.
- Privacy policy URL. Both stores require one, even when no data is collected.
- Short and full descriptions, and a feature graphic (1024×500, Play).

## Mobile performance checklist
- Test on a low-end Android phone early. Start at the **Low** and **Medium** presets.
- Keep the frame-time budget under 16.6 ms (60 FPS). Watch for thermal throttling after 10+ minutes of play.
- Profile with Godot's remote debugger (Debugger > Monitors) while running on the device.
- The game auto-pauses when the app goes to the background or the Android back button is pressed.
