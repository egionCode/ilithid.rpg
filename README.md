# ilithid

<p align="center">
  <img src="docs/logo.png" alt="ilithid Logo" width="250">
</p>

**ilithid** is a Flutter-based RPG campaign helper application designed for both Master and Players. It offers real-time synchronization, campaign management, character sheets, and community-driven NPC management using Appwrite.


## Architecture & Project Structure

The project follows a modular, feature-oriented structure with a dedicated `shared` layer for reusable components and configurations.

```
lib/
├── main.dart          # App entry point
├── features/          # Feature-based modular architecture
│   ├── auth/          # Authentication & Profile management
│   ├── campaigns/     # RPG Campaign management
│   ├── characters/    # Character sheets (CRUD)
│   ├── npcs/          # Community-driven NPC library & Session instantiation
│   ├── sessions/      # Game sessions manager
│   └── dashboard/     # Game Master / Player dashboard
└── shared/            # Shared domains
    ├── components/    # Reusable UI widgets / elements
    ├── services/      # Singletons (Appwrite service, storage, etc.)
    ├── theme/         # Design system & dark theme setup
    ├── routing/       # Declarative routing configuration
    └── utils/         # Helpers, constants, formatters
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
- Android SDK / Command Line Tools (for Android builds)
- A modern web browser (for Web builds)

### Installation & Run

1. Clone the repository:
   ```bash
   git clone git@github.com:egionCode/ilithid.rpg.git
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   # Run on connected device/emulator/browser
   flutter run
   ```

### Code Quality & Formatting

To ensure code health and consistency, strict analysis is configured in `analysis_options.yaml`. Please run:

```bash
flutter analyze
```

Before committing code, make sure all warnings are solved.
