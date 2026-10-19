@echo off
cd "D:\FlutterDev\v2\4. filosign - fixing quiz and practice"
flutter analyze lib/learn/live_sign_lesson_screen.dart 2>errors.txt
type errors.txt
pause