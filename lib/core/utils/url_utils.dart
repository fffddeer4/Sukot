import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_webview.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlUtils {
  static const MethodChannel _methodChannel = MethodChannel(
    'org.getlantern.lantern/method',
  );
  static const Set<String> _webviewHandledSchemes = {
    'about',
    'blob',
    'chrome',
    'data',
    'file',
    'http',
    'https',
    'javascript',
  };
  // Keep this list intentionally narrow. These are the schemes we currently
  // need for payment app handoff from the in-app webview.
  static const Set<String> _externalAppSchemes = {
    'alipays',
    'intent',
    'market',
  };

  static String normalizeWebviewUrl(String url) => url.trim();

  static bool _isSupportedWebviewUri(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) {
      return false;
    }
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static bool isSupportedWebviewUrl(String url) {
    final uri = Uri.tryParse(normalizeWebviewUrl(url));
    if (uri == null) {
      return false;
    }
    return _isSupportedWebviewUri(uri);
  }

  static bool shouldOpenExternallyFromWebView(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isEmpty || _webviewHandledSchemes.contains(scheme)) {
      return false;
    }
    return _externalAppSchemes.contains(scheme);
  }

  static Future<bool> launchExternalAppUrl(Uri uri) async {
    if (PlatformUtils.isAndroid) {
      final launched = await _methodChannel.invokeMethod<bool>(
        'launchExternalUrl',
        uri.toString(),
      );
      return launched ?? false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> tryLaunchExternalAppUrl(
    BuildContext context,
    Uri uri,
  ) async {
    try {
      final ok = await launchExternalAppUrl(uri);
      if (!ok) throw 'Failed to open ${uri.toString()}';
      return true;
    } catch (e, st) {
      appLogger.error('Unable to launch external app URL', e, st);
      if (context.mounted) {
        context.showSnackBar('could_not_open_url'.i18n);
      }
      return false;
    }
  }

  static Future<void> openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      appLogger.error('Could not launch $url');
    }
  }

  // openWithSystemBrowser opens a URL in the browser
  static Future<void> openWithSystemBrowser(String url) async {
    switch (Platform.operatingSystem) {
      case 'linux':
        final webview = await WebviewWindow.create();
        webview.launch(url);
        break;
      default:
        await InAppBrowser.openWithSystemBrowser(url: WebUri(url));
    }
  }

  static Future<void> tryLaunchExternalUrl(
    BuildContext context,
    Uri uri,
  ) async {
    try {
      if (!await canLaunchUrl(uri)) {
        throw 'Cannot open ${uri.toString()}';
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw 'Failed to open ${uri.toString()}';
    } catch (e, st) {
      appLogger.error('Unable to launch url', e, st);
      if (context.mounted) {
        context.showSnackBar('could_not_open_url'.i18n);
      }
    }
  }

  static Future<T?> openWebview<T>(
    String url, {
    String? title,
    Function(T)? onWebviewResult,
    AppWebViewObserver? observer,
  }) async {
    try {
      final normalizedUrl = normalizeWebviewUrl(url);
      if (!isSupportedWebviewUrl(normalizedUrl)) {
        appLogger.error("Invalid webview URL: $url");
        return null;
      }

      switch (Platform.operatingSystem) {
        case 'android':
        case 'ios':
        case 'macos':
        case 'windows':
          final result = await appRouter.push<T>(
            AppWebview(
              title: title ?? '',
              url: normalizedUrl,
              observer: observer,
            ),
          );
          if (result != null) {
            onWebviewResult?.call(result);
          }
          return result;

        case 'linux':
          final webview = await WebviewWindow.create();
          webview.launch(normalizedUrl);
          return null;

        default:
          throw UnsupportedError(
            'Platform ${Platform.operatingSystem} is not supported',
          );
      }
    } catch (e, st) {
      appLogger.error("Failed to open webview", e, st);
      return null;
    }
  }

  static bool isValidDomain(String input) {
    final domainPattern = r'^(?!-)[A-Za-z0-9-]{1,63}(?<!-)\.[A-Za-z]{2,6}$';
    return RegExp(domainPattern).hasMatch(input);
  }

  static bool isValidIPv4(String input) {
    final pattern = r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$';
    final segments = input.split('.');
    return RegExp(pattern).hasMatch(input) &&
        segments.every((s) => int.parse(s) <= 255);
  }

  static bool isValidDomainOrIP(String input) =>
      isValidDomain(input) || isValidIPv4(input);

  static String extractDomain(String input) {
    var formatted = input;
    if (!formatted.startsWith("http://") && !formatted.startsWith("https://")) {
      formatted = "https://$formatted";
    }

    final uri = Uri.parse(formatted);
    final parts = uri.host.split('.');
    return parts.length > 2
        ? "${parts[parts.length - 2]}.${parts.last}"
        : uri.host;
  }

  // ---------------------------------------------------------------------------
  // Proxy config links (V2Ray-style share links)
  // ---------------------------------------------------------------------------

  /// Share-link schemes the core can import as proxy servers (vless://,
  /// vmess://, ss://, trojan://, hysteria2://, tuic://, ...). http/https are
  /// deliberately absent: those are web pages, not proxy configs (the
  /// private-server invite link is handled separately by ip/port/token).
  static const Set<String> configLinkSchemes = {
    'vless',
    'vmess',
    'ss',
    'ssr',
    'trojan',
    'hysteria',
    'hysteria2',
    'hy2',
    'tuic',
    'juicity',
    'anytls',
    'snell',
    'naive',
    'ssh',
    'wireguard',
    'wg',
    'socks',
    'socks4',
    'socks5',
    'socks5h',
  };

  /// Invisible/format characters (zero-width space, ZWNJ/ZWJ, direction
  /// marks, BOM, word-joiner, soft hyphen) that mobile keyboards — Persian
  /// ones in particular — can inject while typing, silently corrupting a
  /// pasted or typed config link.
  static const List<String> _invisibleChars = [
    '\u200B',
    '\u200C',
    '\u200D',
    '\u200E',
    '\u200F',
    '\u2060',
    '\u2066',
    '\u2067',
    '\u2068',
    '\u2069',
    '\uFEFF',
    '\u00AD',
  ];

  /// Cleans typed or pasted config-link text before handing it to the core:
  /// strips invisible characters, converts Persian/Arabic-Indic digits to
  /// ASCII, removes clipboard decoration (quotes, list bullets), splits on
  /// whitespace/commas/newlines and drops empties. Returns a comma-separated
  /// list in the exact shape `AddServersByURL` expects.
  static String cleanConfigLinks(String raw) {
    var text = raw;
    for (final ch in _invisibleChars) {
      text = text.replaceAll(ch, '');
    }
    const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      text = text
          .replaceAll(persianDigits[i], '$i')
          .replaceAll(arabicDigits[i], '$i');
    }
    final quoteStrip = RegExp("^['\"“”«»]+|['\"“”«»]+\$");
    final links = text
        .split(RegExp(r'[\s,،]+'))
        .map((e) => e
            .trim()
            .replaceAll(RegExp(r'^[-•*·>»]+'), '')
            .replaceAll(quoteStrip, '')
            .trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    return links.join(',');
  }

  /// First line of [raw] that starts a known proxy scheme, or ''.
  static String firstConfigLink(String raw) {
    for (final link in cleanConfigLinks(raw).split(',')) {
      if (isConfigLink(link)) return link;
    }
    return '';
  }

  /// True when [link] starts with one of [configLinkSchemes].
  static bool isConfigLink(String link) {
    final match = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*)://').firstMatch(link);
    if (match == null) return false;
    return configLinkSchemes.contains(match.group(1)!.toLowerCase());
  }

  /// True when [raw] contains at least one known proxy config link.
  static bool containsConfigLink(String raw) =>
      firstConfigLink(raw).isNotEmpty;
}
