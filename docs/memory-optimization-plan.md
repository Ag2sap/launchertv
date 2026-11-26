# LauncherTV memory optimization — first pass

## Scope and safety boundaries

This branch targets LauncherTV's own Qt Quick memory footprint on the HG680P (720x576, 2 GB RAM class).

The following remain unchanged:
- RoxyTube and its running process.
- mpv, hardware decoding, and video playback settings.
- Xorg, Openbox, display resolution, audio, IR, and device services.
- LauncherTV features, navigation model, layout, and visual design.

No device configuration or installation is changed by this branch.

## Findings from the initial code review

1. The two full-screen wallpaper Image items used for crossfade did not specify `sourceSize`. Large wallpaper files could therefore be decoded at much larger dimensions than the 720x576 display requires.
2. Every category AppRow used `ListView.cacheBuffer: 3000`, allowing a wide off-screen prefetch region for each row.
3. The Most Used ListView used `cacheBuffer: 2000`, despite showing only six entries.

## First-pass changes

- Bound both crossfade wallpaper images to the root window dimensions using `sourceSize`.
- Reduce category row cacheBuffer from 3000 to 600 pixels.
- Reduce Most Used cacheBuffer from 2000 to 350 pixels.
- Keep icon caching, animations, app discovery, weather, navigation, and all application launch behavior unchanged.

## Validation required on HG680P

Compare LauncherTV PSS (not only RSS) before and after, with the same wallpaper, app list, screen resolution, and Home screen state. Keep RoxyTube and mpv running for the concurrent-use comparison.

Record:
- LauncherTV PSS/RSS from `/proc/<pid>/smaps_rollup`.
- System `MemAvailable`.
- Home navigation responsiveness, including rapid left/right and vertical row navigation.
- Wallpaper initial load and slideshow crossfade quality.
- Any missing icons or delegate-loading delay.

Repeat the comparison in these states:
1. LauncherTV Home idle.
2. LauncherTV while RoxyTube and mpv are running in the background.

## Acceptance criteria

- No visual/layout regressions at 720x576.
- Remote navigation remains responsive.
- Wallpaper and slideshow continue working.
- App icons remain correct.
- LauncherTV PSS decreases or remains stable without increasing memory pressure.
- RoxyTube/mpv playback behavior remains unchanged.

The memory reduction is not assumed in advance; it must be measured on the target device.
