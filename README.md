# HTools
50+ Hacking Tools Collection

## Phone Diagnostics Script

Use `phone_diagnose.sh` to collect basic software and hardware status from a
connected Android or iOS device (via USB) and save a markdown report.

### Examples

```bash
./phone_diagnose.sh --android
./phone_diagnose.sh --ios
```

### Requirements

- Android: `adb` from Android platform tools.
- iOS: `ideviceinfo` and `idevicediagnostics` from `libimobiledevice`.
