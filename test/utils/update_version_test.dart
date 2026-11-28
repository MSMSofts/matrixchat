// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/utils/show_update_snackbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only strictly newer stable releases are accepted', () {
    expect(UpdateNotifier.isNewerStableVersion('2.11.7', '2.11.6'), isTrue);
    expect(UpdateNotifier.isNewerStableVersion('2.12.0', '2.11.9'), isTrue);
    expect(UpdateNotifier.isNewerStableVersion('3.0.0', '2.99.99'), isTrue);
    expect(UpdateNotifier.isNewerStableVersion('2.11.6', '2.11.6'), isFalse);
    expect(UpdateNotifier.isNewerStableVersion('2.11.5', '2.11.6'), isFalse);
    expect(UpdateNotifier.isNewerStableVersion('2.9.9', '2.11.6'), isFalse);
    expect(
      UpdateNotifier.isNewerStableVersion('2.11.7-rc.1', '2.11.6'),
      isFalse,
    );
    expect(UpdateNotifier.isNewerStableVersion('2.11.7', 'Unknown'), isFalse);
  });
}
