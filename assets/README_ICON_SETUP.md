# App Icon Setup Instructions

## Step 1: Save the Logo Image

1. Save the CityGo Supervisor logo image as `app_icon.png` in the `assets/` folder
2. **Recommended size**: 1024x1024 pixels (square)
3. **Format**: PNG with transparent background (if possible)
4. The image should be high quality for best results

## Step 2: Generate Icons

After saving the image, run:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will automatically generate all required icon sizes for:
- Android (all densities)
- iOS (all sizes)
- Web (favicon)
- Windows
- macOS
- Linux

## Step 3: Rebuild the App

After generating icons, rebuild your app:

```bash
# For Android
flutter clean
flutter build apk

# For iOS
flutter clean
flutter build ios
```

## Notes

- The icon will be generated in all required sizes automatically
- Make sure the source image is square (1:1 aspect ratio)
- For best results, use a PNG with transparent background
- The icon will appear after rebuilding the app

