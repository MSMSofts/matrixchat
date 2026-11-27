// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/security/security_policy.dart';
import 'package:fluffychat/security/security_presets.dart';
import 'package:fluffychat/utils/beautify_string_extension.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/app_lock.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/settings_switch_list_tile.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

import 'settings_security.dart';

class SettingsSecurityView extends StatelessWidget {
  final SettingsSecurityController controller;

  const SettingsSecurityView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = Matrix.of(context).client;
    final publicMasterKey =
        client.userDeviceKeys[client.userID]?.masterKey?.publicKey;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).security),
        automaticallyImplyLeading: !FluffyThemes.isColumnMode(context),
        centerTitle: FluffyThemes.isColumnMode(context),
      ),
      body: ListTileTheme(
        iconColor: theme.colorScheme.onSurface,
        child: MaxWidthBody(
          child: FutureBuilder(
            future: Matrix.of(
              context,
            ).client.getCapabilities().timeout(const Duration(seconds: 10)),
            builder: (context, snapshot) {
              final capabilities = snapshot.data;
              final error = snapshot.error;
              if (error == null && capabilities == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                );
              }
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.security),
                    title: Text(
                      Localizations.localeOf(context).languageCode == 'fa'
                          ? 'مرکز امنیت MatrixChat'
                          : 'MatrixChat Security Center',
                    ),
                    subtitle: Text(
                      Localizations.localeOf(context).languageCode == 'fa'
                          ? 'تنظیمات پیشنهادی را یکجا اعمال کنید.'
                          : 'Apply a bundle of security settings.',
                    ),
                  ),
                  for (final preset in SecurityPreset.values)
                    ListTile(
                      title: Text(switch (preset) {
                        SecurityPreset.compatible =>
                          Localizations.localeOf(context).languageCode == 'fa'
                              ? 'سازگار با Matrix'
                              : 'Matrix compatible',
                        SecurityPreset.encrypted =>
                          Localizations.localeOf(context).languageCode == 'fa'
                              ? 'فقط اتاق رمزنگاری‌شده'
                              : 'Encrypted rooms only',
                        SecurityPreset.verified =>
                          Localizations.localeOf(context).languageCode == 'fa'
                              ? 'هویت تأییدشده'
                              : 'Verified identities',
                      }),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => controller.applySecurityPreset(preset),
                    ),
                  Divider(color: theme.dividerColor),
                  ListTile(
                    title: Text(
                      L10n.of(context).privacy,
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: L10n.of(context).sendTypingNotifications,
                    subtitle: L10n.of(
                      context,
                    ).sendTypingNotificationsDescription,
                    setting: AppSettings.sendTypingNotifications,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: L10n.of(context).sendReadReceipts,
                    subtitle: L10n.of(context).sendReadReceiptsDescription,
                    setting: AppSettings.sendPublicReadReceipts,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: Localizations.localeOf(context).languageCode == 'fa'
                        ? 'اعلان خصوصی'
                        : 'Private notifications',
                    subtitle:
                        Localizations.localeOf(context).languageCode == 'fa'
                        ? 'محتوا و نام فرستنده در اعلان پیام نمایش داده نمی‌شود.'
                        : 'Hide message content and sender in message notifications.',
                    setting: AppSettings.privateNotifications,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: Localizations.localeOf(context).languageCode == 'fa'
                        ? 'ارسال فقط در اتاق رمزنگاری‌شده'
                        : 'Encrypted rooms only',
                    subtitle:
                        Localizations.localeOf(context).languageCode == 'fa'
                        ? 'ارسال پیام معمولی بدون رمزنگاری مسدود می‌شود.'
                        : 'Block plaintext message sends.',
                    setting: AppSettings.requireEncryptedRooms,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: Localizations.localeOf(context).languageCode == 'fa'
                        ? 'الزام تأیید هویت مخاطبان'
                        : 'Require verified identities',
                    subtitle:
                        Localizations.localeOf(context).languageCode == 'fa'
                        ? 'در مسیرهای ارسال بررسی‌شده، تأیید هویت لازم است.'
                        : 'Require verified identities in guarded send flows.',
                    setting: AppSettings.requireVerifiedIdentities,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: Localizations.localeOf(context).languageCode == 'fa'
                        ? 'ذخیره پیش‌نویس بدون رمزنگاری'
                        : 'Persist unencrypted drafts',
                    subtitle:
                        Localizations.localeOf(context).languageCode == 'fa'
                        ? 'در حالت خاموش، پیش‌نویس فقط در ویرایشگر باقی می‌ماند.'
                        : 'When off, new drafts remain in the editor only.',
                    setting: AppSettings.persistPlaintextDrafts,
                  ),
                  SettingsSwitchListTile.adaptive(
                    title: Localizations.localeOf(context).languageCode == 'fa'
                        ? 'کش دائمی رسانه'
                        : 'Persistent media cache',
                    subtitle:
                        Localizations.localeOf(context).languageCode == 'fa'
                        ? 'خاموش: فقط فایل‌های در انتظار ارسال نگهداری می‌شوند. برای اعمال کامل برنامه را دوباره اجرا کنید.'
                        : 'Off limits regular disk caching; pending uploads remain protected. Restart to apply.',
                    setting: AppSettings.persistMediaCache,
                  ),
                  ListTile(
                    trailing: const Icon(Icons.chevron_right_outlined),
                    title: Text(L10n.of(context).blockedUsers),
                    subtitle: Text(
                      L10n.of(context).thereAreCountUsersBlocked(
                        Matrix.of(context).client.ignoredUsers.length,
                      ),
                    ),
                    onTap: () =>
                        context.go('/rooms/settings/security/ignorelist'),
                  ),
                  if (PlatformInfos.supportsAppLock) ...[
                    Divider(color: theme.dividerColor),
                    ListTile(
                      title: Text(
                        L10n.of(context).appLock,
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(L10n.of(context).appLockDescription),
                    ),
                    SwitchListTile.adaptive(
                      value: AppLock.of(context).isActive,
                      title: Text(L10n.of(context).useAppLock),
                      onChanged: (active) => active
                          ? controller.setAppLockAction()
                          : controller.disableAppLockAction(),
                    ),
                    if (AppLock.of(context).isActive) ...[
                      FutureBuilder(
                        future: LocalAuthentication().canCheckBiometrics,
                        builder: (context, snapshot) {
                          if (snapshot.data != true) return SizedBox.shrink();
                          return SwitchListTile.adaptive(
                            value: AppLock.of(context).useBiometrics,
                            onChanged: (_) => controller.toggleBiometrics(),
                            title: Text(L10n.of(context).unlockWithBiometrics),
                          );
                        },
                      ),
                      ListTile(
                        trailing: const Icon(Icons.lock_reset_outlined),
                        title: Text(L10n.of(context).resetPin),
                        onTap: controller.setAppLockAction,
                      ),
                    ],
                  ],

                  Divider(color: theme.dividerColor),
                  ListTile(
                    title: Text(
                      L10n.of(context).shareKeysWith,
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(L10n.of(context).shareKeysWithDescription),
                  ),
                  ListTile(
                    title: Material(
                      borderRadius: BorderRadius.circular(
                        AppConfig.borderRadius / 2,
                      ),
                      color: theme.colorScheme.onInverseSurface,
                      child: DropdownButton<ShareKeysWith>(
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadius / 2,
                        ),
                        underline: const SizedBox.shrink(),
                        value: Matrix.of(context).client.shareKeysWith,
                        items: SecurityPolicy.allowedKeySharing
                            .map(
                              (share) => DropdownMenuItem(
                                value: share,
                                child: Text(share.localized(L10n.of(context))),
                              ),
                            )
                            .toList(),
                        onChanged: controller.changeShareKeysWith,
                      ),
                    ),
                  ),
                  Divider(color: theme.dividerColor),
                  ListTile(
                    title: Text(
                      L10n.of(context).account,
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (publicMasterKey != null)
                    ListTile(
                      title: Text(L10n.of(context).yourPublicKey),
                      leading: const Icon(Icons.verified_user_outlined),
                      subtitle: SelectableText(
                        publicMasterKey.beautified,
                        style: const TextStyle(fontFamily: 'RobotoMono'),
                      ),
                    ),
                  ListTile(
                    title: Text(L10n.of(context).deviceIdentityKey),
                    leading: const Icon(Icons.mobile_friendly_outlined),
                    subtitle: SelectableText(
                      Matrix.of(context).client.fingerprintKey.beautified,
                      style: const TextStyle(fontFamily: 'RobotoMono'),
                    ),
                  ),
                  if (capabilities?.mChangePassword?.enabled != false ||
                      error != null)
                    ListTile(
                      leading: const Icon(Icons.password_outlined),
                      trailing: const Icon(Icons.chevron_right_outlined),
                      title: Text(L10n.of(context).changePassword),
                      onTap: () =>
                          context.go('/rooms/settings/security/password'),
                    ),
                  Divider(color: theme.dividerColor),
                  ListTile(
                    iconColor: Colors.orange,
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: Text(
                      L10n.of(context).dehydrate,
                      style: const TextStyle(color: Colors.orange),
                    ),
                    onTap: controller.dehydrateAction,
                  ),
                  ListTile(
                    iconColor: Colors.red,
                    leading: const Icon(Icons.delete_outlined),
                    title: Text(
                      L10n.of(context).deleteAccount,
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: controller.deleteAccountAction,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

extension on ShareKeysWith {
  String localized(L10n l10n) {
    switch (this) {
      case ShareKeysWith.all:
        return l10n.allDevices;
      case ShareKeysWith.crossVerifiedIfEnabled:
        return l10n.crossVerifiedDevicesIfEnabled;
      case ShareKeysWith.crossVerified:
        return l10n.crossVerifiedDevices;
      case ShareKeysWith.verifiedOnly:
      // ignore: deprecated_member_use
      case ShareKeysWith.directlyVerifiedOnly:
        return l10n.verifiedDevicesOnly;
    }
  }
}
