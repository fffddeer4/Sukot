import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/private_server/provider/private_server_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';

/// Presents the "Add Config" sheet from the home screen's + button — the
/// V2Ray-style entry point for connecting custom configs to Sukot.
void showAddConfigSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const AddConfigSheet(),
  );
}

/// Bottom sheet for importing custom proxy configs. Accepts one or more
/// config links (vmess://, vless://, ss://, trojan://, hysteria2://, ...)
/// either pasted or scanned from a QR code. Submission goes through the
/// production core API `addServerBasedOnURLs` — the exact same call the
/// private-server flow uses — so every format the core supports works here.
/// Added servers land in the server list with the rest of the locations.
class AddConfigSheet extends StatefulHookConsumerWidget {
  const AddConfigSheet({super.key});

  @override
  ConsumerState<AddConfigSheet> createState() => _AddConfigSheetState();
}

class _AddConfigSheetState extends ConsumerState<AddConfigSheet> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final linksController = useTextEditingController();
    final hasLinks = useState(false);

    void updateValid(String value) {
      hasLinks.value = value.trim().isNotEmpty;
    }

    Future<void> paste() async {
      final value = await pasteFromClipboard();
      if (value.isEmpty) return;
      linksController.text = value;
      updateValid(value);
    }

    Future<void> scanQR() async {
      final value = await appRouter.push<String>(QrCodeScanner());
      if (value == null || value.isEmpty) return;
      linksController.text = value;
      updateValid(value);
    }

    Future<void> submit() async {
      // Normalize the input (strip invisible keyboard characters, Persian
      // digits, quotes/bullets, whitespace) into a comma-separated URL list.
      final urls = UrlUtils.cleanConfigLinks(linksController.text);
      if (urls.isEmpty) return;

      // Drop anything that is not a recognizable config link; only complain
      // when nothing usable remains.
      final validLinks = urls
          .split(',')
          .where((u) => u.isNotEmpty && UrlUtils.isConfigLink(u))
          .toList();
      if (validLinks.isEmpty) {
        AppDialog.errorDialog(
          context: context,
          title: 'error'.i18n,
          content: 'invalid_config_link'.i18n,
        );
        return;
      }

      context.showLoadingDialog();
      final result = await ref
          .read(privateServerProvider.notifier)
          .addServerBasedOnURLs(validLinks.join(','), true);
      result.fold(
        (error) {
          appLogger.error("Failed to add config: $error");
          context.hideLoadingDialog();
          AppDialog.errorDialog(
            context: context,
            title: 'error'.i18n,
            content: error.localizedErrorMessage,
          );
        },
        (tags) {
          appLogger.info("Config added, servers: $tags");
          unawaited(
            ref
                .read(availableServersProvider.notifier)
                .forceFetchAvailableServers(),
          );
          context.hideLoadingDialog();
          // Close the sheet itself (plain modal route, not auto_route).
          Navigator.of(context).pop();
          _showSuccessDialog();
        },
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          defaultSize,
          8,
          defaultSize,
          24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'add_config'.i18n,
              style: textTheme.headlineSmall!.copyWith(
                color: context.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'add_config_hint'.i18n,
              style: textTheme.bodySmall!.copyWith(
                color: context.textSecondary,
              ),
            ),
            SizedBox(height: 16),
            AppTextField(
              fieldKey: const Key('add_config.links'),
              label: 'config_links'.i18n,
              hintText: 'config_links_hint'.i18n,
              controller: linksController,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              enableSuggestions: false,
              autocorrect: false,
              enableIMEPersonalizedLearning: false,
              onChanged: updateValid,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (PlatformUtils.isMobile)
                    GestureDetector(
                      onTap: scanQR,
                      child: AppImage(path: AppImagePaths.qrCodeScanner),
                    ),
                  SizedBox(width: 12),
                  GestureDetector(
                    onTap: paste,
                    child: AppImage(path: AppImagePaths.copy),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            PrimaryButton(
              buttonKey: const Key('add_config.submit'),
              enabled: hasLinks.value,
              label: 'add_config_button'.i18n,
              onPressed: submit,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    final textTheme = Theme.of(context).textTheme;
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24),
          Center(child: AppImage(path: AppImagePaths.roundCorrect, height: 36)),
          SizedBox(height: 16),
          Text('config_added_title'.i18n, style: textTheme.titleLarge),
          SizedBox(height: 12),
          Text(
            'config_added_message'.i18n,
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'got_it'.i18n,
          textColor: AppColors.blue6,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
