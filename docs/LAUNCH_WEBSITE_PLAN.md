# Airclip landing page plan

Planning draft · 11 September 2026 · No website or app changes made.

Working assumption: a free public beta for people who use a Mac and Android phone, with direct downloads and no account. Pricing, domain ownership and signing membership remain open decisions.

## What Dockset does well

Inspected the live [homepage](https://dockset.app/) and [pricing page](https://dockset.app/pricing).

The homepage uses a white background, oversized serif headline, restrained navigation, and floating product examples. Its structure is promise → visual examples → everyday scenarios → smaller benefits → attributed testimonials → FAQ → repeated download/purchase action. Price and refund reassurance sit close to the primary action. Support, changelog, privacy and maker identity make the small product feel maintained.

The current website offers direct purchasing through Paddle and a download link. Its pricing distinguishes continued use from the period of included updates. This observation does not establish whether it also has an App Store listing. Airclip can use a similar direct-distribution approach.

Borrow the clarity, real product demonstrations and visible maker. Airclip needs fewer feature sections: its core story is one action moving between two devices. Do not duplicate Dockset's visual assets, wording, testimonials or widget-heavy layout. There is no evidence here of Dockset's conversion performance.

## Positioning

Primary audience: someone who works on a Mac and carries an Android phone. Designer/developer examples can support this without excluding other users.

Proposed headline: **Your Mac and Android. One clipboard.**

Supporting copy: **Move text and links between your devices over local Wi-Fi. No account. No cloud clipboard.**

Use this copy only after validating both directions on supported devices. Explain Android's actual send workflow near the demo. Avoid an unconditional claim that every copy in every Android app syncs automatically.

Primary action: **Download for Mac**. Secondary action: **Get Android app**, with a QR link to the Android download page. State that both apps are needed. On phones, place the Android download first while keeping both visible.

## Page outline

| Order | Content | Purpose |
|---|---|---|
| 1 | Logo, How it works, FAQ, Download | Small, predictable navigation |
| 2 | Headline, two download buttons, beta status, supported OS versions | Establish audience and next step immediately |
| 3 | A short real recording: Mac text → Android destination, then Android share/send → Mac | Demonstrate the actual product and required steps |
| 4 | Install both apps → pair once → transfer | Explain setup; mention same reachable local network |
| 5 | Three examples: move a link, reuse a text snippet, retrieve a recent clip | Show everyday value |
| 6 | Local transfer, encryption, no account, local history controls | Answer privacy and control concerns |
| 7 | Small maker story and beta feedback link | Explain why this exists and how to get help |
| 8 | FAQ and final download actions | Resolve installation and compatibility objections |
| 9 | Privacy, installation help, changelog, support, maker link | Establish maintenance and accountability |

Start with one polished product demonstration and three benefit blocks. Use Airclip's existing identity. Keep mobile layout, keyboard navigation, contrast, reduced motion and readable text intact. Give video a poster and playback control; avoid large downloads on initial page load. Use local fonts/assets where practical.

For launch, omit invented social proof, live user counters, unsupported time-saving claims, a blog, accounts, and payment infrastructure. Add real quotes only with permission. A free beta should clearly state that future pricing is undecided and make no lifetime-free promise.

## Supporting pages

- `/download`: DMG and APK; version, release date, actual file size, tested OS/chip support, installation instructions and checksums. QR points here rather than an expiring file URL.
- `/help`: install, pair, first transfer, Android send workflow, blocked discovery, sleep/wake, update steps, uninstall and local-data deletion.
- `/changelog`: dated releases with fixes, known issues and compatible companion versions.
- `/privacy`: distinguish clipboard transfer, local statistics, optional exports, update requests and website hosting logs.

FAQ must answer: Does this need internet? Must both devices share a network? Does it work outside home? What can it transfer? Why might Android require Share or Send? What permissions are needed? Where is history stored? How do updates work? What happens when one device is offline?

## Implementation and launch sequence

1. Confirm audience, beta terms, domain, supported platforms and budget.
2. Complete the release and privacy work in the two companion plans.
3. Record the verified happy path using invented example content.
4. Build a small static website; use Cloudflare Pages for the site and GitHub Releases for binaries. Pages has a 25 MiB per-file limit, so keep installers in release storage. [Pages limits](https://developers.cloudflare.com/pages/platform/limits/).
5. Test download → install → pair → transfer with someone who has never used Airclip. Check phone QR flow and keyboard access too.
6. Launch to a small volunteer cohort; resolve repeated setup failures before broader promotion.

Promotion: a short maker launch post, a workflow video and relevant Mac/Android communities that permit product posts. Website metrics initially mean aggregate traffic and download counts; they do not prove activation or retention. See the metrics plan for how to establish those outcomes.

Ready to publish when both downloads are signed appropriately, compatibility is verified, an update path works, support/privacy pages exist, and every product claim matches a demonstrated behavior.
