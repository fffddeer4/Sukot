import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/utils/url_utils.dart';

void main() {
  group('UrlUtils.cleanConfigLinks', () {
    const userConfig =
        'vless://eead0cdf-bb4c-44b4-a953-7007b0dd7dd0@cf-config-panel.sukot.workers.dev:443?path=%2F%3Fed%3D2048%26proxyip%3Dproxyip.nl.cmliussss.net&security=tls&alpn=http%2F1.1&encryption=none&insecure=0&host=cf-config-panel.sukot.workers.dev&fp=chrome&type=ws&allowInsecure=0&sni=cf-config-panel.sukot.workers.dev#SUKOT-MCI-Gdgdg-EX-proxyip-nl';

    test('passes the real SUKOT config through untouched', () {
      expect(UrlUtils.cleanConfigLinks(userConfig), userConfig);
      expect(UrlUtils.isConfigLink(userConfig), isTrue);
      expect(UrlUtils.containsConfigLink(userConfig), isTrue);
    });

    test('strips zero-width characters injected by keyboards', () {
      final corrupted = userConfig
          .replaceAll('eead0cdf', 'eead\u200C0cdf') // ZWNJ inside UUID
          .replaceAll('workers.dev', 'workers.\u200Fdev'); // RLM in host
      final cleaned = UrlUtils.cleanConfigLinks(corrupted);
      expect(cleaned, userConfig);
    });

    test('converts Persian and Arabic-Indic digits', () {
      // port 443 typed with Persian digits
      expect(
        UrlUtils.cleanConfigLinks(
            'vless://uuid@host:\u06F4\u06F4\u06F3?type=ws'),
        'vless://uuid@host:443?type=ws',
      );
      expect(
        UrlUtils.cleanConfigLinks('vless://uuid@host:\u0664\u0664\u0663?type=ws'),
        'vless://uuid@host:443?type=ws',
      );
    });

    test('drops quotes, bullets and shared-message decoration', () {
      expect(
        UrlUtils.cleanConfigLinks('"$userConfig"'),
        userConfig,
      );
      expect(
        UrlUtils.cleanConfigLinks('- $userConfig'),
        userConfig,
      );
      expect(
        UrlUtils.cleanConfigLinks('«$userConfig»'),
        userConfig,
      );
    });

    test('joins multiple links separated by newlines/spaces/commas', () {
      final two = 'vmess://AAAA vless://BBB\n${'ss://CCC، '}trojan://DDD';
      expect(
        UrlUtils.cleanConfigLinks(two),
        'vmess://AAAA,vless://BBB,ss://CCC,trojan://DDD',
      );
    });

    test('scheme detection', () {
      expect(UrlUtils.isConfigLink('vless://a@b:1?type=ws'), isTrue);
      expect(UrlUtils.isConfigLink('VLESS://a@b:1'), isTrue);
      expect(UrlUtils.isConfigLink('vmess://eyJ2IjoiMiJ9'), isTrue);
      expect(UrlUtils.isConfigLink('hy2://pass@host:443'), isTrue);
      expect(UrlUtils.isConfigLink('https://example.com/private-server'), isFalse);
      expect(UrlUtils.isConfigLink('not a link'), isFalse);
      expect(UrlUtils.isConfigLink('ftp://x'), isFalse);
    });

    test('private-server invite text keeps the URL intact', () {
      const invite =
          'join my server https://sukot.io/private-server?ip=1.2.3.4&port=443&token=JWT-TOKEN&exp=123';
      expect(
        UrlUtils.cleanConfigLinks(invite),
        'join,my,server,https://sukot.io/private-server?ip=1.2.3.4&port=443&token=JWT-TOKEN&exp=123',
      );
      // The invite URL itself survives cleaning so the join screen can pull
      // ip/port/token back out of it.
      expect(
        UrlUtils.cleanConfigLinks(invite).contains(
            'https://sukot.io/private-server?ip=1.2.3.4&port=443&token=JWT-TOKEN&exp=123'),
        isTrue,
      );
    });
  });
}
