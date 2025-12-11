# iOS Build Instructions for CityGo Supervisor

## Prerequisites

⚠️ **Important**: iOS builds require **macOS** and **Xcode**. You cannot build iOS apps on Windows.

### Required Software:
1. **macOS** (Mac computer or Mac virtual machine)
2. **Xcode** (latest version from Mac App Store)
3. **CocoaPods** (iOS dependency manager)
4. **Flutter** (already installed)

## Step 1: Install CocoaPods

On your Mac, open Terminal and run:

```bash
sudo gem install cocoapods
```

## Step 2: Navigate to iOS Folder

```bash
cd ios
```

## Step 3: Install iOS Dependencies

```bash
pod install
```

This will install all iOS-specific dependencies (Google Maps, NFC Manager, etc.)

## Step 4: Open in Xcode (Optional)

You can open the project in Xcode to configure signing:

```bash
open Runner.xcworkspace
```

**Note**: Always open `.xcworkspace`, NOT `.xcodeproj`

## Step 5: Configure Signing in Xcode

1. In Xcode, select the **Runner** project in the left sidebar
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Check **"Automatically manage signing"**
5. Select your **Team** (Apple Developer account)
6. Xcode will automatically generate a provisioning profile

### If you don't have an Apple Developer account:
- You can still test on your iPhone using a **free Apple ID**
- Xcode will create a temporary certificate (valid for 7 days)
- You'll need to re-sign every 7 days

## Step 6: Connect Your iPhone

1. Connect your iPhone to your Mac via USB
2. Unlock your iPhone
3. Trust the computer if prompted
4. In Xcode, select your iPhone from the device dropdown (top toolbar)

## Step 7: Build and Run

### Option A: Using Flutter CLI (Recommended)

```bash
# From project root
flutter run -d <your-iphone-id>
```

To see available devices:
```bash
flutter devices
```

### Option B: Using Xcode

1. Select your iPhone as the target device
2. Click the **Play** button (▶️) or press `Cmd + R`
3. Xcode will build and install the app on your iPhone

### Option C: Build IPA for Distribution

```bash
flutter build ios --release
```

This creates an IPA file that can be distributed via TestFlight or App Store.

## Troubleshooting

### Issue: "No Podfile found"
**Solution**: The Podfile should be in the `ios/` folder. If missing, run:
```bash
cd ios
pod init
```

### Issue: "CocoaPods not installed"
**Solution**: 
```bash
sudo gem install cocoapods
```

### Issue: "Signing certificate not found"
**Solution**: 
1. Open Xcode
2. Go to Xcode → Preferences → Accounts
3. Add your Apple ID
4. Select your team in Signing & Capabilities

### Issue: "Device not trusted"
**Solution**: 
1. On your iPhone: Settings → General → Device Management
2. Trust the developer certificate

### Issue: "NFC not working"
**Note**: NFC requires:
- iPhone 7 or later
- iOS 11.0 or later
- The app must be running in foreground

## Testing Checklist

- [ ] App installs on iPhone
- [ ] App icon shows correctly
- [ ] App name shows "CityGo Supervisor"
- [ ] Login screen works
- [ ] Maps display correctly
- [ ] Location permissions work
- [ ] NFC reading works (if iPhone 7+)
- [ ] All screens display correctly
- [ ] Text doesn't overflow

## Next Steps

After successful testing:
1. **TestFlight**: Upload to TestFlight for beta testing
2. **App Store**: Submit for App Store review
3. **Distribution**: Share with other testers

## Notes

- **Free Apple ID**: Can test on your own device for 7 days
- **Paid Developer Account ($99/year)**: 
  - Test on multiple devices
  - Distribute via TestFlight
  - Submit to App Store
  - No 7-day expiration

---

**Need Help?** Check Flutter iOS documentation: https://docs.flutter.dev/deployment/ios

