# Changelog

## [Unreleased]
- Prevent Vercel from serving PHP files as downloads by ignoring the local-only `public/debriefing.php` and routing `/debriefing.php` to the serverless handler.
- Mirror CSS-based sticky header implementation for public deployment assets.
- Sync debriefing script comments clarifying sticky header behavior.
