# Airclip product value, local metrics and case-study evidence

Planning draft · 11 September 2026 · No collection or instrumentation added.

## What we should sell

The core benefit is removing the intermediary step when moving something between a Mac and Android phone. Users can avoid sending a message to themselves, opening that message on another device, and copying its contents again. Local history also helps retrieve something copied earlier.

Lead with convenience and control: **Move a link or snippet between your Mac and Android without sending it to yourself.** Support it with local transfer, no required account, paired-device control and accessible history. These are positioning proposals, not claims of superiority over every competitor.

For the maker, useful evidence includes setup success, repeat use, observed task time, workflow steps, reliability improvements and voluntary feedback. Download volume alone is weak evidence of product value.

## Three distinct data boundaries

| Layer | What to record | Who sees it |
|---|---|---|
| Local product statistics | Monthly transfer/reuse counts and coarse reliability summaries | User on that device |
| Website/download operations | Aggregate requests or release download totals | Maker and hosting providers |
| Voluntary research | Reviewed summary export, study observations and feedback | Maker when the participant explicitly shares |

Recommended first release: local statistics, aggregate download totals and a small volunteer study. No automatic app analytics uploads. A local counter does not need a new OS capability just to increment; explain it in Settings, allow disabling/resetting it, and do not treat this as a universal legal conclusion about consent. Country-specific requirements depend on the final data flow and launch markets.

Keeping statistics local means the maker cannot see them remotely. There is no way to obtain everyone's actual usage while also promising that no usage data leaves their devices. A no-interruption experience is achievable by avoiding analytics uploads and research prompts in normal use.

Offer **Export usage summary** in Settings: preview the exact fields, save a file locally, then let the user choose whether to share it. No automatic sending. Recruit interested beta testers separately. Website hosts and update hosts may retain IP/request logs even without analytics scripts; document actual providers and retention instead of claiming that nothing at all is collected.

Never export clipboard text, screenshots, URLs/domains, clipboard hashes, app/window titles, network names, IP addresses, device names/IDs, pairing keys or exact activity timelines. Hashed clipboard contents are not safely anonymous, particularly for predictable values. Use coarse counts, month, platform and app version. Store monthly summaries for a proposed rolling 12 months; reset/delete on request. This retention choice does not change clipboard-history retention.

## Define events before counting

| Metric | Definition | Limitation |
|---|---|---|
| Received live clips | Successfully decrypted, accepted live clips on this device | Does not establish a later paste |
| Remote history reuse | Explicit Copy on a remotely sourced history item | Clipboard copy is not proof of use in another app |
| Local history reuse | Explicit Copy on a locally sourced history item | Different benefit from cross-device transfer |
| Active days | Days with a transfer or explicit reuse | Avoid counting background uptime |
| Setup success | A participant pairs and completes their first real transfer | Requires local measurement or a study report |
| Delivery success | Confirmed deliveries / eligible attempted transfers | Requires trustworthy receipt acknowledgements |

The inspected Mac `sendClipboard` inserts local history before broadcasting. Counting that history as delivered would overstate success, including when no peer receives it. The inspected live receive path and history-backfill path are separate, which provides a useful place to distinguish new transfers from backfill.

For the first local summary, count accepted live receives at the receiver and explicit history Copy actions. Do not infer historical monthly totals from retained history: trimming and deletion make that inaccurate. Start counters at instrumentation release and disclose the coverage period.

If later implementing confirmed deliveries, count after receiver acceptance and return an authenticated receipt. Do not confuse an existing heartbeat acknowledgement with a clipboard-delivery receipt. Deduplicate retries by transfer event ID, not by globally unique content: copying the same text intentionally on another occasion may be a legitimate new event. Exclude backfill, reconnect replays, blocked content and loop echoes. Bound any receipt bookkeeping.

Do not sum sender and receiver counts as separate transfers. For multiple destinations distinguish one transfer event from several device deliveries. Without a pairing-level aggregation design, display **on this device** and avoid an all-devices grand total. A copy from received history must not add another live transfer.

Airclip cannot reliably observe every paste in arbitrary other apps through its normal clipboard flow. Do not introduce Accessibility monitoring or a keyboard solely to measure productivity.

## Turning usage into time saved

**1,000 copies do not establish five hours saved.** Some are local-only, never used, duplicates or automatic transfers the user did not need. Five hours across 1,000 relevant tasks requires a measured average saving of 18 seconds per task.

