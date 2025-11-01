# Changelog

## [Unreleased]
- Dynamically detect the correct asset base for CSS and icon bundles across `/`, `/public`, and `/api` entry points so Docker and Vercel deployments render with full styling.
- Prefer the `/public` asset bundle when both `/core` and `/public` sprites exist so root-level requests reuse the CDN-friendly copies without sacrificing CLI fallbacks.
- Point the public API bootstrap directly at the shared config and core Tacview engine so Vercel deployments follow the same include path as the local entry point.
- Restore aircraft and category icons by forcing Tacview to build root-relative image paths from both debriefing entry points; verified by running `php -S localhost:8000 -t public` against the sanitized Tacview sample.
- Prevent Vercel from serving PHP files as downloads by ignoring the local-only `public/debriefing.php` and routing `/debriefing.php` to the serverless handler.
- Mirror CSS-based sticky header implementation for public deployment assets.
- Sync debriefing script comments clarifying sticky header behavior.
- Refresh mod aircraft thumbnails (A-4E Skyhawk, F-104 Starfighter) with 640x360 Wikimedia imagery so production icons stay in parity with the main bundle.
- Stop rerouting Skyhawk and Starfighter requests to surrogate jets now that refreshed thumbnails exist; rename Hind icon to lower-case `.jpg` so Linux deployments load it.
- Normalize aircraft objects during event processing so OV-10 Bronco entries retain their corrected name throughout the mission log instead of reverting to the DCS-exported B-1 alias.
- Skip Tacview events lacking a `PrimaryObject` to prevent PHP notices when support objects (e.g., weapon-only records) bubble into the feed.
- Resolve missing building category sprites by probing coalition-specific and neutral fallbacks before defaulting to the car glyph, eliminating 404s during mission log playback.
