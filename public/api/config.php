<?php

declare(strict_types=1);

/**
 * PHPTacview Configuration - Brownwater
 */

return [
    // Group branding
    'group_name' => 'Brownwater',
    'logo_path' => 'merc_logo.png',
    'logo_alt' => 'Merc Logo',
    'group_link' => 'https://docs.google.com/spreadsheets/d/1gPK4ps2OQMKksESTPCNcuA6Ck8J7WJzPetBlyE4UP7I/edit?gid=923906759#gid=923906759&range=I1',

    // Page settings
    'page_title' => 'PHP Tacview Debriefing',
    'default_language' => 'en',

    // Paths (relative to project root)
    'debriefings_path' => 'debriefings/*.xml',
    'core_path' => 'php-tacview-core',  // Path to the fetched shared core bundle relative to project root
    // EventGraph aggregator tuning
    'aggregator' => [
        'time_tolerance' => 1.5,
        'hit_backtrack_window' => 5.0,
        'anchor_tolerance' => 120.0,
        'anchor_min_matches' => 3,
        'max_fallback_offset' => 900.0,
        'max_anchor_offset' => 14400.0,
        'mission_time_congruence_tolerance' => 1800.0,
    ],
];
