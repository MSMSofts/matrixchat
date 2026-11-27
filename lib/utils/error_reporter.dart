// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:fluffychat/widgets/fluffy_chat_app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:matrix/matrix.dart';

/// Keep diagnostics local and generic, without raw exception details.
class ErrorReporter {
  final BuildContext? context;
  final String? message;

  const ErrorReporter(this.context, [this.message]);

  static const Set<String> ingoredTypes = {
    'IOException',
    'ClientException',
    'SocketException',
    'TlsException',
    'HandshakeException',
  };

  static void onFlutterError(Object error, [StackTrace? stackTrace]) {
    debugPrint('MatrixChat: an application error occurred.');
  }

  Future<void> onErrorCallback(Object error, [StackTrace? stackTrace]) async {
    if (ingoredTypes.contains(error.runtimeType.toString())) return;
    Logs().e('MatrixChat: operation failed.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentContext =
          context ??
          FluffyChatApp.router.routerDelegate.navigatorKey.currentContext;
      if (currentContext == null || !currentContext.mounted) return;
      showAdaptiveDialog(
        context: currentContext,
        builder: (context) => AlertDialog.adaptive(
          title: Text(L10n.of(context).initAppError),
          content: Text(
            Localizations.localeOf(context).languageCode == 'fa'
                ? 'خطایی رخ داد. جزئیات حساس ثبت یا ارسال نشد.'
                : 'An error occurred. Sensitive diagnostics were not shared.',
          ),
          actions: [
            AdaptiveDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(L10n.of(context).close),
            ),
          ],
        ),
      );
    });
  }
}
