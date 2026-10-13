# RUSMEDIA app (Flutter)

Platform folders (android/, ios/, web/) are not included. Generate them once:

```
flutter create . --project-name rusmedia_app --platforms=android,ios,web
flutter pub get
flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
# Android emulator: --dart-define=API_BASE_URL=http://10.0.2.2:8080
```
