# Airclip Motion Audit and Implementation Plan

Scope: every user-visible macOS and Android surface currently present in the repository. This is a planning audit only; it does not change application behavior.

## Motion direction

Airclip should feel calm, immediate, and native. Motion exists to explain a state change, preserve spatial continuity, or confirm an action. It should not decorate frequent clipboard work.

Use the existing Airclip motion language as the authority:

| Token | Duration | Use |
|---|---:|---|
| Instant | 100 ms | press, hover, focus, icon/color feedback |
| Fast | 150 ms | fades, selection color, compact feedback |
| Standard | 200 ms | reveal/collapse, small content replacement |
| Deliberate | 250 ms | onboarding/page continuity |
| Maximum | 350 ms | rare first-run entrance only |

- Enter and confirm with `easeOutQuart`; use the existing `easeOutExpo` only for rare first-run entrances.
- Move an already-visible object with ease-in-out. Use linear motion only for genuine continuous progress.
- Prefer opacity plus 4–8 pt/dp translation. Press scale may go down to 0.97; never overshoot above 1.
- No bounce, spring physics, shake, spin, animated blur, large parallax, or staggered lists.
- Do not animate keyboard-driven navigation, typing, list selection, shortcut capture, or repeated clipboard operations.
- Retain native macOS/Android sheet, dialog, menu, ripple, scrollbar, and window transitions instead of recreating them.
- Reduced Motion: replace movement and scale with a short opacity change, stop every infinite animation, and keep all state changes understandable without motion.

## macOS audit

### Menu bar and popover

| Before | After | Why |
|---|---|---|
| Menu-bar icon swaps immediately between normal and unread | Keep the swap immediate; optionally fade only if AppKit supports it without a custom overlay | The icon is a persistent status signal, not a decorative event |
| Popover opening combines an AppKit panel fade, a container offset/scale, and staggered card entrances | Use one 100–140 ms panel fade for mouse opening; open instantly from the global shortcut | A frequently opened utility should feel immediate; the current layers duplicate motion |
| Popover closing combines content exit motion and panel alpha animation | Keep one 100–120 ms panel fade; Escape and keyboard dismissal are immediate | One owner makes dismissal interruptible and prevents delayed closure |
| Recent clip cards stagger into view | Remove the stagger and present the list as one stable surface | Repeated menu access should not replay a reveal sequence |
| Card hover blurs the clip and reveals “Click to Copy” | Keep content sharp; fade in a small copy affordance and change fill/border in 100–120 ms | Blur adds visual noise and reduces readability |
| Card press scales to 0.965 | Use 0.98 for 80–100 ms, or rely on the fill change | Enough tactile confirmation without a noticeable jump |
| Keyboard selection changes immediately | Keep it immediate | Arrow-key navigation is frequent and must track input exactly |
| Copy confirmation appears as a short toast and closes the popover | Keep the brief fade/4 pt offset; keep total feedback under about 700 ms | It confirms success without blocking the workflow |
| Sensitive content is statically blurred | Keep redaction static; reveal/conceal via a 100–120 ms opacity crossfade, never animate blur radius | Preserves privacy while avoiding an expensive, distracting blur animation |
| Empty popover, coachmark, manual Send, See All/Open App footer | Fade coachmark once at 150–180 ms; use existing hover/press feedback for actions; leave empty state static | Only transient state needs motion |
| Connection badge can pulse whenever connected | Pulse opacity only while actively syncing; connected and offline states remain still | Continuous motion should represent ongoing work, not success |

### Main window shell and navigation

| Before | After | Why |
|---|---|---|
| Sidebar expands/collapses with width and opacity animation | Keep the existing 240 ms `easeOutQuart` transition; use opacity-only under Reduced Motion | It explains reclaimed space and already follows the design tokens |
| Sidebar row hover and press feedback | Keep the 120 ms hover; reduce press to 0.98 at 80–100 ms | Small pointer feedback is useful and local |
| Home, Devices, Saved, and Settings content replaces abruptly or inherits broad `withAnimation` scopes | Use a 120–150 ms content crossfade for pointer clicks only; switch immediately for notifications, shortcuts, and programmatic routing | Avoids accidental animation of unrelated descendants and respects input modality |
| Active navigation fill/count badge changes inside broad animation scopes | Animate fill/color in 100–120 ms; crossfade changed counts in 120 ms without moving the row | Communicates selection and unread changes without layout motion |
| Main window creation and standard toolbar/window actions | Keep native AppKit behavior | Native window motion is already correct and accessible |

