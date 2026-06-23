# Roost App Store Submission Packet

This packet collects the App Store Connect fields and assets for the first Mac App Store submission.

## App Information

- App name: Roost
- Bundle ID: `com.ivynbean.Roost`
- SKU: `roost-macos`
- Primary language: English (U.S.)
- Primary category: Productivity
- Secondary category: Utilities
- App Store category in bundle: `public.app-category.productivity`
- Version: `1.0`
- Build: `1`
- Minimum macOS: macOS 14.0
- Copyright: Copyright (c) 2026 ivynbean. All rights reserved.

## Product Page Copy

Subtitle:

```text
Catch notes, links, and files
```

Promotional text:

```text
Roost is a cheerful, local-first desktop catch-all for the small things you do not want to lose: links, files, screenshots, quick notes, projects, and today's context.
```

Description:

```text
Roost is a native macOS workspace for catching links, files, screenshots, and loose notes before they scatter.

Keep a compact catch box above your desktop, paste or drag in anything worth saving, and let Roost sort it into useful collections like Work, Code, Design, Money, Travel, Shopping, Media, Docs, Tools, Screenshots, and Read Later.

Roost also includes an Agenda-style notes area for day-based notes, project organization, pinned "On the Agenda" items, and optional read-only calendar context. Everything is stored locally on your Mac.

Highlights:
- Capture URLs, file URLs, file paths, clipboard contents, screenshots, and quick notes
- Organize saved items by project, tag, and smart collection
- Add notes to saved bookmarks
- Keep day-grouped notes and project notes in one place
- Optionally show today's calendar events beside your notes
- Store everything locally, with no analytics or tracking
```

Keywords:

```text
notes,bookmarks,links,files,screenshots,projects,productivity,organizer,local
```

Support URL:

```text
https://github.com/ivynbean/Roost/issues
```

Privacy Policy URL:

```text
https://github.com/ivynbean/Roost/blob/main/docs/PrivacyPolicy.md
```

Marketing URL:

```text
https://github.com/ivynbean/Roost
```

## App Privacy

Recommended App Store Connect privacy declaration:

- Data collection: No data collected by the developer
- Tracking: No
- Third-party advertising: No
- Analytics: No
- Product personalization: No

Notes for the questionnaire:

- Notes, bookmarks, tags, projects, file references, screenshots, and preferences are stored locally on the user's Mac.
- Calendar access is optional and read-only.
- Network access is used only to fetch web page titles for saved links.
- Roost does not upload user content to developer servers.

## Age Rating

Likely rating: 4+

Suggested questionnaire posture:

- No objectionable content included by the app.
- No gambling, contests, medical treatment information, unrestricted social networking, or user-to-user communication.
- Roost can store user-entered text and links locally, but does not publish or share that content.

Confirm these answers manually in App Store Connect before submission.

## Assets Already In Repo

App icon sources:

- `assets/AppIcon.iconset/icon_512x512@2x.png` - 1024 x 1024
- `assets/AppIcon.iconset/` - complete Mac iconset sizes
- `Sources/Roost/Resources/Roost.icns` - bundled app icon
- `assets/roost-icon-square.png` - source square icon

Privacy and signing assets:

- `Sources/Roost/Resources/PrivacyInfo.xcprivacy`
- `entitlements/AppStore.entitlements`
- `script/package_app_store.sh`

## Screenshots Needed

Apple requires Mac screenshots for Mac apps. Accepted Mac screenshot sizes are 16:10:

- 1280 x 800
- 1440 x 900
- 2560 x 1600
- 2880 x 1800

Recommended first submission set:

1. Library view with sidebar, collections, notes, and detail panel
2. Compact Roost catch box with a link/file capture example
3. Today or project notes view showing local-first notes and optional calendar context
4. Settings view showing calendar and screenshot options

Store final screenshots in:

```text
assets/AppStoreScreenshots/Mac/
```

## Build Upload

Use the repo helper after Apple signing assets are available:

```bash
APP_STORE_PROVISIONING_PROFILE="/path/to/profile.provisionprofile" \
APP_SIGN_IDENTITY="Apple Distribution: Your Team Name (TEAMID)" \
APP_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Team Name (TEAMID)" \
./script/package_app_store.sh
```

The upload package should be:

```text
dist/Roost-AppStore.pkg
```

## Remaining Manual Items

- Confirm the Apple Developer team name and Team ID.
- Create or confirm the App Store Connect app record for `com.ivynbean.Roost`.
- Host the privacy policy URL on a public page before review.
- Capture final Mac screenshots at one accepted 16:10 size.
- Review artwork license rights for the chick/icon assets.
- Fill App Privacy, Age Rating, Pricing, Availability, and Export Compliance in App Store Connect.
