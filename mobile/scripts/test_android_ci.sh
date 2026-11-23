#!/usr/bin/env bash
set -uo pipefail
device="${ANDROID_TEST_DEVICE:-emulator-5554}"
adb -s "$device" wait-for-device
adb -s "$device" logcat -c
: > /tmp/raices-android-tests.log
# Flutter can leave a DDS connection from the preceding test suite on Android.
# One CLI process per suite owns and closes its service connection independently.
# Assertions still fail the job; only transport startup failures are retried.
for suite in integration_test/*_test.dart; do
  result=1
  for attempt in 1 2; do
    adb -s "$device" wait-for-device
    adb -s "$device" shell am force-stop com.inmobiliaria.inmobiliaria_mobile || true
    adb -s "$device" forward --remove-all || true
    echo "Android suite: $suite; attempt: $attempt" | tee -a /tmp/raices-android-tests.log
    timeout --signal=TERM --kill-after=20s 12m flutter test "$suite" -d "$device" --reporter expanded --verbose 2>&1 | tee /tmp/raices-android-suite.log
    result=${PIPESTATUS[0]}
    cat /tmp/raices-android-suite.log >> /tmp/raices-android-tests.log
    if [ "$result" -eq 0 ]; then break; fi
    adb -s "$device" logcat -d -t 2000 > /tmp/raices-android-logcat.log
    if [ "$attempt" -eq 1 ] && grep -Eq 'Failed to start Dart Development Service|adb: device offline|Lost connection to device' /tmp/raices-android-suite.log; then
      echo 'Se reintenta únicamente esta suite por un fallo de conexión, con DDS habilitado.'
    else
      tail -n 250 /tmp/raices-android-logcat.log
      exit "$result"
    fi
  done
  if [ "$result" -ne 0 ]; then exit "$result"; fi
done
