# TianGuía

**Find the stall. Discover the product. Connect with the seller.**

TianGuía is a student software engineering project building a mobile companion
for Mexico's *tianguis*: local markets made up of individual stalls. Its goal is
to help shoppers find products and sellers, and help vendors make their stalls,
availability, and merchandise easier to discover.

Finding a particular item can mean walking through an entire market without
knowing whether the seller is there that day. TianGuía brings together a stall
directory, product information, location, and direct communication to make those
visits easier to plan and navigate.

## Who it is for

| Audience | What TianGuía aims to help them do |
| --- | --- |
| Shoppers | Find products and open stalls, check availability, and contact sellers before visiting. |
| Vendors | Share where they are operating, maintain a product catalog, and coordinate with customers and other vendors. |
| Administrators and moderators | Maintain market information and support a trustworthy community through reports and review. |

The design prioritizes clear actions and legible interfaces for people with
different levels of familiarity with technology.

## Project vision

The software requirements specification
defines the broader direction of the project:

- **Discovery and location:** search products, filter by market or category, and
  consult a map of open stalls using the location vendors record when opening.
- **Vendor visibility:** manage stall status, product descriptions, photos,
  availability, and temporary offers.
- **Direct coordination:** discuss products, propose prices, request temporary
  reservations (*apartados*), and exchange information about market spaces.
- **Community and trust:** follow favorites, choose notifications, confirm
  in-person visits, leave ratings, and use reporting and moderation tools.

These are design goals that guide development, rather than a list of features
available in every build. The project board tracks priorities and progress.

TianGuía supports in-person commerce. Payments and exchanges take place directly
between participants; payment processing, commissions, shipping, and legally
formalizing agreements are outside the project's scope. Stall locations represent
the last position recorded for a market day, without continuous vendor tracking.

## Engineering and academic context

TianGuía originated as an Ingeniería en Computación project at the
**Universidad de Guadalajara, Centro Universitario de Ciencias Exactas e
Ingenierías (CUCEI)**.

The requirements document connects the problem statement to functional and
nonfunctional requirements, use cases, user stories, a conceptual domain model,
and a traceability matrix. Initial input came from interviews with five vendors
and four shoppers, providing qualitative guidance for the design.

Development aims to carry those needs through implementation and review, with
particular attention to usability, privacy, permissions, timely market
information, and interruptions in connectivity.

## Technology and repository layout

The app uses **Flutter and Dart**, with **Supabase** for authentication,
PostgreSQL data, image storage, and realtime messaging. Android is the mobile
platform configured in this repository.

```text
lib/
  config/       Theme and Supabase configuration
  models/       Domain data models
  screens/      Flutter screens and tabs
  services/     Authentication and domain operations
supabase/       Database security/functions script and optional sample data
android/        Android application and build configuration
```

## Run locally

### Prerequisites

Install Flutter stable and Android Studio with the Android SDK, and add Flutter's
`bin` directory to your `PATH`. Flutter uses Android Studio's bundled JDK for
Android builds.

```sh
git clone https://github.com/Tianguia/Tianguiapp.git
cd Tianguiapp
flutter doctor -v
flutter pub get
```

### Backend configuration

The app reads `SUPABASE_URL` and `SUPABASE_KEY` through Dart compile-time defines
in [SupabaseConfig](lib/config/supabase_config.dart). That file includes default
project settings; pass overrides to connect to your own development backend.
Use a client publishable/anon key, and keep privileged service-role keys out of
the app.

A compatible Supabase database is required for the app's data flows. The
[supabase directory](supabase/) contains security policies, functions, and
optional seed data. These scripts work with existing application tables;
the SQL that creates those tables, their columns, relationships, and custom
types is not included in this repository. To use a fresh Supabase project,
that database structure must be supplied before running the scripts.
Authentication uses anonymous sign-in for shoppers and email OTP for
vendor/administrator access, so configure those methods in your backend.

### Launch on Android

Connect a phone with USB debugging enabled or start an Android emulator:

```sh
flutter devices
flutter run -d <device-id> --dart-define=SUPABASE_URL=<project-url> --dart-define=SUPABASE_KEY=<publishable-key>
```

The same `--dart-define` options can be passed to build commands:

```sh
flutter build apk --debug
flutter build apk --release
```

APKs are written to `build/app/outputs/flutter-apk/`. Release builds use the
project's debug signing configuration; configure release signing before store
distribution.

<details>
<summary>Windows and Android setup notes</summary>

The existing local setup notes record Flutter 3.47.8, Android compile SDK 36, and
NDK 28.2.13676358. The Gradle configuration takes SDK and NDK versions from the
installed Flutter SDK. Install the requested NDK through Android Studio's
**SDK Manager > SDK Tools > Show Package Details > NDK (Side by side)**.

With the newer Android CLI, the recorded installation command is:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\android.exe" sdk install 'ndk/28.2.13676358'
flutter doctor --android-licenses
```

If `sdkmanager.bat` fails when Gradle requests `ndk;28.2.13676358`, try the direct
`android.exe` command above where that CLI is installed.

`android/gradle.properties` disables Kotlin incremental compilation to avoid
cache issues when the checkout and Pub cache are on different Windows drives.
Visual Studio's C++ workload is only needed for Windows desktop development.

</details>

<details>
<summary>Browser development with Brave</summary>

Where a Flutter web target is configured, Brave can be selected through
`CHROME_EXECUTABLE`. Set its path without embedded quotation marks:

```powershell
$browserPath = "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe"
[Environment]::SetEnvironmentVariable('CHROME_EXECUTABLE', $browserPath, 'User')
$env:CHROME_EXECUTABLE = $browserPath
flutter run -d chrome
```

Restart existing terminals and IDEs after changing persistent environment
variables.

</details>

## Contributing

Contributions to code, documentation, accessibility, interface design, and
requirements review are welcome. Experience with tianguis as a shopper or vendor
is especially useful when discussing how the app should behave.

1. Review the requirements document and project board, then check existing
   [issues](https://github.com/Tianguia/Tianguiapp/issues) for related work.
2. Open an issue to describe a bug or discuss a substantial change. For bugs,
   include reproduction steps, expected behavior, and the device/platform.
3. Work on a focused branch and submit a pull request explaining the problem,
   the change, and how you verified it. Link the related issue and relevant
   requirement when applicable; include screenshots for interface changes.

Before submitting Dart changes, format the code and run static analysis:

```sh
dart format lib
flutter analyze
```

Include relevant tests when adding or changing behavior, and describe any manual
checks that need a device or configured backend. Keep credentials and personal
user data out of issues, screenshots, and commits.

## License

A license file has not yet been added. Reuse and redistribution terms still need
to be established by the project maintainers.
