// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/security/media_vault.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Reports local runtime configuration, not an independent security audit.
class SecurityStatusPanel extends StatefulWidget {
  final Client client;

  const SecurityStatusPanel({super.key, required this.client});

  @override
  State<SecurityStatusPanel> createState() => _SecurityStatusPanelState();
}

class _SecurityStatusPanelState extends State<SecurityStatusPanel> {
  static const _channel = MethodChannel('matrixchat/security');
  String? _capability;
  bool _checking = false;

  Future<void> _probe() async {
    if (_checking) return;
    setState(() => _checking = true);
    String? result;
    try {
      result = await _channel.invokeMethod<String>('probeKeystore');
    } catch (_) {
      result = 'unavailable';
    }
    if (!mounted) return;
    setState(() {
      _capability = result ?? 'unknown';
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fa = Localizations.localeOf(context).languageCode == 'fa';
    final nativeVault = widget.client.database is VaultMatrixDatabase;
    final verifiedOnly =
        widget.client.shareKeysWith == ShareKeysWith.verifiedOnly;
    String status(bool active) =>
        active ? (fa ? 'فعال' : 'On') : (fa ? 'غیرفعال' : 'Off');
    final hardware = switch (_capability) {
      'strongbox' => 'StrongBox',
      'tee' => 'Trusted Execution Environment',
      'hardware' => fa ? 'سخت‌افزار امن' : 'Secure hardware',
      'software' => fa ? 'نرم‌افزاری' : 'Software',
      'unavailable' ||
      'unsupported' ||
      'unknown' => fa ? 'قابل تأیید نیست' : 'Not confirmed',
      _ => fa ? 'آزمون نشده' : 'Not tested',
    };

    return Column(
      children: [
        ListTile(
          title: Text(fa ? 'وضعیت واقعی تنظیمات' : 'Local security status'),
          subtitle: Text(
            fa
                ? 'این بررسی وضعیت فعلی برنامه است، نه گواهی امنیت.'
                : 'Configuration status, not a security certification.',
          ),
        ),
        ListTile(
          title: Text(fa ? 'ذخیره‌سازی محلی' : 'Local storage'),
          subtitle: Text(
            nativeVault
                ? 'SQLCipher account vault'
                : (fa
                      ? 'حفاظت معادل تأیید نشده'
                      : 'Equivalent protection unconfirmed'),
          ),
        ),
        ListTile(
          title: Text(
            fa
                ? 'اشتراک کلید فقط با دستگاه تأییدشده'
                : 'Verified-only key sharing',
          ),
          trailing: Text(status(verifiedOnly)),
        ),
        ListTile(
          title: Text(
            fa ? 'ارسال رمزنگاری‌شده اجباری' : 'Encrypted sends required',
          ),
          trailing: Text(
            status(
              AppSettings.requireEncryptedRooms.value ||
                  AppSettings.requireVerifiedIdentities.value,
            ),
          ),
        ),
        ListTile(
          title: Text(fa ? 'کنترل هویت مخاطب' : 'Identity checks'),
          trailing: Text(status(AppSettings.requireVerifiedIdentities.value)),
        ),
        if (PlatformInfos.isAndroid)
          ListTile(
            title: Text(
              fa
                  ? 'آزمون قابلیت سخت‌افزاری Keystore'
                  : 'Test Android Keystore capability',
            ),
            subtitle: Text(
              fa
                  ? '$hardware — کلید آزمایشی مستقل؛ نه کلید دیتابیس'
                  : '$hardware — temporary probe, not the database key',
            ),
            trailing: _checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onTap: _checking ? null : _probe,
          ),
      ],
    );
  }
}