### Home and Saved clipboard workspace

| Before | After | Why |
|---|---|---|
| Search field focus, fill, and border change abruptly | Animate color/border only for 100–120 ms | Focus is a state transition; typing itself remains unanimated |
| Clear-search control appears/disappears immediately | Fade it for 100 ms only when empty/non-empty state changes | Prevents a tiny pop without animating each keystroke |
| Filter row appears/disappears abruptly | Reveal/collapse with opacity plus 4 pt vertical movement over 160–180 ms | Explains where the extra controls came from |
| Filter-chip selection switches immediately | Animate fill, border, and text color for 100–120 ms; do not move or resize chips | Stable geometry is more important than flourish |
| Filter strip scroll arrows already fade and the strip scrolls smoothly | Keep the existing 120 ms arrow fade and 240 ms gesture-independent scroll; use immediate scrolling under Reduced Motion | This already communicates overflow and direction clearly |
| Search/filter result set changes abruptly | Crossfade the empty/result container for 120–150 ms; do not stagger or slide all rows | Search is frequent, so feedback must remain fast |
| Live incoming clipboard items appear immediately | When the list is idle, insert with a single 140–160 ms fade plus 4 pt offset; insert immediately while scrolling or under Reduced Motion | Calls attention to a new remote clip without disturbing active reading |
| Deleted items disappear immediately | Collapse/fade the removed row over 120–150 ms for pointer deletion; remove immediately for keyboard Delete | Connects the destructive action to its result without delaying keyboard work |
| Save/unsave state and Saved count update abruptly | Crossfade icon/color and count for 100–120 ms | Confirms the state mutation while keeping the row stationary |
| Row hover and press already animate | Keep hover at 100–120 ms; use at most 0.99/0.98 press scale | The full row should not visibly shrink |
| Row selection and keyboard movement | Keep immediate | Selection is high-frequency navigation |
| Preview switches between selected items abruptly | Crossfade preview content in 120–150 ms for pointer selection; switch immediately for keyboard traversal | Adds continuity only when it will not lag input |
| Link metadata and image previews pop in after loading | Fade loaded media/content in for 120–150 ms; use a static placeholder and spinner only after roughly 400 ms | Async completion benefits from a soft handoff; fast loads should not flash a loader |
| Sensitive preview reveal changes abruptly | Crossfade redacted and revealed layers for 100–120 ms; do not animate blur | Keeps the privacy boundary legible |
| Copy action already swaps to success feedback | Keep the 120 ms crossfade, shorten the reset to about 800 ms, and suppress movement with Reduced Motion | Clear, compact confirmation |
| Open, Reveal, Copy, Save, Delete floating actions | Keep local hover/press feedback; crossfade only stateful icons such as Save/Unsave | Avoid animating destructive or external navigation itself |
| Saved coachmark enters and waits 2.2 seconds before exit | Enter with fade/4 pt movement at 160 ms; dismiss after 1.2–1.6 seconds with a 100–120 ms fade | It stays visible long enough to read without interrupting repeat saves |
| Group headers, manual-send row, static empty illustrations | Keep static; use only container crossfade when the whole state changes | These are landmarks, not animated objects |

### Devices and pairing

| Before | After | Why |
|---|---|---|
| Reconnect icon spins with a spring | Remove spin and spring; dim to 0.55 then restore over 150 ms, and crossfade the refreshed status | Motion should show the request was accepted without implying indefinite work |
| Network name, connection count, and online/offline labels switch immediately | Crossfade changed text/status dots in 100–150 ms without moving the row | Status changes become noticeable but calm |
| Offline device content opacity changes immediately | Animate opacity only for 120 ms | Preserves layout and explains availability |
| Device rows appear/remove abruptly | Fade plus 4 pt insertion/removal over 150–180 ms; never animate periodic reordering | Pairing/removal are rare structural changes |
| Diagnostic, milestone, and Wi-Fi mismatch notices pop in/out | Fade plus 4 pt vertical movement at 160–180 ms; exit with a 100–120 ms fade | These messages are contextual and spatially inserted |
| Add Device opens a sheet | Keep native sheet presentation and dismissal | The platform already communicates modality |
| Pairing sheet changes QR placeholder, code, instructions, and success state abruptly | Fade QR/media in at 140 ms; crossfade title/instructions/success over 160–180 ms; keep the numeric countdown static | Makes asynchronous pairing progress legible without animating every timer tick |
| Pairing activity uses a system progress indicator | Keep it only for waits longer than about 400 ms | Prevents loader flashes |
| Remove confirmation uses a native alert | Keep native alert motion; animate only the resulting row removal | The alert already provides the correct hierarchy |
| Old orbit/network-hub components contain spring, rotation, hover, and tooltip motion but are not used by the current Devices panel | Do not invest in their motion; verify they are unreachable, then delete them in a separate cleanup | Dead UI should not expand the implementation scope |

