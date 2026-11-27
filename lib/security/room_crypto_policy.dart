// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

abstract final class RoomCryptoPolicy {
  static Map<String, Object> encryptionContent({required bool strict}) => {
    'algorithm': AlgorithmTypes.megolmV1AesSha2,
    'rotation_period_ms': strict ? 3600000 : 86400000,
    'rotation_period_msgs': strict ? 20 : 100,
  };
}
