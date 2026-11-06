@echo off
cd "D:\FlutterDev\v2\4. filosign - fixing quiz and practice"
flutter analyze lib/learn/lesson_player_screen.dart lib/learn/live_sign_lesson_screen.dart 2>&1
echo Analyze complete
pause