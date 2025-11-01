# Changelog

## [Unreleased]
- Restore aircraft and category icons by forcing Tacview to build root-relative image paths from both debriefing entry points; verified by running `php -S localhost:8000 -t public` against the sanitized Tacview sample.
- Prevent Vercel from serving PHP files as downloads by ignoring the local-only `public/debriefing.php` and routing `/debriefing.php` to the serverless handler.
- Mirror CSS-based sticky header implementation for public deployment assets.
- Sync debriefing script comments clarifying sticky header behavior.
- Refresh mod aircraft thumbnails (A-4E Skyhawk, F-104 Starfighter) with 640x360 Wikimedia imagery so production icons stay in parity with the main bundle.
- Stop rerouting Skyhawk and Starfighter requests to surrogate jets now that refreshed thumbnails exist; Hind icon already ships in lower-case `.jpg` form for Linux parity.
