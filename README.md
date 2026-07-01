# TCG Search iOS

Minimal SwiftUI iOS client for the existing TCG Search auth API.

## Auth Contract

The app calls the current backend endpoints:

- `POST /api/auth/signup`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`

Request and response JSON matches the backend snake_case contract, including
`device_id`, `refresh_token`, `access_token`, `token_type`, and `expires_in`.
Token pairs are stored in Keychain.

## Card Search Contract

Screen-level card search API requirements are documented in
`docs/card-search-api-requirements.md`.

## Local Backend URL

The default API base URL is set in `TCGSearch/Info.plist`:

```xml
<key>TCGSearchAPIBaseURL</key>
<string>http://localhost:8080</string>
```

This works for iOS Simulator when the backend is running on the Mac. For a real
device, change it to the Mac's LAN address.

## Verification

Once Xcode license setup is complete, run:

```sh
swift test
xcodebuild -project TCGSearch.xcodeproj -scheme TCGSearch -sdk iphonesimulator -configuration Debug build
```
