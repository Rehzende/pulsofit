# PULSO Mobile App (Flutter)

Student mobile application for the PULSO platform, featuring heart rate monitoring via Bluetooth and workout tracking.

## 🚀 Features

- **Authentication**: Secure login with JWT token storage
- **Premium Dark Theme**: Matches the web application aesthetic
- **Bluetooth Support**: Ready for Magene H303 heart rate monitor connection
- **API Integration**: Connects to FastAPI backend

## 📋 Prerequisites

- Flutter SDK 3.38.3 or higher
- Android Studio / Xcode (for mobile development)
- Running TrainerIoT backend server

## 🛠️ Tech Stack

- **Framework**: Flutter 3.38.3
- **State Management**: Provider
- **HTTP Client**: Dio
- **Secure Storage**: flutter_secure_storage
- **Bluetooth**: flutter_blue_plus
- **Fonts**: Google Fonts (Inter)
- **Animations**: animate_do

## 📦 Installation

1. **Install dependencies**:
   ```bash
   cd mobile_app
   flutter pub get
   ```

2. **Configure API URL**:
   - Open `lib/core/constants.dart`
   - Update `apiUrl` based on your testing environment:
     - **Android Emulator**: `http://10.0.2.2:8000` (default)
     - **Physical Device**: `http://YOUR_COMPUTER_IP:8000` (e.g., `http://192.168.1.100:8000`)

3. **Run the app**:
   ```bash
   # For Android
   flutter run

   # For iOS
   flutter run
   ```

## 🔧 Configuration

### API Endpoints

The app connects to the following endpoints (configured in `lib/core/constants.dart`):

- **Login**: `POST /api/v1/login/access-token`
- **User Info**: `GET /api/v1/users/me`
- **Workouts**: `GET /api/v1/workouts`

### Testing Credentials

Use the following credentials to test the app:

- **Email**: `student@example.com`
- **Password**: `student`

Or use the admin account:

- **Email**: `admin@example.com`
- **Password**: `admin`

## 📱 Running on Different Devices

### Android Emulator

The default configuration works out of the box. The API URL `http://10.0.2.2:8000` maps to your host machine's `localhost:8000`.

### Physical Android Device

1. Ensure your device and computer are on the same network
2. Find your computer's IP address:
   ```bash
   # Linux/Mac
   ifconfig | grep "inet "
   
   # Windows
   ipconfig
   ```
3. Update `apiUrl` in `lib/core/constants.dart` to `http://YOUR_IP:8000`
4. Make sure the backend is running with `--host 0.0.0.0`:
   ```bash
   uvicorn app.main:app --reload --port 8000 --host 0.0.0.0
   ```

### iOS Simulator

Use your computer's IP address (same as physical device instructions above).

## 🏗️ Project Structure

```
mobile_app/
├── lib/
│   ├── core/
│   │   └── constants.dart          # App constants, API URLs, theme colors
│   ├── providers/
│   │   └── auth_provider.dart      # Authentication state management
│   ├── screens/
│   │   ├── login_screen.dart       # Login UI
│   │   └── home_screen.dart        # Home screen (placeholder)
│   └── main.dart                   # App entry point
├── android/                        # Android-specific configuration
├── ios/                            # iOS-specific configuration
└── pubspec.yaml                    # Dependencies
```

## 🎨 Theme

The app uses a premium dark theme matching the web application:

- **Background**: `#09090B`
- **Card Background**: `#18181B`
- **Primary Accent**: `#3B82F6` (Blue)
- **Text Primary**: `#FFFFFF`
- **Text Secondary**: `#A1A1AA`
- **Font**: Inter (via Google Fonts)

## 🔐 Security

- JWT tokens are stored securely using `flutter_secure_storage`
- Tokens are automatically included in API requests via Dio interceptors
- Auto-logout on 401 (Unauthorized) responses

## 📝 Next Steps

The following features are planned for future phases:

- [ ] Workout list screen
- [ ] Workout detail and execution
- [ ] Real-time heart rate monitoring via Bluetooth
- [ ] Workout history and statistics
- [ ] Push notifications
- [ ] Offline mode support

## 🐛 Troubleshooting

### Cannot connect to API

- **Android Emulator**: Ensure backend is running on `http://localhost:8000`
- **Physical Device**: 
  - Verify device and computer are on same network
  - Check firewall settings allow connections on port 8000
  - Confirm API URL in `constants.dart` matches your computer's IP

### Bluetooth permissions

- Ensure location services are enabled on Android (required for BLE scanning)
- Grant location permissions when prompted

### Build errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## 📄 License

Part of the TrainerIoT project.