### Settings

| Before | After | Why |
|---|---|---|
| Appearance, history, sync, and sensitive choices update abruptly | Animate only local fill/border/text color for 100–150 ms; allow the system theme change to remain native | Confirms selection without adding a second global transition |
| Sensitive category rows appear/disappear when the master rule changes | Reveal/collapse the group with opacity plus 4 pt movement over 180–200 ms | Shows that the master rule controls the child settings |
| Menus and destructive confirmations | Keep native menu and alert transitions | No custom animation is needed |
| Shortcut recorder enters/leaves recording mode abruptly | Animate border/fill and prompt crossfade for 100–120 ms; capture each key immediately | The mode change needs feedback; keystrokes do not |
| Clear-shortcut affordance appears/disappears | Fade over 100 ms | Small state continuity |
| Show Tips, Clear History, Leave Network, About/version rows | Use existing hover/press feedback only; crossfade content after an actual reset if visible | Actions should feel direct, especially destructive ones |

### macOS onboarding and system surfaces

| Before | After | Why |
|---|---|---|
| Landing art contains continuous orbiting elements | Prefer a static composition; if retained, run one slow linear loop only while the window is active and stop under Reduced Motion | Airclip’s rules reject decorative spin; background work should never continue invisibly |
| Landing content and call-to-action entrance | Keep a one-time 220–300 ms fade plus 6–8 pt movement | First-run context can tolerate one deliberate entrance |
| Create/Join/Name/Show Code/Enter Code steps already fade and move | Standardize forward/back direction and keep transitions at 180–220 ms; use fade-only with Reduced Motion | Preserves spatial history without slowing onboarding |
| Device-name and pairing-code focus | Animate border/color for 100–120 ms; do not animate typed characters | Focus feedback is useful; typing must remain immediate |
| Validation errors appear abruptly | Fade plus 4 pt vertical entrance over 120–150 ms; no shake or wiggle | Error copy and color are sufficient feedback |
| QR image and generated numeric code appear after loading | Fade content in for 140–160 ms; keep countdown digits unanimated | Softens async replacement without creating timer motion |
| Paired/success state and handoff to main window | Crossfade content in 180–220 ms; use native window behavior | This is a rare, meaningful completion |
| Permissions, context menus, About, toolbar, notifications, and window controls | Keep operating-system motion and feedback | Recreating system transitions would be less consistent and less accessible |

## Android audit

### App shell and bottom navigation

| Before | After | Why |
|---|---|---|
| Onboarding and paired app roots replace immediately | Use a 180–220 ms fade for successful first pairing; use immediate replacement on cold launch | Only the in-session completion needs continuity |
| Home, Devices, and Settings replace abruptly | Crossfade for 120–150 ms with no horizontal slide | Tabs are peers, not a forward/back hierarchy |
| Bottom-nav indicator, icon, and label switch immediately | Animate fill and color for 120–150 ms; crossfade active/inactive icons; retain Material ripple | Gives one consistent selection signal without bounce |
| Device-connected tip uses scale plus a spring | Replace spring with 150–180 ms ease-out fade and 0.96-to-1 scale; fade-only under Reduced Motion | Keeps the useful reveal while removing spring physics |
| Sensitive-send dialog and blocked snackbar | Keep native Material motion | These are standard system-like feedback surfaces |
| Status/navigation bar color changes with paired state | Let the theme/window apply immediately or use the root fade only; do not separately animate system bars | Avoids mismatched simultaneous transitions |

### Home clipboard feed

