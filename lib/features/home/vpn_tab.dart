import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/ping_chip.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
// Prefixed: router.gr already exposes a `ServerSelection` route class, and an
// unprefixed import of this file once made that name ambiguous.
import 'package:lantern/features/vpn/server_selection.dart'
    as server_selection;
import 'package:lantern/features/vpn/vpn_status.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

import '../../core/common/common.dart';

/// VPN tab body — the Sukot home screen. Hero section with a big glowing
/// power button and live status (plus a connection timer while the tunnel
/// is up), then the current server card, the full server/country list with
/// real pings, and the settings card (data usage, VPN status, routing,
/// split tunneling). No Scaffold or AppBar — the shell provides that.
class VpnTab extends ConsumerWidget {
  const VpnTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverLocation = ref.watch(serverLocationProvider);
    final serverType = serverLocation.serverType.toServerLocationType;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: defaultSize),
        // Preserve the spaced layout when it fits while allowing the body to
        // grow and scroll when the window leaves less vertical room.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            primary: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: <Widget>[
                  SizedBox(height: 8.h),
                  const _HeroStatus(),
                  SizedBox(height: 16.h),
                  _ServerLocationCard(location: serverLocation),
                  SizedBox(height: 16.h),
                  const _ServersSection(),
                  SizedBox(height: 12.h),
                  if (serverType == ServerLocationType.privateServer)
                    InfoRow(text: 'private_server_usage_message'.i18n)
                  else if (!PlatformUtils.isIOS)
                    const DataUsage(),
                  const SizedBox(height: 8),
                  _SettingCard(),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big circular power button + status headline + connection timer. Tapping
/// it toggles the VPN through the exact same handler the old toggle switch
/// used. The wrapper keeps the `vpn.switch.<status>` key and the tap target
/// keeps `vpn.toggle` so tests and the smoke harness keep working.
class _HeroStatus extends HookConsumerWidget {
  const _HeroStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vpnStatus = ref.watch(vpnProvider);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final connecting =
        vpnStatus == VPNStatus.connecting ||
        vpnStatus == VPNStatus.disconnecting;
    final connected = vpnStatus == VPNStatus.connected;

