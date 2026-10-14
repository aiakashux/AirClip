# Airclip website

Live: https://airclip-silk.vercel.app

Static landing page for the Airclip beta. Public files are isolated in `public/`; no build step, dependencies, database, or feedback service.

Preview: `python3 -m http.server 4173 --bind 127.0.0.1 --directory public`

Deploy from this directory: `npx vercel --prod`. Vercel serves only `public/` using `vercel.json`. The Vercel project is separate from the app repository's other code.

Deployment is manual; automatic Git deployments are disconnected so unrelated app changes cannot replace this site. The source in this directory has not been committed or pushed.

App binaries live in the existing public GitHub repository's versioned prerelease, not in the website deployment. To ship an update, publish new versioned files and update all release links in `public/index.html`.

## Release identity

The Android release signing identity is retained outside the repository at `~/.config/airclip/release/airclip-release.p12`, with its password in `keystore-password` alongside it. Both are private local files. Back them up securely together: future APK updates need the same key. Never put them in this directory or upload them to GitHub/Vercel.

The current published Mac beta is ad-hoc signed and not notarized. New releases are prepared for Developer ID signing, hardened runtime, notarization, and Sparkle 2. The Sparkle private Ed25519 key is stored in the local login Keychain; back it up securely and never commit it. Generate each signed appcast with Sparkle's `generate_appcast` tool, publish the immutable signed archive, then publish `public/updates/mac/appcast.xml` last.

Android updates keep application ID `com.airclip.airclip` and must use the existing private release identity documented above with an increased `versionCode`. Publish the APK and landing-page link before updating `public/updates/android/stable.json`.

## Next phase

Add a feedback form with required feedback text and optional name/email. Prefer a private submission inbox with basic spam protection. Do not imply submissions are stored until a working endpoint exists.

The page currently has no analytics, cookies, external font requests, or form submissions. Normal Vercel/GitHub access logs still apply.