| Before | After | Why |
|---|---|---|
| Large header collapses with scroll-linked geometry and opacity | Keep it gesture-linked; do not add a timed animation | Direct manipulation should follow the finger exactly |
| Search prompt changes to the focused search field abruptly | Use a 100–140 ms crossfade/size handoff, then focus the keyboard immediately | Explains the transformation without delaying text entry |
| Search closes abruptly | Reverse the short handoff unless Back/keyboard dismissal requests immediate closure | Maintains continuity while respecting input |
| Filter row changes header height abruptly | Reveal/collapse over 160–180 ms with opacity and vertical size; preserve the current scroll position | Avoids a layout jump |
| Filter chips use a bouncy spring press plus animated colors | Keep 120–150 ms colors and Material ripple; remove the spring scale | Native ripple already confirms touch |
| Search/filter empty and populated states replace immediately | Crossfade the container for 120–150 ms; do not animate each result | Search results must remain responsive |
| New remote clips appear immediately | When idle, use one 140–160 ms fade/4 dp insertion using the Compose version already installed; skip while scrolling | Highlights inbound content without list turbulence |
| Deletion removes a row immediately and shows Undo | Fade/collapse the row over 120–150 ms, then retain the native snackbar/Undo | Connects cause and effect while preserving recovery |
| Clip rows dim to 0.6 on press in 100 ms | Keep local press feedback but use 0.75–0.8 alpha, or rely on ripple | 0.6 is visually heavy for a high-frequency list |
| Save/unsave changes immediately | Crossfade icon/color over 100–120 ms | Confirms the state without moving content |
| Async link metadata, remote images, and image clipboard previews pop in | Fade loaded content in over 120–150 ms; show a static placeholder and delayed progress only for slow loads | Avoids flashes and explains asynchronous replacement |
| Preview opens in a Material modal bottom sheet | Keep native sheet movement and drag behavior | Native spatial continuity already exists |
| Copy in preview already crossfades and changes button color | Keep the 150 ms confirmation; reset after about 800 ms instead of 1.4 seconds | The existing pattern is correct but can finish sooner |
| Preview Save/Open/Delete icon buttons | Retain ripple; crossfade only Save/Unsave; let Delete close the native sheet before row removal | Each action gets one clear response |
| Snackbars for Save and Delete/Undo | Keep native Material motion | Already consistent and accessible |
| Today, Yesterday, This Week, Earlier sticky headers, manual-send row, and stable empty art | Keep static; crossfade only the whole content state | These are navigational anchors |
| Manual sync action has no explicit in-progress feedback | While a send is actually in flight, pulse icon opacity once or show a small native progress indicator after 400 ms; never spin continuously | Distinguishes accepted work from idle state |

### Devices and scanner

| Before | After | Why |
|---|---|---|
| Network refresh icon performs a bouncy 360-degree rotation | Remove rotation; animate opacity down/up over 150 ms and crossfade resulting network/status text | Meets Airclip’s no-spin/no-spring rule |
| Network name and connected count switch immediately | Crossfade changed text in 100–150 ms; leave the card geometry fixed | Makes refresh results noticeable without movement |
| Diagnostic banner and no-connected-device tip appear abruptly | Fade plus 4 dp vertical entrance over 160–180 ms; 100–120 ms fade exit | Explains inserted guidance |
| Empty device state and populated list replace abruptly | Crossfade the container in 160–180 ms; keep the Add Device button tied to that same transition | Prevents overlapping independent animations |
| Device status dims immediately when offline | Animate opacity over 120 ms and crossfade the status label | Availability changes become legible |
| Device add/remove changes list structure immediately | Fade plus 4 dp insertion/removal over 150–180 ms; do not animate periodic status refresh | Structural events are rare; timestamps are not |
| Three-dot custom dropdown appears/disappears instantly | Add an origin-aware 0.98-to-1 scale plus fade over 140–160 ms; exit with a 100 ms fade | Preserves the menu’s source relationship |
| Remove and location-permission explanation dialogs | Keep native Material dialog motion | Standard modality needs no customization |
| Scanner opens a dedicated ZXing activity with a static target and native camera preview | Keep target static and use the activity’s native transition; on detection, use haptic/audio confirmation or a 100 ms target-color flash before closing if timing permits | The live camera is already visually active; a sweeping scan line would be decorative |
| Scanner Close button | Retain platform touch feedback only | The native ripple is sufficient |

### Settings

| Before | After | Why |
|---|---|---|
| Selectable rows open Material modal sheets | Keep native bottom-sheet motion and drag behavior | Platform behavior already provides origin and modality |
| Radio selection and displayed row value update | Keep native radio animation; crossfade the row value for 100–120 ms after dismissal | Confirms the chosen result without animating the entire page |
| Sensitive category rows appear/disappear abruptly | Reveal/collapse the group over 180–200 ms with fade; fade-only under Reduced Motion | Shows parent-child dependency |
| Appearance changes the full color scheme | Use the platform/theme transition if provided; do not add a custom full-screen overlay | One theme change is enough |
| Show Tips, version, Clear History, and Leave Network rows | Use Material ripple only | These are ordinary or destructive actions, not animation showcases |
| Clear History and Leave Network confirmation dialogs | Keep native dialog motion; crossfade resulting app root only when leaving returns to onboarding | Maintains platform expectations |

