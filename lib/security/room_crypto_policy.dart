// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:matrix/matrix.dart';

abstract final class RoomCryptoPolicy {
  /// Only use algorithms supported by the locked Matrix SDK. Negotiating a
  /// new protocol requires an interoperable standard and reviewed SDK support.
  static bool canEncrypt({
    required String? algorithm,
    required bool encryptionEnabled,
  }) => encryptionEnabled && algorithm == AlgorithmTypes.megolmV1AesSha2;

  static bool canEncryptRoom(Room room) => canEncrypt(
    algorithm: room.encryptionAlgorithm,
    encryptionEnabled: room.client.encryptionEnabled,
  );

  static Map<String, Object> encryptionContent({required bool strict}) => {
    'algorithm': AlgorithmTypes.megolmV1AesSha2,
    'rotation_period_ms': strict ? 3600000 : 86400000,
    'rotation_period_msgs': strict ? 20 : 100,
  };
}
