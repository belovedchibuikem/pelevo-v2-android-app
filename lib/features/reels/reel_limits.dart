const Duration reelMaxDuration = Duration(minutes: 3);

String get reelMaxDurationLabel => '3 minutes';

String get reelTruncatedMessage =>
    'Your video was longer than $reelMaxDurationLabel, so we kept the first $reelMaxDurationLabel and discarded the rest.';
