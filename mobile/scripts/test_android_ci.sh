#!/usr/bin/env bash
set -uo pipefail
device="${ANDROID_TEST_DEVICE:-emulator-5554}"
adb -s "$device" wait-for-device
flutter test integration_test -d "$device" --reporter expanded 2>&1 | tee /tmp/raices-android-tests.log
result=${PIPESTATUS[0]}
if [ "$result" -ne 0 ] && grep -Eq 'Failed to start Dart Development Service|adb: device offline|Lost connection to device' /tmp/raices-android-tests.log; then
  echo 'La conexión del ejecutor al emulador falló; se reintenta una vez con DDS habilitado.'
  adb -s "$device" wait-for-device
  flutter test integration_test -d "$device" --reporter expanded
  exit $?
fi
exit "$result"
