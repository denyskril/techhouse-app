# TechHouse iOS Client

A SwiftUI prototype that brings a Telegram-inspired experience to XenForo forums hosted at `test.techhouse.vip`.

## Highlights
- **SwiftUI + async/await** networking layer talking to XenForo REST endpoints.
- **Telegram-style UI** for thread list, messaging view, notifications, and profile.
- **Secure storage** abstraction that writes API tokens to Keychain on device (UserDefaults fallback for previews).
- **Configurable secrets** via `XF_API_KEY` env var with provided fallback key.
- **Composable architecture**: dedicated view models per feature, shared components (avatars, message bubbles, search bar) and theming.

## Getting Started
1. Open the package in Xcode 15+: `File > Open` and choose the repo folder.
2. Ensure you are on iOS 17 SDK or newer. SwiftPM will generate a simple app target from `@main` entry point.
3. (Optional) Override the API key for safety before shipping:
   ```bash
   export XF_API_KEY="your-rotated-key"
   ```
4. Hit Run. On login, supply your XenForo credentials; the provided API key is already baked in for the staging forum.

## Architecture
- `App/` – bootstrap, dependency container, global session state.
- `Config/` – static configuration and secrets helper.
- `Data/` – HTTP client, request builder, API-facing models.
- `Features/` – SwiftUI screens + view models by domain (threads, conversations, alerts, profile, composer).
- `Shared/` – Theming, components, utilities.

### Networking
`XenForoAPI` wraps REST calls for login, threads, posts, conversations, alerts, and replies. Extend it with additional endpoints (attachments, reactions, moderation) as needed. The service expects the XenForo API add-on to be enabled and accessible at `/api/*`.

### Push Notifications
APNs integration is not wired yet. Add an intermediary service that listens for XenForo webhooks and triggers device tokens, then surface them via `PushNotificationManager` (future work).

## Roadmap
- Implement thread creation API bridge inside `ComposerSheet`.
- Flesh out `ConversationDetailView` with DM timeline + composer.
- Add offline caching (Core Data/SQLite) for thread lists.
- Integrate real-time updates through polling or WebSockets.
- Harden error handling and add unit/UI tests once Xcode workspace exists.

## Testing
`TechHouseAppTests` currently exercises view-model level filtering. Expand with mocks for networking to cover additional flows.

## Security
The included API key is for staging only. Rotate keys regularly, restrict IPs if possible, and prefer injecting secrets at build time using `.xcconfig` or CI secrets instead of shipping them inline.
