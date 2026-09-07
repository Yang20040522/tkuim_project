# ZEGO 1-to-1 Video Call MVP

The student demo/testing project's ZEGO AppID and AppSign are embedded in the
Flutter call configuration so every team member can run the same project
without additional credential setup.

Run:

```text
flutter pub get
flutter run
```

Build a debug APK:

```text
flutter build apk --debug
```

This MVP intentionally has no incoming-call invitation. Both participants open
the same chat and tap the video button to join the deterministic room.

> The embedded AppID/AppSign are only for this student demo/testing project.
> Production should replace client-side AppSign authentication with a
> server-issued ZEGO token.
