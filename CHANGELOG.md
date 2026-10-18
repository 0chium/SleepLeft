# Changelog

## 0.1.0 — first public release

- Live hours/minutes/seconds in ordinary Clock alarm subtitles, including
  configured countdowns on disabled alarms.
- Preserves native labels and alarm controls; does not change snooze or scheduling.
- Released as Sleep Left (`com.ochium.sleepleft`) with the approved crescent
  artwork, public source/support links and documentation. MIT license retained.
- Conflicts with and replaces the private `com.ochium.fivemoreminutes` alpha;
  internal injection names remain FiveMoreMinutes. No scheduling or UI behavior changes.

The implementation source is unchanged from 0.1.0~alpha1. The owner reports that
alpha passed the initial functional checks on iPhone 14 Pro / iOS 17.0 / 21A329
and iPhone 11 Pro Max / iOS 18.3.2 / 22D82, without another alarm-countdown tweak active.
The final 0.1.0 release package has not itself received device testing.

Sleep/Wake Up is excluded. Calendar edge cases, VoiceOver, large text, performance
and other configurations are not certified. No blanket iOS 17/18 or iOS 26
support is claimed.

Inspired by AlarmTime by P2KDev. Independently implemented.
