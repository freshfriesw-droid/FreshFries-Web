# Fresh Fries LUXE — approved ringtone behavior (22 Nov 2026)

## Behavior contract

| App state | Ringing behavior | Stop condition |
|---|---|---|
| Android app background / screen locked / task closed | Incoming high-priority native notification with restaurant-selected alert. Ring repeatedly when Android permissions and policies allow it. | The employee **opens the notification**, without any obligation to accept the order. |
| Website/application visible in foreground | In-app alert repeats every 3.5 seconds and highlights the respective order card. | For courier offers: **accept the offer**; for cashier orders: **receipt confirmed by the backend**. Cancellation cards stop after cancellation acknowledgment. |
| User switches from foreground to background | Web foreground tone stops immediately; background notification is handled by the OS/native Android channel. | No duplicate web audio in background. |
| Employee opens a background notification and enters the website | Opening notification mutes that already-notified order in the foreground so the ring does not unexpectedly resume; new orders still ring. | Notification open, not receipt confirmation. |

## Implemented in website

- `scripts/luxe-foreground-ring-20261122.js`: foreground alarm, order highlighting, audibility and stop conditions.
- `index.html`: driver-offer and cashier-order DOM identifiers, sound release on confirmation.
- `sw.js`: notification click opens app, informs existing tabs of opening, and preserves the suppression flag on newly opened tabs.
- Background Web Push sender is already in Supabase. **Browser Web Push does not have authority to loop arbitrary MP3/OGG audio while its page is closed.**

## Still required for *actual repeating background audio*

An Android native shell/activity with Firebase Cloud Messaging token registration and server fan-out, a high-importance notification channel with the locally bundled restaurant tone, and explicit permission on Android 13+. The Android framework provides `Notification.FLAG_INSISTENT` (repeat sound until the notification is canceled or the notification shade is opened); whether that meets the exact **tap-only** stopping semantics must be tested on the target phones. If it stops on opening the notification shade before tapping, a carefully-scoped, Android-compliant foreground audio service may be needed. FCM priority does not override Android Do Not Disturb, disabled notification permissions, or battery restrictions.

The existing GitHub repository contains no Android project and no Firebase project configuration. No native Android APK, Firebase sender, or guaranteed continuous background ringtone has been deployed. Do not claim those are complete.

## Device QA gates

1. Foreground driver offer -> sound persists until the backend confirms `accept`; unsuccessful acceptance does not silence it.
2. Foreground cashier order -> sound persists until the backend confirms `cashier_received_at`.
3. Foreground canceled cashier order -> sound persists until the backend confirms cancellation acknowledgment.
4. Notification tap from a hidden tab -> stops the current order's ring without accepting it; new orders still ring.
5. Verify Android locked-screen native ringtone only after native shell and FCM are installed and permissions granted.
6. Verify multi-device deduplication, screen-off behavior, battery saver, permissions, OS Do Not Disturb, and logout.
