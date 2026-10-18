# Sleep Left

See how long remains until your alarms, right in Apple's Clock app.

Sleep Left appends a live hours/minutes/seconds countdown to each ordinary
alarm's existing subtitle. Custom labels and native alarm controls stay in place.
Enabled and disabled alarms both show a countdown; a disabled alarm's countdown
previews its configured next occurrence and does not mean it will ring.

The tweak does not change snooze duration, delay alarms, enable disabled alarms,
or alter alarm scheduling. Sleep/Wake Up is excluded. There is no separate app or
settings bundle.

Free and MIT licensed. Original implementation by **0chium**. Uses the owner-approved crescent artwork.

## Install and use

1. Use a compatible conventional rootless jailbreak with a Substrate-compatible
   tweak loader. The specific owner-tested configurations are listed below.
2. If you use AlarmTime, block its Clock injection first using the coexistence
   instructions below.
3. Add **https://0chium.github.io/** to Sileo, refresh sources, and install
   **Sleep Left** (`com.ochium.sleepleft`). Review the transaction
   before confirming. A manual `.deb` download is also available from the
   [package page](https://0chium.github.io/depictions/sleepleft.html).
4. Fully close and reopen Clock, then open Alarms. Ordinary alarm subtitles show
   the countdown automatically; no configuration is needed.

The package depends on `mobilesubstrate`. It contains arm64 and arm64e slices and
uses the rootless `iphoneos-arm64` package layout. Its iOS 17–18 package/runtime
bounds are technical guards, not a claim that all builds in that range work.

The public package conflicts with and replaces `com.ochium.fivemoreminutes`,
the private alpha identity, so both cannot be installed together. The internal
loader name remains **FiveMoreMinutes**; this is also its entry in Choicy.

## Owner-tested configurations

| Device | iOS | Build |
| --- | --- | --- |
| iPhone 14 Pro | 17.0 | 21A329 |
| iPhone 11 Pro Max | 18.3.2 | 22D82 |

The owner reports that **0.1.0~alpha1** passed the initial functional checks on
both configurations with AlarmTime blocked through Choicy: enabled/disabled
countdowns, custom labels, editing/toggling, scrolling without duplicate or
mismatched text, and correct catch-up after leaving and returning to Clock.

These are owner-reported functional passes. They are not comprehensive
compatibility, calendar, accessibility or performance certification. The final
**0.1.0** package is a release metadata/presentation build of the same source
implementation; it has not itself received device testing.

## Limitations

- Sleep/Wake Up alarms are not included.
- No blanket iOS 17/18 support is advertised. iOS 26 is unsupported. Other device,
  OS and bootstrap combinations, including RootHide conversion, are unverified.
- Recurrence/DST boundaries, time-zone edge cases and snooze-state edge cases
  have not been comprehensively tested. Apple supplies occurrence dates; that
  does not certify every edge case in this integration.
- VoiceOver custom content, large accessibility text and actual timer inactivity
  have not been verified by owner testing. No CPU, battery or reliability
  measurements are claimed.
- Countdown units are currently English. The original native subtitle retains
  Apple's own text and formatting. An unfamiliar model/layout contract or a
  missing future date leaves the native row undecorated.

## AlarmTime coexistence

Do not let AlarmTime and Sleep Left modify Clock's rows at the same time.
No automatic removal or disablement is performed.

With the existing Choicy controls, open **Settings → Choicy → Applications →
Clock** and record the current configuration. Enable **Custom Tweak Configuration**.
In **Deny** mode, mark **AlarmTime ON** to block it and leave **FiveMoreMinutes
OFF** in that deny list. Preserve other entries. If you already use **Allow**
mode, keep that mode and set AlarmTime OFF / FiveMoreMinutes ON instead.
Do not use Disable Tweak Injection for Clock: that blocks both tweaks.

Fully close Clock before reopening it. To return to AlarmTime later, first block
FiveMoreMinutes, restore AlarmTime's previous selection and the prior Clock
configuration, then close and reopen Clock. Other existing tweak managers may
provide equivalent per-app controls; their behavior is not certified here.

## Implementation and what we learned

- **Apple supplies the next occurrence.** The model received from Clock provides
  `nextFireDateAfterDate:`; we display its result without creating an alarm engine
  or changing the model's scheduling state.
- **Native subtitle and controls.** We capture Apple's formatted subtitle and
  append the countdown. A narrow subtitle-width adjustment gives the text room
  while retaining native fonts, enabled/disabled colors, controls and row sizing.
- **One visible-list timer.** A single timer updates the visible, active ordinary
  alarm list once per second. Controller/scene inactivity stops it. A tick
  subtracts the current wall time from Apple's occurrence date, so delayed ticks
  catch up instead of accumulating drift.
- **Original text is retained.** Each native refresh replaces the base subtitle
  and model. Reuse clears the association. Each countdown is regenerated from
  that base text, which prevents repeatedly appending another suffix.
- **VoiceOver custom content is a choice.** Clock constructs its spoken cell
  label separately. We offer time remaining as on-demand custom content without
  replacing its time/on-off speech or actions. This behavior remains unverified
  by owner testing.

Native refresh/reuse and controller lifecycle callbacks handle ordinary UI
changes. Foreground and relevant clock/time-zone notifications discard cached
visible dates. These decisions describe this implementation; they do not imply
knowledge of AlarmTime's internals or superiority over it.

## Source, support and credits

- [Source](https://github.com/0chium/SleepLeft)
- [Support and issue reports](https://github.com/0chium/SleepLeft/issues)
- [Changelog](CHANGELOG.md) · [Build instructions](BUILDING.md) · [MIT license](LICENSE)

For an issue, include the package version, device model, iOS/build, bootstrap,
reproduction steps, and whether other Clock tweaks were blocked. Remove passwords,
unique device identifiers and other private information from public attachments.
Screenshots are optional.

**Inspired by AlarmTime by P2KDev. Independently implemented.**

Sleep Left is 0chium's independent implementation, not an AlarmTime fork
or an endorsed continuation. P2KDev is credited for the inspiration, not for code
contribution or endorsement. No AlarmTime code or artwork is included. Original
code and the included artwork are distributed under the MIT license; Apple frameworks and the device-provided hook
library retain their respective ownership and are not redistributed here.
