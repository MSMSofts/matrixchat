// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/key_verification/key_verification_dialog.dart';
import 'package:fluffychat/security/identity_pin.dart';
import 'package:fluffychat/utils/beautify_string_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

Future<bool> showTrustUserInRoomDialog(BuildContext context, Room room) async {
  if (!room.encrypted) {
    if (!AppSettings.requireEncryptedRooms.value &&
        !AppSettings.requireVerifiedIdentities.value) {
      return true;
    }
    _securityBlocked(context, identity: false);
    return false;
  }

  final users = await room.requestParticipants();
  if (!context.mounted) return false;
  if (AppSettings.requireVerifiedIdentities.value) {
    final activeUsers = users.where(
      (user) =>
          user.membership == Membership.join ||
          user.membership == Membership.invite,
    );
    if (activeUsers.isEmpty) return false;
    for (final user in activeUsers) {
      if (user.id == room.client.userID) continue;
      final keys = room.client.userDeviceKeys[user.id];
      final master = keys?.masterKey;
      final publicKey = master?.publicKey;
      if (master?.verified != true || publicKey == null || keys == null) {
        _securityBlocked(context, identity: true);
        return false;
      }
      final devices = keys.deviceKeys.values.where((key) => !key.blocked);
      if (devices.isEmpty ||
          devices.any((key) => !key.isValid || !key.verified)) {
        _securityBlocked(context, identity: true);
        return false;
      }
      final account = '${room.client.clientName}:${room.client.userID}';
      final result = await IdentityPin.instance.check(
        account: account,
        userId: user.id,
        publicKey: publicKey,
        verified: true,
      );
      if (!context.mounted) return false;
      if (result == IdentityPinResult.changed) {
        final persian = Localizations.localeOf(context).languageCode == 'fa';
        final consent = await showOkCancelAlertDialog(
          context: context,
          title: persian ? 'تغییر کلید هویت' : 'Identity key changed',
          message: persian
              ? 'کلید ثبت‌شده مخاطب تغییر کرده است. فقط پس از تطبیق هویت از مسیر مستقل، دوباره تأیید کنید.'
              : 'The saved identity key changed. Verify the contact again through an independent channel before accepting it.',
        );
        if (!context.mounted || consent != OkCancelResult.ok) return false;
        final request = await keys.startVerification();
        if (!context.mounted) return false;
        final success = await KeyVerificationDialog(
          request: request,
        ).show(context);
        if (!context.mounted || success != true) return false;
        final updated = room.client.userDeviceKeys[user.id]?.masterKey;
        if (updated?.publicKey != publicKey || updated?.verified != true) {
          return false;
        }
        // Never send in the same attempt as a trust change.
        await IdentityPin.instance.replaceAfterVerification(
          account: account,
          userId: user.id,
          publicKey: publicKey,
          verified: true,
        );
        return false;
      }
      if (result == IdentityPinResult.unavailable) {
        _securityBlocked(context, identity: true);
        return false;
      }
    }
    return true;
  }

  users.removeWhere((user) {
    if (user.id == room.client.userID) return true;
    final keys = room.client.userDeviceKeys[user.id];
    final masterKey = keys?.masterKey;

    if (keys == null ||
        masterKey == null ||
        masterKey.verified ||
        masterKey.trustOnFirstUseSince != null) {
      return true;
    }
    return false;
  });

  if (users.isEmpty) return true;

  final l10n = L10n.of(context);
  final theme = Theme.of(context);

  final action = await showAdaptiveDialog<_Action>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Center(
        child: Icon(
          Icons.lock_outlined,
          size: 32,
          color: theme.colorScheme.primary,
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 128),
        child: SelectionArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: .stretch,
              mainAxisSize: .min,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    users.length == 1
                        ? l10n.messageCanOnlyBeReadByUser
                        : l10n.messageCanOnlyBeReadByUsers,
                    style: TextStyle(fontSize: 16),
                    textAlign: .center,
                  ),
                ),
                const SizedBox(height: 16),
                for (final user in users) ...[
                  Row(
                    children: [
                      Avatar(
                        name: user.calcDisplayname(),
                        mxContent: user.avatarUrl,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          user.calcDisplayname(),
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          textAlign: TextAlign.start,
                        ),
                      ),
                    ],
                  ),
                  Builder(
                    builder: (context) {
                      final controller = TextEditingController(
                        text: l10n.publicKey(
                          room
                                  .client
                                  .userDeviceKeys[user.id]
                                  ?.masterKey
                                  ?.publicKey
                                  ?.beautifiedOneLine ??
                              '???',
                        ),
                      );
                      return DialogTextField(
                        controller: controller,
                        textStyle: theme.textTheme.labelSmall,
                        readOnly: true,
                        maxLines: 3,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        AdaptiveDialogAction(
          autofocus: true,
          bigButtons: true,
          onPressed: () {
            for (final user in users) {
              room.client.userDeviceKeys[user.id]?.masterKey?.trustOnFirstUse();
            }
            Navigator.of(context).pop(_Action.allow);
          },
          child: Text(L10n.of(context).continueText),
        ),
        if (room.isDirectChat)
          AdaptiveDialogAction(
            bigButtons: true,
            onPressed: () => Navigator.of(context).pop(_Action.verification),
            child: Text(L10n.of(context).interactiveVerification),
          ),
        AdaptiveDialogAction(
          bigButtons: true,
          onPressed: () => Navigator.of(context).pop(_Action.deny),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );

  if (action == null) return false;

  switch (action) {
    case _Action.allow:
      for (final user in users) {
        room.client.userDeviceKeys[user.id]?.masterKey?.trustOnFirstUse();
      }
    case _Action.deny:
      return false;
    case _Action.verification:
      final req = await room.client.userDeviceKeys[room.directChatMatrixID]
          ?.startVerification();
      if (req == null) return false;
      if (!context.mounted) return false;
      final success = await KeyVerificationDialog(request: req).show(context);
      return success == true;
  }

  return true;
}

void _securityBlocked(BuildContext context, {required bool identity}) {
  if (!context.mounted) return;
  final persian = Localizations.localeOf(context).languageCode == 'fa';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        identity
            ? (persian
                  ? 'ابتدا هویت مخاطبان را تأیید کنید.'
                  : 'Verify the participants before sending.')
            : (persian
                  ? 'ارسال در اتاق بدون رمزنگاری مجاز نیست.'
                  : 'Sending to an unencrypted room is blocked.'),
      ),
    ),
  );
}

enum _Action { allow, deny, verification }