### Android onboarding

| Before | After | Why |
|---|---|---|
| Create/Join navigation already slides a short distance and fades | Keep 180–220 ms directional transitions; fade-only with Reduced Motion | It correctly describes forward/back history |
| Landing logo/content enter over 300 ms | Keep as the only staged first-run entrance, capped at 250–300 ms | A rare brand moment can be deliberate |
| Landing orbit loops continuously | Prefer static art; if retained, stop under Reduced Motion and while not RESUMED | Avoids decorative battery/GPU work and conflicts with the no-spin rule |
| Buttons use spring scale feedback | Remove spring scale and rely on Material ripple, or use a 100 ms 0.97 press tween for the large custom CTA only | Prevents mixed motion language |
| Create Name validation and loading | Fade error text in at 120–150 ms with no shake; show native progress only while work is active | Clear and restrained feedback |
| Join-flow tabs move their indicator with a spring while content/subtitle switches abruptly | Move the indicator with a 180–200 ms ease-in-out tween and crossfade body/subtitle in 140–160 ms | One coherent tab transition is better than mixed behaviors |
| Show QR changes progress to QR/code abruptly | Fade QR and code in at 140–160 ms; keep countdown text changes immediate | Async content gets continuity; the timer does not become distracting |
| Scan QR card uses spring press | Keep native ripple or a 100 ms press tween | Removes bounce from a common action |
| Pairing-code digits breathe vertically while verifying | Replace with a single opacity pulse on the code group or delayed native progress indicator | Verification needs status, not perpetual character motion |
| Invalid code triggers a multi-step shake | Remove shake; animate border/background to destructive color in 120–150 ms and fade the error message in | Error state remains obvious and more accessible |
| Digit slots resize/expand with springs while typing | Keep slot geometry fixed; update digits immediately, with at most a 100 ms opacity entrance | Keyboard input must not lag or reflow |
| Success content enters over 400 ms | Reduce to a 220–250 ms fade plus 6 dp movement; no bouncing checkmark | Completion feels polished without exceeding the motion budget |
| Network-switch confirmation | Keep the native Material dialog | Standard destructive context switch |

### Share target, widget, notifications, and system surfaces

| Before | After | Why |
|---|---|---|
| Share target is a transparent activity that returns a Toast | Keep native Toast/activity behavior; do not build a custom animated surface | It should finish as quickly as the platform allows |
| Home-screen widget swaps among No Devices, Synced, Pending, and Ready to Send via `RemoteViews` | Keep state replacement immediate; do not add an animation dependency or fake repeated updates | Launcher support varies and widget refreshes are constrained |
| Widget Send/Paste action invokes a transparent activity and may show a native sensitive-content alert | Keep the native alert; let the widget state change be the confirmation | A hidden helper activity should not introduce another UI layer |
| Widget status dot and labels | Change atomically with each widget update; no pulse loop | Widgets should be glanceable and battery-cheap |
| Android system splash, activity transitions, permission UI, keyboard, notifications, back gesture | Retain platform behavior | These surfaces are owned by Android and already account for accessibility/settings |

## Explicitly do not animate

- Clipboard text as the user types or as every timestamp/countdown second changes.
- Keyboard selection, arrow navigation, shortcut recording keystrokes, Copy/Paste hotkeys, or global-shortcut opening.
- Sticky headers, scroll-linked collapse beyond their direct gesture response, or rows merely becoming visible during normal scrolling.
- Sensitive content via changing blur radius.
- Connected/healthy status continuously. Only active work may use a bounded opacity pulse.
- Native menus, alerts, sheets, snackbars, ripples, scrollbars, permission prompts, window controls, scanner camera preview, To­­asts, and widgets with custom replacements.
- Dead/unreachable Mac orbit components.

## Minimal implementation plan

### Phase 0 — Baseline and accessibility gate

1. Record short reference captures for every surface above in light/dark mode.
2. Verify Reduced Motion behavior on macOS and Android animator duration scale at 0×.
3. Add no dependency. Reuse SwiftUI/AppKit and Compose/Material APIs already installed.

Exit: the team has a before capture and a checklist covering every table row.

### Phase 1 — Remove conflicting motion

Mac files:

