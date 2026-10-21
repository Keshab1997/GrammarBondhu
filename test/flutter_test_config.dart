import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test in this directory — `flutter test` picks this file up
/// automatically when it is named `flutter_test_config.dart`.
///
/// Why it exists: `rootBundle` is a `CachingAssetBundle`, so it stores the
/// *Future* of each asset read keyed by asset path. A future that was created
/// inside one widget test's fake-async zone stays cached after that test ends,
/// and the next test in the same file awaits it in a zone that no longer
/// exists — it never completes and the whole file hangs until the CI job is
/// killed (this is what made `app_smoke_test.dart` freeze at its second test).
/// Clearing the caches per test forces every read to create a fresh future in
/// the zone that will actually await it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    // Plain unit tests never initialize a binding, and only the widget binding
    // owns the image cache — skip the cleanup there.
    if (BindingBase.debugBindingType() == null) return;
    rootBundle.clear();
    PaintingBinding.instance.imageCache.clear();
  });
  await testMain();
}
