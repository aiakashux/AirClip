# AirClip Device Image Sync v2 Plan

**Date:** 2026-05-20  
**Scope:** Device image asset syncing for the orbital Devices page  
**Status:** Planned for version 2. Not part of the current release.

---

## Context

The Devices page will first ship with a generic fallback visual for unknown devices.
Version 2 will add a controlled device-image pipeline so AirClip can show a matching
device image when one exists, and fall back to a generic phone, laptop, or desktop
icon when it does not.

This keeps the current app low-risk and low-cost while allowing the asset library to
grow over time without blocking the UI.

---

## Goals

- Show a stable visual for every connected device.
- Prefer a real device image when the asset exists.
- Fall back to a generic platform icon when the asset is missing.
- Keep image lookup deterministic and cacheable.
- Track which device models are missing images so they can be uploaded later.
- Replace fallback visuals automatically after the asset is uploaded to the server.

---

## Non-Goals

- No on-demand AI image generation in the app.
- No per-hover image generation.
- No blocking the UI while waiting for a missing asset.
- No requirement that every device model must have a custom image on day one.

---

## Current Version 1 Behavior

Version 1 will use the generic image that is already being prepared for the device
orbit frame.

Rules:

- If a device image exists locally or on the server, show it.
- If not, show a generic phone, laptop, or desktop icon.
- Keep offline devices visible at 50% opacity.
- Hover or click on a device reveals a sticky tooltip with device name and status.
- Tooltip closes when the pointer leaves both the device and tooltip.

---

## Version 2 System Design

### 1. Device identity

Each connected device should resolve to a stable key, not just a display name.

Suggested fields:

- `deviceId`
- `deviceName`
- `modelName`
- `platform`
- `deviceClass` (`phone`, `laptop`, `desktop`, `tablet`, `unknown`)
- `imageKey`
- `imageVersion`
- `lastSeenAt`

The important part is that the visual lookup uses `imageKey`, not free-form text.
That prevents mismatches when the device name changes.

### 2. Asset manifest

The server should expose a small manifest that tells the client what image exists for
each device key.

Example:

```json
{
  "apple-iphone-15-pro": {
    "imageUrl": "https://assets.airclip.app/devices/apple-iphone-15-pro.png",
    "fallback": "phone",
    "updatedAt": "2026-05-20T00:00:00Z"
  },
  "apple-macbook-pro-14": {
    "imageUrl": null,
    "fallback": "laptop",
    "updatedAt": "2026-05-20T00:00:00Z"
  }
}
```

The client should fetch this manifest on startup and refresh it periodically.

### 3. Client rendering rules

- Render the device using `imageUrl` when available.
- Cache the asset locally after first load.
- If `imageUrl` is missing, use the fallback icon for the device class.
- If a newer manifest version is available, refresh the cached image.
- Never block the orbit layout while the image is loading.

### 4. Missing asset tracking

The app should report missing device images so the admin workflow can keep up with
new devices.

Suggested report payload:

- `deviceId`
- `deviceName`
- `modelName`
- `platform`
- `deviceClass`
- `missingImageKey`
- `firstSeenAt`

This report can be shown in an internal list or sent to a lightweight admin endpoint.

### 5. Manual upload workflow

The content pipeline is manual:

1. A new device model appears in the wild.
2. The app logs the missing image key.
3. The missing model appears in the admin list.
4. A matching device image is generated or prepared offline.
5. The image is uploaded to the server folder.
6. The manifest is updated.
7. Clients sync the new manifest and swap the fallback for the real image.

This is the cheapest and safest approach for v2.

---

## Server Folder Strategy

Use a plain asset folder with predictable names.

Suggested structure:

```text
device-assets/
  apple-iphone-15-pro.png
  apple-macbook-pro-14.png
  dell-xps-13.png
  manifest.json
```

This keeps the upload process simple:

- upload a file
- update the manifest
- clients pick it up on the next sync

---

## UI Behavior

### Orbit items

- Connected devices appear around the center network node.
- Position may reshuffle between page loads.
- Offline devices remain visible, but at 50% opacity.
- Hover or click shows the tooltip.
- Click keeps the tooltip open.
- Leaving both the device and tooltip dismisses it.

### Center node

- Show the current network name.
- Show the connected device count under it.
- The count should reflect devices on the same network.

### Fallback visuals

- Phone devices use a generic phone silhouette.
- Laptop devices use a generic laptop silhouette.
- Desktop devices use a generic desktop silhouette.
- Unknown devices use the safest neutral icon available.

---

## Acceptance Criteria

- Every device can render even if no custom image exists.
- Missing images do not break layout or reduce readability.
- The app can identify and list missing device image keys.
- Uploaded images replace fallback visuals without a code change.
- Offline devices stay visible at reduced opacity.
- Hover and click tooltip behavior works as described.

---

## Implementation Order for v2

1. Define stable device image keys.
2. Add manifest fetch and local cache.
3. Add fallback icon rendering by device class.
4. Add missing-asset reporting.
5. Add manual upload sync support.
6. Swap orbit visuals from fallback to real image when available.

---

## Notes

For the current release, do not build the manifest pipeline yet.
Ship the generic image first, then layer this system on top in v2.