- `mac/Airclip/Views/PopoverView.swift`: remove list stagger, hover blur, and duplicate inner open/close transform.
- `mac/Airclip/MenuBar/StatusBarController.swift`: make the panel the single owner of popover open/close timing.
- `mac/Airclip/Views/MainWindowView.swift`: replace reconnect spring/spin; exclude or delete unreachable orbit UI in a separate cleanup.
- `mac/Airclip/Views/SharedComponents.swift`: replace spring focus/selection/press effects with existing Airclip timing curves.
- `mac/Airclip/Views/OnboardingView.swift`: stop decorative loops under Reduced Motion/window inactivity; remove them entirely if static art passes review.

Android files:

- `android/app/src/main/java/com/airclip/airclip/ui/screens/SharedComponents.kt`: remove spring button feedback; add the compact dropdown transition.
- `android/app/src/main/java/com/airclip/airclip/ui/screens/DevicesScreen.kt`: replace spring/spin refresh.
- `android/app/src/main/java/com/airclip/airclip/ui/screens/OnboardingScreen.kt`: remove shake, breathing digits, spring indicators, and spring button feedback.
- `android/app/src/main/java/com/airclip/airclip/ui/screens/MainScreen.kt`: replace the connected-tip spring.
- `android/app/src/main/java/com/airclip/airclip/ui/screens/ClipboardScreen.kt`: remove chip spring scale.

Exit: no bounce, spring, spin, shake, or animated blur remains in active Airclip UI.

### Phase 2 — Shared, high-value state transitions

1. Put only the five durations and two curves into the existing platform theme/token files; do not create a motion framework.
2. Add Reduced Motion/animator-scale branches at the few shared animation entry points.
3. Apply local press/focus/selection color feedback through existing shared controls.
4. Keep native components native.

Exit: buttons, fields, tabs, dropdowns, and selection feedback use one vocabulary across both apps.

### Phase 3 — Clipboard workflow polish

1. Add search/filter reveal, result/empty crossfade, restrained new-item insertion, delete removal, Save/Unsave, and preview async-load fades.
2. Preserve immediate behavior for keyboard actions and while lists are actively scrolling.
3. Keep Copy confirmation under one second and verify rapid repeated copying interrupts cleanly.

Exit: the primary clipboard loop—receive, find, preview, copy/save/delete—feels continuous without becoming slower.

### Phase 4 — Pairing, devices, and settings

1. Add device/status/diagnostic transitions and pairing QR/success handoffs.
2. Add sensitive-rule child-section reveal and compact settings value feedback.
3. Leave alerts, sheets, permission prompts, scanner activity, and destructive confirmations native.

Exit: structural and asynchronous changes are visible; steady-state screens remain still.

### Phase 5 — Onboarding and final restraint pass

1. Standardize forward/back transitions and first-run entrances.
2. Remove or pause decorative orbit loops.
3. Test interruption: rapidly change tabs, open/close popover, toggle filters, pair/unpair, and background/foreground the apps.
4. Delete any motion that does not clarify cause, state, or hierarchy.

Exit: no animation exceeds 350 ms, no action waits for animation to complete, and no infinite motion runs without representing real progress.

## Verification matrix

| Check | macOS | Android |
|---|---|---|
| Reduced Motion / animations disabled | System Settings → Accessibility → Display → Reduce motion | Developer options animator scale 0× and accessibility settings |
| Input modality | Mouse, trackpad, keyboard, global hotkey | Touch, keyboard/back gesture where available |
| Theme | Light, dark, system switch | Light, dark, system switch |
| Stress | Rapid popover open/close, fast selection, incoming clip during scroll | Rapid tab/filter changes, incoming clip during scroll, repeated sheet dismissal |
| Lifecycle | Window inactive, app hidden, wake from sleep | Background/foreground, rotation lock in scanner, process cold start |
| Performance | No animated blur; stable list/preview geometry | Prefer opacity/transform; no list-wide animation or continuous widget refresh |
| Accessibility | Focus/VoiceOver state remains correct without motion | TalkBack labels, focus order, and state announcements remain correct |

## Recommended priority

- P0: remove conflicting spring/spin/shake/blur/stagger motion; Reduced Motion coverage; eliminate duplicate popover animation.
- P1: clipboard workflow, app/tab navigation, dropdowns, device status, pairing success, sensitive-setting reveal.
- P2: rare first-run entrances and optional async media fades.
- Skip: custom widget animation, scanner sweep, animated system dialogs/menus, timestamps/countdowns, dead orbit UI.