    // Live session timer: ticks once per second while the tunnel is up,
    // resets when it drops. Purely cosmetic — no state is persisted.
    final elapsed = useState<Duration>(Duration.zero);
    useEffect(() {
      if (vpnStatus != VPNStatus.connected) {
        elapsed.value = Duration.zero;
        return null;
      }
      final start = DateTime.now();
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        elapsed.value = DateTime.now().difference(start);
      });
      return () => timer.cancel();
    }, [vpnStatus]);

    final ringColor = switch (vpnStatus) {
      VPNStatus.connected => context.statusSuccessBgDot,
      VPNStatus.connecting => AppColors.blue5,
      VPNStatus.disconnecting => context.textTertiary,
      VPNStatus.error => context.borderError,
      _ => isDark ? AppColors.blue8 : AppColors.blue3,
    };

    return Container(
      key: Key('vpn.switch.${vpnStatus.name}'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        children: [
          _PowerButton(
            status: vpnStatus,
            ringColor: ringColor,
            isDark: isDark,
            onTap: () {
              appLogger.info('VPN power button tapped');
              handleVPNStateChange(ref, context);
            },
          ),
          SizedBox(height: 16.h),
          Text(
            // Same wording the status row uses everywhere else.
            vpnStatus.name.capitalize,
            style: textTheme.headlineSmall!.copyWith(
              color: connected ? context.statusSuccessText : context.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            connecting
                ? '...'
                : (connected ? 'disconnect'.i18n : 'connect'.i18n),
            style: textTheme.bodyMedium!.copyWith(
              color: context.textTertiary,
            ),
          ),
          if (connected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: context.statusSuccessBgDot.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.statusSuccessBgDot,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _formatElapsed(elapsed.value),
                    style: textTheme.labelMedium!.copyWith(
                      color: context.statusSuccessText,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

/// The big round power button: layered glow rings, brand-blue gradient
/// fill while connected, soft surface while off, spinning arc while
/// connecting, gentle breathing glow while the tunnel is up, and a slight
/// press-down scale for a premium feel.
class _PowerButton extends StatefulWidget {
  final VPNStatus status;
  final Color ringColor;
  final bool isDark;
  final VoidCallback onTap;

  const _PowerButton({
    required this.status,
    required this.ringColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<_PowerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _PowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    // Breathe only while the tunnel is up or being established.
    if (widget.status == VPNStatus.connected ||
        widget.status == VPNStatus.connecting ||
        widget.status == VPNStatus.disconnecting) {
      _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0.0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.status == VPNStatus.connected;
    final connecting =
        widget.status == VPNStatus.connecting ||
        widget.status == VPNStatus.disconnecting;
    final size = 150.0.r;

    return GestureDetector(
      key: const Key('vpn.toggle'),
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: _breath,
          builder: (context, child) {
            final breath = 0.5 - 0.5 * math.cos(2 * math.pi * _breath.value);
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: connected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.blue5, AppColors.blue10],
                      )
                    : null,
                color: connected
                    ? null
                    : (widget.isDark ? AppColors.gray850 : context.bgSurface),
                border: Border.all(
                  color: connected
                      ? Colors.transparent
                      : widget.ringColor.withValues(alpha: 0.55),
                  width: 2.5,
                ),
                boxShadow: [
                  // Outer ambient glow that breathes with the state.
                  BoxShadow(
                    color: (connected ? AppColors.blue6 : widget.ringColor)
                        .withValues(alpha: 0.18 + 0.22 * breath),
                    blurRadius: 30 + 20 * breath,
                    spreadRadius: 1 + 2 * breath,
                    offset: const Offset(0, 8),
                  ),
                  // Tight inner glow for depth.
                  BoxShadow(
                    color: (connected ? AppColors.blue10 : widget.ringColor)
                        .withValues(alpha: 0.10 + 0.10 * breath),
                    blurRadius: 12,
                    spreadRadius: -2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (connecting)
                    SizedBox(
                      width: size + 14.r,
                      height: size + 14.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5.r,
                        valueColor:
                            AlwaysStoppedAnimation(context.actionToggleKnobBg),
                      ),
                    ),
                  Icon(
                    Icons.power_settings_new,
                    size: 56.r,
                    color: connected
                        ? AppColors.white
                        : (widget.isDark ? AppColors.blue3 : AppColors.blue6),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Prominent server card on the home screen: flag, smart/selected location,
/// protocol and the live ping badge — tappable, opens server selection.
/// Keeps the `home.location_setting` key used by tests and the smoke harness.
class _ServerLocationCard extends ConsumerWidget {
  final ServerLocation location;

  const _ServerLocationCard({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final serverType = location.serverType.toServerLocationType;

    String title;
    String value;
    String flag;
    String protocol;

    switch (serverType) {
      case ServerLocationType.auto:
        title = 'smart_location'.i18n;
        final autoLoc = location.autoLocation;
        value = autoLoc != null && autoLoc.displayName.isNotEmpty
            ? autoLoc.displayName
            : 'fastest_server'.i18n;
        flag = autoLoc?.countryCode ?? '';
        protocol = autoLoc?.protocol ?? '';
        break;

      case ServerLocationType.lanternLocation:
        title = 'selected_location'.i18n;
        value = location.displayName;
        flag = location.countryCode;
        protocol = location.protocol;
        break;

      case ServerLocationType.privateServer:
        title = location.serverName;
        value = location.displayName;
        flag = location.countryCode;
        protocol = location.protocol;
        break;
    }

    final ping = _pingChip(context, ref);

    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 32,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: InkWell(
          key: const Key('home.location_setting'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => appRouter.push(const ServerSelection()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: flag.isEmpty
                      ? AppImage(path: AppImagePaths.location)
                      : Flag(countryCode: flag),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge!.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value.i18n,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium!.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (protocol.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          protocol.capitalize,
                          maxLines: 1,
                          style: textTheme.labelMedium!.copyWith(
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (ping != null) ...[
                  const SizedBox(width: 8),
                  ping,
                ],
                const SizedBox(width: 8),
                if (!isSmallScreen(context))
                  const AppImage(path: AppImagePaths.arrowForward),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Real ping for the currently selected server, straight from the probe
  /// history the core already maintains. Smart Location resolves through its
  /// auto tag; manual selection through the server name.
  PingChip? _pingChip(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(availableServersProvider).value;
    if (servers == null) return null;

    final Server? server;
    if (location.serverType.toServerLocationType == ServerLocationType.auto) {
      final tag = location.autoLocation?.tag;
      server = tag == null || tag.isEmpty ? null : servers.serverByTag(tag);
    } else {
      server = servers.serverByTag(location.serverName);
    }
    if (server == null) return null;

    return pingChipFor(
      context: context,
      lastSuccessDelayMs: server.selectionHistory?.lastSuccessDelayMs,
      isProbedUnreachable: server.isProbedUnreachable,
      isAwaitingProbe: server.isAwaitingProbe,
    );
  }
}

/// Full list of available servers grouped by country, embedded straight on
/// the home screen so every server, its country flag and its real ping are
/// visible at a glance — without having to open the ServerSelection screen.
/// Tapping a row connects through the exact same flow as that screen.
class _ServersSection extends ConsumerWidget {
  const _ServersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: HeaderText('server_locations'.i18n),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor,
                blurRadius: 32,
                offset: Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: server_selection.ServerLocationsInlineList(),
          ),
        ),
      ],
    );
  }
}

class _SettingCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routingMode = ref.watch(
      radianceSettingsProvider.select((s) => s.routingMode),
    );
    final isSplitTunnelingOn = ref.watch(
      radianceSettingsProvider.select((s) => s.splitTunneling),
    );
    final serverType = ref
        .watch(serverLocationProvider)
        .serverType
        .toServerLocationType;

    // Data usage is surfaced by the standalone card above now; inside the
    // settings card it only appears on small screens where space is tight.
    final smallScreen = isSmallScreen(context);
    final showDataUsage =
        smallScreen &&
        serverType != ServerLocationType.privateServer &&
        !PlatformUtils.isIOS;
    final showRoutingMode = !PlatformUtils.isIOS;
    final showSplitTunneling =
        PlatformUtils.isAndroid ||
        PlatformUtils.isMacOS ||
        PlatformUtils.isWindows;

    // Small screens drop the > chevrons; rows stay tappable via onTap.
    final chevronActions = smallScreen
        ? const <Widget>[]
        : const <Widget>[AppImage(path: AppImagePaths.arrowForward)];
    final routingTile = SettingTile(
      label: 'routing_mode'.i18n,
      icon: AppImagePaths.route,
      value: routingMode.label(),
      actions: chevronActions,
      onTap: () => appRouter.push(const SmartRouting()),
    );
    final splitTunnelingTile = SettingTile(
      // Tapped by the split-tunneling smoke harness.
      tileKey: const Key('home.split_tunneling_setting'),
      label: 'split_tunneling'.i18n,
      icon: AppImagePaths.callSpilt,
      value: isSplitTunnelingOn ? 'enabled'.i18n : 'disabled'.i18n,
      actions: chevronActions,
      onTap: () => appRouter.push(const SplitTunneling()),
    );

    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 32,
            offset: Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            // Brings its own trailing divider, shown only when visible.
            if (showDataUsage) const DataUsage(insideCard: true),
            const VpnStatus(),
            const DividerSpace(),
            if (showRoutingMode || showSplitTunneling) ...[
              // Small screens: Routing Mode | Split Tunneling share one row;
              // otherwise stacked full-width rows.
              if (showRoutingMode && showSplitTunneling && smallScreen)
                Row(
                  children: [
                    Expanded(child: routingTile),
                    SizedBox(
                      height: 40,
                      child: VerticalDivider(
                        width: 1,
                        color: Theme.of(context).dividerTheme.color,
                      ),
                    ),
                    Expanded(child: splitTunnelingTile),
                  ],
                )
              else ...[
                if (showRoutingMode) routingTile,
                if (showRoutingMode && showSplitTunneling) const DividerSpace(),
                if (showSplitTunneling) splitTunnelingTile,
              ],
            ],
          ],
        ),
      ),
    );
  }
}