Use this equation only with clearly stated assumptions:

```text
estimated time saved = eligible completed tasks × measured time difference per task
measured time difference = baseline task time − Airclip task time
```

Illustrative arithmetic, not research results:

- Usual self-message workflow: 24 seconds.
- Airclip workflow: 6 seconds, including required Android steps.
- Difference: 18 seconds.
- 300 comparable completed tasks: 90 minutes estimated.
- 1,000 comparable completed tasks: 5 hours estimated.

Transfer counts are not automatically eligible completed tasks. Until a study supports the mapping, show actual counts and keep the time figure as a user-controlled scenario calculator: **If Airclip replaces 300 transfers like this, the estimated difference is 90 minutes.** Do not silently assume that every received item replaced a manual task.

Count clicks/taps/keyboard actions in the benchmark workflow too. A claim such as fewer steps is defensible only when the start/end task is the same and both workflows include their real actions. Avoid translating focus or context switching into arbitrary minutes.

## Small study for the case study

Recruit 5–8 willing Mac/Android users for a formative study; this is a proposed study size, not existing evidence or a representative population sample.

1. Observe fresh install, pairing and first transfer. Record completion, elapsed time and where help was needed.
2. Give each person three matched tasks: transfer a link, a short snippet and retrieve an earlier item. Use invented content.
3. Compare their usual method with Airclip from content ready on the source through usable content in the destination. Include required foreground/share actions, failed attempts and recovery.
4. Alternate workflow order to reduce learning effects; repeat tasks enough to see variation.
5. Report paired time differences, medians/ranges, task steps, completion rates, sample size, versions and limitations. Keep first-time setup cost separate from repeat-transfer savings; report both.
6. Invite one week of normal use and an optional reviewed summary export. Ask whether Airclip replaced the previous method and what still failed.
7. Publish only consented quotations and aggregate results. Label your own usage as a single-person example, not all-user evidence.

Suitable eventual claim template: **In a study of N participants, the median time difference for [specified task] was X seconds compared with their usual method.** Do not fill in X before measuring it. Optional reporters are self-selected; do not present their retention as the entire install base.

## App adjustments before launch

1. **Privacy wording and URL previews:** Android `UrlMetadataLoader` contains HTTP requests to copied URLs and supplies remote image URLs. Audit its callers and image loading; for a strict local default, disable automatic remote previews and let users deliberately request them. Such requests can reveal a copied URL, including its path/query, to a remote site. Update checks are a separate, documented internet use.
2. **Reduce permissions:** Mac `CurrentWiFiNetwork` requests Location access to display the Wi-Fi name, with calls from onboarding and the main view. Make displaying that name optional; pairing should work without requiring it. Keep necessary local-network and user-invoked camera/install permission flows. Promise minimal permissions, not zero permissions.
3. **Android expectations:** Android 10+ generally restricts clipboard reads to the focused app or default input method. A foreground service alone is not an exemption. Test and document Share/Send/widget behavior, both directions, and battery/background constraints. [Android clipboard restrictions](https://developer.android.com/about/versions/10/privacy/changes#clipboard-data).
4. **Distribution readiness:** current Mac minimum is 26.0; Android minSdk is 26. Both versions are currently 1.0/build 1. Confirm actual supported device coverage, add signed release builds and the update path in the distribution plan.
5. **Reliable local controls:** verify pause, remove paired device, clear history, retention, reconnect and upgrade persistence. Treat prior audit findings as checks to re-run, not proof that current uncommitted fixes still fail.
6. **Local statistics:** add the minimal counters and reset/export controls described above. Include one small runnable check proving retry/backfill does not inflate counts and reset clears the aggregates.
7. **Validate the promise:** inspect outbound network behavior with internet disabled while LAN remains available; examine logs and OS backup behavior. Android currently sets `allowBackup=false`, but verify actual backup/transfer behavior and Mac backups before broad claims. Distinguish transport encryption from encryption of local stored history.

## Decisions still needed

- Free beta, permanently free, or paid launch? Recommended default: free beta before a licensing system.
- Broad Mac/Android audience or designer-first positioning?
- Owned domain, Apple Developer membership, and operating budget?
- Keep macOS 26 minimum or invest in older-system support?
- Which countries are in the first release?
- Is local-only usage measurement plus volunteer exports sufficient? Recommended default: yes.

This plan is based on targeted source inspection and current platform documentation. It is not a completed runtime, security or legal audit.
