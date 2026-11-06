import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/widgets/app_text.dart';
import 'package:lantern/core/widgets/expansion_chevron.dart';
import 'package:lantern/core/widgets/ping_chip.dart';
import 'package:lantern/core/widgets/spinner.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/features/vpn/server_selection_callbacks.dart';
import 'package:lantern/features/vpn/single_city_server_view.dart';

@RoutePage(name: 'ServerSelection')
class ServerSelection extends StatefulHookConsumerWidget {
  const ServerSelection({super.key});

  @override
  ConsumerState<ServerSelection> createState() => _ServerSelectionState();
}

class _ServerSelectionState extends ConsumerState<ServerSelection> {
  TextTheme? _textTheme;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(availableServersProvider.notifier)
            .refreshAvailableServersAfterProbeSettle(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(serverLocationProvider);
    final availableServers = ref.watch(availableServersProvider);
    final isUserPro = ref.watch(isUserProProvider);

    _textTheme = TextTheme.of(context);

    final appBar = CustomAppBar(
      title: Text('server_selection'.i18n),
      actions: [
        IconButton(
          key: const Key('server_selection.more_options'),
          icon: const Icon(Icons.more_vert),
          onPressed: onOpenMoreOptions,
        ),
      ],
    );

    if (availableServers.isLoading) {
      return BaseScreen(
        key: const Key('server_selection.screen'),
        title: '',
        appBar: appBar,
        body: const Center(child: Spinner()),
      );
    }

    final err = availableServers.asError;
    if (err != null) {
      return BaseScreen(
        key: const Key('server_selection.screen'),
        title: '',
        appBar: appBar,
        body: Center(
          child: Text(err.error.toString(), textAlign: TextAlign.center),
        ),
      );
    }

    final selectedServer = selected;
    final isPrivateServerFound = availableServers.requireValue.hasUserServers;

    return BaseScreen(
      key: const Key('server_selection.screen'),
      title: '',
      appBar: appBar,
      body: isPrivateServerFound
          ? _buildBody(selectedServer, isUserPro)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSmartLocation(selectedServer),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'smart_routing_mode_description'.i18n,
                    style: _textTheme?.bodyMedium!.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: size24),
                Flexible(child: ServerLocationListView(userPro: isUserPro)),
              ],
            ),
    );
  }

  Widget _buildBody(ServerLocation selectedServer, bool isUserPro) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSmartLocation(selectedServer),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'smart_routing_mode_description'.i18n,
              style: _textTheme?.bodyMedium!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: size24),
          SizedBox(
            height: 35.h,
            child: TabBar(
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.symmetric(horizontal: size24),
              splashBorderRadius: BorderRadius.circular(40),
              labelColor: context.actionTabbarSelectedText,
              dividerHeight: 0,
              unselectedLabelColor: context.actionTabbarDisabledText,
              labelStyle: _textTheme!.titleSmall,
              indicator: BoxDecoration(
                color: context.actionTabbarBg,
                borderRadius: BorderRadius.circular(40),
                shape: BoxShape.rectangle,
                border: Border.all(color: AppColors.blue3, width: 1),
              ),
              tabs: [
                Tab(child: Text('lantern_servers'.i18n)),
                Tab(
                  key: const Key('server_selection.private_servers_tab'),
                  child: Text('private_servers'.i18n),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const DividerSpace(padding: EdgeInsets.zero),
          const SizedBox(height: defaultSize),
          Expanded(
            child: TabBarView(
              children: [
                ServerLocationListView(userPro: isUserPro),
                const PrivateServerLocationListView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartLocation(ServerLocation serverLocation) {
    final autoLocation = serverLocation.autoLocation;
    final displayName = autoLocation?.displayName ?? 'fastest_server'.i18n;
    final flag = autoLocation?.countryCode ?? '';
    final protocol = autoLocation?.protocol ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'smart_location'.i18n,
            style: _textTheme?.labelLarge!.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            icon: flag.isEmpty
                ? AppImagePaths.location
                : Flag(countryCode: flag),
            label: displayName.i18n,
            onPressed: onSmartLocation,
            subtitle: protocol.isEmpty
                ? null
                : Text(
                    protocol.capitalize,
                    style: _textTheme!.labelMedium!.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
            trailing: AppImage(
              path: AppImagePaths.blot,
              color: context.statusWarningBgDot,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> onSmartLocation() async {
    if (PlatformUtils.isMacOS) {
      final macosExtensionStatus = ref.read(macosExtensionProvider);
      if (!macosExtensionStatus.isReady) {
        appRouter.push(const MacOSExtensionDialog());
        return;
      }
    }

    final serverLocation = ref.read(serverLocationProvider);

    final type = serverLocation.serverType.toServerLocationType;
    if (type == ServerLocationType.auto) {
      appLogger.debug(
        'Already in smart location, no need to switch, Just pop the screen',
      );
      appRouter.popUntilRoot();
      return;
    }

    /// User clicking here mean user want to switch to auto server regardless of VPN state
    final result = await ref.read(vpnProvider.notifier).startVPN(force: true);

    result.fold(
      (failure) {
        if (failure is VpnConflictFailure) {
          if (!context.mounted) {
            return;
          }
          AppDialog.vpnConflictDialog(
            context: context,
            onConnectAnyway: () async {
              appRouter.maybePop();
              final retryResult = await ref
                  .read(vpnProvider.notifier)
                  .startVPN(skipConflictCheck: true, force: true);
              if (!context.mounted) return;
              retryResult.fold((failure) {
                context.showSnackBar(failure.localizedErrorMessage);
                appLogger.error("Error changing VPN state: ${failure.error}");
              }, (_) => appRouter.popUntilRoot());
            },
          );
        } else {
          context.showSnackBar(failure.localizedErrorMessage);
        }
      },
      (_) async {
        await ref.read(serverLocationProvider.notifier).switchToAuto();
        appRouter.popUntilRoot();
      },
    );
  }

  void onOpenMoreOptions() {
    showAppBottomSheet(
      context: context,
      title: 'private_server_options'.i18n,
      scrollControlDisabledMaxHeightRatio: .4,
      builder: (context, scrollController) {
        return ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            AppTile(
              tileKey: const Key('server_selection.setup_private_server'),
              label: 'setup_private_server'.i18n,
              onPressed: () {
                context.pushRoute(PrivateServerSetup());
              },
            ),
            const DividerSpace(padding: EdgeInsets.zero),
            AppTile(
              tileKey: const Key('server_selection.join_private_server'),
              label: 'join_a_private_server'.i18n,
              onPressed: () {
                context.pushRoute(JoinPrivateServer());
              },
            ),
            const DividerSpace(padding: EdgeInsets.zero),
            AppTile(
              tileKey: const Key('server_selection.manage_private_servers'),
              label: 'manage_private_servers'.i18n,
              onPressed: () {
                context.pushRoute(ManagePrivateServer());
              },
            ),
          ],
        );
      },
    );
  }
}

class ServerLocationListView extends StatefulHookConsumerWidget {
  final bool userPro;

  const ServerLocationListView({super.key, required this.userPro});

  @override
  ConsumerState<ServerLocationListView> createState() =>
      _ServerLocationListViewState();
}

class _ServerLocationListViewState
    extends ConsumerState<ServerLocationListView>
    with ServerConnectFlow<ServerLocationListView> {
  @override
  Widget build(BuildContext context) {
    final availableServers = ref.watch(availableServersProvider);
    final selected = ref.watch(serverLocationProvider);

    const verticalSpacing = 12.0;

    final selectedTag = selected.serverName;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: availableServers.when(
              data: (data) {
                final allLocations = data.lanternServerLocations;
                if (allLocations.isEmpty) {
                  return const Center(child: Text("No locations available"));
                }

                final sections = [
                  _sectionHeader('pro_locations'.i18n),
                  _sectionCard(_locationTiles(allLocations, selectedTag)),
                ];

                // Server picking is free for everyone in Sukot — no gating
                // overlay is drawn over the list anymore.
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: sections,
                  ),
                );
              },
              loading: () => const Center(child: Spinner()),
              error: (error, _) => Center(
                child: Text(
                  error.localizedDescription,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: defaultSize),
      child: HeaderText(text),
    );
  }

  Widget _sectionCard(List<Widget> tiles) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _withDividers(tiles),
      ),
    );
  }

  List<Widget> _locationTiles(List<Server> locations, String selectedTag) {
    final grouped = _groupLocationsByCountry(locations);
    final countryEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return countryEntries.map((entry) {
      final country = entry.key;
      final countryLocations = entry.value;

      if (countryLocations.length == 1) {
        final serverData = countryLocations.first;
        return SingleCityServerView(
          key: ValueKey(serverData.tag),
          onServerSelected: onServerSelected,
          server: serverData,
          isSelected: selectedTag == serverData.tag,
        );
      }

      return _CountryCityListView(
        country: country,
        locations: countryLocations,
        selectedServerTag: selectedTag,
        onServerSelected: onServerSelected,
      );
    }).toList();
  }

  List<Widget> _withDividers(List<Widget> tiles) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      children.add(tiles[i]);
      if (i < tiles.length - 1) {
        children.add(const DividerSpace());
      }
    }
    return children;
  }

}

/// Shared "pick a server and connect" flow used by the full ServerSelection
/// screen and by the inline server list embedded on the home screen
/// ([ServerLocationsInlineList]). Keeping it in one place guarantees both
/// entry points behave identically: macOS extension gate, connect call,
/// VPN-conflict dialog, location bookkeeping.
mixin ServerConnectFlow<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Future<void> onServerSelected(Server selectedServer) async {
    if (PlatformUtils.isMacOS) {
      /// Check for if extension permission is granted before connecting to server, if not show the permission dialog first
      final macosExtensionStatus = ref.read(macosExtensionProvider);
      if (!macosExtensionStatus.isReady) {
        appRouter.push(const MacOSExtensionDialog());
        return;
      }
    }

    await _connectToServer(selectedServer);
  }

  Future<void> _connectToServer(Server selectedServer) async {
    final result = await ref
        .read(vpnProvider.notifier)
        .connectToServer(
          ServerLocationType.lanternLocation,
          selectedServer.tag,
        );

    result.fold(
      (failure) {
        if (failure is VpnConflictFailure) {
          AppDialog.vpnConflictDialog(
            context: context,
            onConnectAnyway: () async {
              appRouter.maybePop();
              final retryResult = await ref
                  .read(vpnProvider.notifier)
                  .connectToServer(
                    ServerLocationType.lanternLocation,
                    selectedServer.tag,
                    skipConflictCheck: true,
                  );
              retryResult.fold(
                (failure) =>
                    context.showSnackBar(failure.localizedErrorMessage),
                (_) {
                  ref
                      .read(serverLocationProvider.notifier)
                      .updateServerLocation(
                        ServerLocation.fromServer(server: selectedServer),
                      );
                  appRouter.popUntilRoot();
                },
              );
            },
          );
        } else {
          context.showSnackBar(failure.localizedErrorMessage);
        }
      },
      (_) async {
        final vpnStatus = ref.read(vpnProvider);

        void syncAndPop() {
          ref
              .read(serverLocationProvider.notifier)
              .updateServerLocation(
                ServerLocation.fromServer(server: selectedServer),
              );
          appRouter.popUntilRoot();
        }

        if (vpnStatus == VPNStatus.connected) {
          syncAndPop();
          return;
        }

        ref.listenManual<AsyncValue<LanternStatus>>(vPNStatusProvider, (
          previous,
          next,
        ) {
          if (next is AsyncData<LanternStatus> &&
              next.value.status == VPNStatus.connected) {
            syncAndPop();
          }
        });
      },
    );
  }

  /// Connect flow for user-imported configs (the ➕ Add Config feature).
  /// Mirrors [onPrivateServerSelected] so a config added on the lobby
  /// connects exactly like one added anywhere else: loading gate, conflict
  /// dialog, success snackbar, location bookkeeping, back to root.
  Future<void> onUserServerSelected(Server server) async {
    context.showLoadingDialog();

    final result = await ref
        .read(vpnProvider.notifier)
        .connectToServer(ServerLocationType.privateServer, server.tag);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        if (failure is VpnConflictFailure) {
          AppDialog.vpnConflictDialog(
            context: context,
            onConnectAnyway: () async {
              appRouter.maybePop();
              final retryResult = await ref
                  .read(vpnProvider.notifier)
                  .connectToServer(
                    ServerLocationType.privateServer,
                    server.tag,
                    skipConflictCheck: true,
                  );
              retryResult.fold(
                (f) {
                  context.hideLoadingDialog();
                  context.showSnackBar(f.localizedErrorMessage);
                },
                (_) {
                  context.hideLoadingDialog();
                  _completeUserServerConnection(server);
                },
              );
            },
          );
        } else {
          context.showSnackBar(failure.localizedErrorMessage);
        }
      },
      (_) {
        context.hideLoadingDialog();
        _completeUserServerConnection(server);
      },
    );
  }

  void _completeUserServerConnection(Server server) {
    context.showSnackBar('connected_to_private_server'.i18n);
    ref
        .read(serverLocationProvider.notifier)
        .updateServerLocation(
          ServerLocation(
            serverType: ServerLocationType.privateServer.name,
            serverName: server.tag,
            country: server.location.country,
            city: server.location.city,
            countryCode: server.location.countryCode,
            protocol: server.type,
          ),
        );
    appRouter.popUntilRoot();
  }
}

class _CountryCityListView extends StatefulWidget {
  final String country;
  final List<Server> locations;
  final String selectedServerTag;
  final OnServerSelected onServerSelected;

  const _CountryCityListView({
    required this.country,
    required this.locations,
    required this.selectedServerTag,
    required this.onServerSelected,
  });

  @override
  State<_CountryCityListView> createState() => _CountryCityListViewState();
}

class _CountryCityListViewState extends State<_CountryCityListView> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final countryCode = widget.locations.first.location.countryCode;
    final country = widget.locations.first.location.country;

    if (PlatformUtils.isDesktop) {
      return Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          enableFeedback: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 0,
          ),
          leading: Flag(countryCode: countryCode),
          title: Text(
            country,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge!.copyWith(color: context.textPrimary),
          ),
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          trailing: ExpansionChevron(isExpanded: _isExpanded),
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          children: widget.locations.map((server) {
            return AppTile(
              dense: true,
              minHeight: 58,
              contentPadding: const EdgeInsets.only(left: 53, right: 14),
              label: server.location.city,
              subtitle: server.type.isEmpty
                  ? null
                  : Text(
                      server.type.capitalize,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
              tileTextStyle: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: context.textPrimary),
              trailing: pingChipFor(
                context: context,
                lastSuccessDelayMs: server.selectionHistory?.lastSuccessDelayMs,
                isProbedUnreachable: server.isProbedUnreachable,
                isAwaitingProbe: server.isAwaitingProbe,
              ),
              onPressed: () => _onLocationSelected(context, server),
            );
          }).toList(),
        ),
      );
    }

    return AppTile(
      icon: Flag(countryCode: countryCode),
      label: widget.country,
      // Fastest known ping among the country's cities, then the chevron.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _countryPingChip(context) ?? const SizedBox.shrink(),
          const SizedBox(width: 8),
          AppImage(
            path: AppImagePaths.arrowForward,
            height: 20.0,
            color: context.textPrimary,
          ),
        ],
      ),
      onPressed: () => _showCountryBottomSheet(context),
    );
  }

  /// Lowest successful probe delay across the country's locations.
  PingChip? _countryPingChip(BuildContext context) {
    int? best;
    var anyUnreachable = widget.locations.isNotEmpty;
    for (final server in widget.locations) {
      final delay = server.selectionHistory?.lastSuccessDelayMs ?? 0;
      if (delay > 0 && (best == null || delay < best)) {
        best = delay;
      }
      if (!server.isProbedUnreachable) {
        anyUnreachable = false;
      }
    }
    if (best != null) {
      return PingChip(delayMs: best);
    }
    return anyUnreachable ? PingChip(delayMs: null, unreachable: true) : null;
  }

  void _onLocationSelected(BuildContext context, Server server) {
    widget.onServerSelected(server);
  }

  void _showCountryBottomSheet(BuildContext context) {
    showAppBottomSheet(
      context: context,
      title: widget.country,
      scrollControlDisabledMaxHeightRatio: 0.45,
      builder: (bottomSheetContext, scrollController) {
        return Flexible(
          child: ListView.separated(
            controller: scrollController,
            padding: EdgeInsets.zero,
            itemCount: widget.locations.length,
            separatorBuilder: (_, _) =>
                const DividerSpace(padding: EdgeInsets.zero),
            itemBuilder: (_, index) {
              final server = widget.locations[index];
              final isSelected = widget.selectedServerTag == server.tag;

              return SingleCityServerView(
                nested: true,
                onServerSelected: (selected) {
                  Navigator.of(bottomSheetContext).pop();
                  widget.onServerSelected(selected);
                },
                server: server,
                isSelected: isSelected,
              );
            },
          ),
        );
      },
    );
  }
}

class PrivateServerLocationListView extends StatefulHookConsumerWidget {
  const PrivateServerLocationListView({super.key});

  @override
  ConsumerState<PrivateServerLocationListView> createState() =>
      _PrivateServerLocationListViewState();
}

class _PrivateServerLocationListViewState
    extends ConsumerState<PrivateServerLocationListView> {
  TextTheme? _textTheme;

  @override
  Widget build(BuildContext context) {
    _textTheme = Theme.of(context).textTheme;

    final availableServers = ref.watch(availableServersProvider);
    final selected = ref.watch(serverLocationProvider);

    if (availableServers.isLoading) {
      return const Center(child: Spinner());
    }

    final err = availableServers.asError;
    if (err != null) {
      return Center(
        child: Text(err.error.toString(), textAlign: TextAlign.center),
      );
    }

    final userLocations = availableServers.requireValue.userServers;

    final selectedTag = selected.serverName;

    if (userLocations.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'no_private_server_setup_yet'.i18n,
            textAlign: TextAlign.center,
            style: _textTheme!.titleSmall!.copyWith(color: AppColors.gray8),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'setup_private_server'.i18n,
            onPressed: () => context.pushRoute(VPNSetting()),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: HeaderText('your_server'.i18n),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: EdgeInsets.zero,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: userLocations.length,
            separatorBuilder: (_, _) => const DividerSpace(),
            itemBuilder: (context, index) {
              final server = userLocations[index];
              final isSelected = selectedTag == server.tag;
              return AppTile(
                tileKey: Key('server_selection.private_server.${server.tag}'),
                onPressed: () {
                  if (isSelected) {
                    appLogger.debug('Already selected this server');
                    context.showSnackBar('server_already_selected'.i18n);
                    return;
                  }
                  onPrivateServerSelected(server);
                },
                icon: Flag(
                  countryCode: server.location.countryCode,
                  size: const Size(40, 28),
                ),
                label: server.tag,
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${server.location.city} - ${server.type}',
                        style: _textTheme!.labelMedium!.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: isSelected
                    ? AppImage(path: AppImagePaths.blot)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> onPrivateServerSelected(Server server) async {
    context.showLoadingDialog();

    final result = await ref
        .read(vpnProvider.notifier)
        .connectToServer(ServerLocationType.privateServer, server.tag);

    result.fold(
      (failure) {
        context.hideLoadingDialog();
        if (failure is VpnConflictFailure) {
          AppDialog.vpnConflictDialog(
            context: context,
            onConnectAnyway: () async {
              appRouter.maybePop();
              final retryResult = await ref
                  .read(vpnProvider.notifier)
                  .connectToServer(
                    ServerLocationType.privateServer,
                    server.tag,
                    skipConflictCheck: true,
                  );
              retryResult.fold(
                (failure) {
                  context.hideLoadingDialog();
                  context.showSnackBar(failure.localizedErrorMessage);
                },
                (_) {
                  context.hideLoadingDialog();
                  context.showSnackBar('connected_to_private_server'.i18n);
                  ref
                      .read(serverLocationProvider.notifier)
                      .updateServerLocation(
                        ServerLocation(
                          serverType: ServerLocationType.privateServer.name,
                          serverName: server.tag,
                          country: server.location.country,
                          city: server.location.city,
                          countryCode: server.location.countryCode,
                          protocol: server.type,
                        ),
                      );
                  appRouter.popUntilRoot();
                },
              );
            },
          );
        } else {
          context.showSnackBar(failure.localizedErrorMessage);
        }
      },
      (_) {
        context.hideLoadingDialog();
        context.showSnackBar('connected_to_private_server'.i18n);

        ref
            .read(serverLocationProvider.notifier)
            .updateServerLocation(
              ServerLocation(
                serverType: ServerLocationType.privateServer.name,
                serverName: server.tag,
                country: server.location.country,
                city: server.location.city,
                countryCode: server.location.countryCode,
                protocol: server.type,
              ),
            );
        appRouter.popUntilRoot();
      },
    );
  }
}

Map<String, List<Server>> _groupLocationsByCountry(List<Server> servers) {
  final Map<String, List<Server>> result = {};
  for (final server in servers) {
    result.putIfAbsent(server.location.country, () => <Server>[]).add(server);
  }
  return result;
}

/// Compact, non-scrollable rendering of every available Lantern server,
/// grouped by country exactly like [ServerLocationListView] — but laid out
/// in a plain [Column] so it can be embedded inside the home screen's own
/// scroll view. Country rows keep their flags, city rows keep their type
/// subtitles, every row keeps its real probe ping chip, and tapping a
/// server runs the exact same connect flow as the full ServerSelection
/// screen (shared via [ServerConnectFlow]).
class ServerLocationsInlineList extends ConsumerStatefulWidget {
  const ServerLocationsInlineList({super.key});

  @override
  ConsumerState<ServerLocationsInlineList> createState() =>
      _ServerLocationsInlineListState();
}

class _ServerLocationsInlineListState
    extends ConsumerState<ServerLocationsInlineList>
    with ServerConnectFlow<ServerLocationsInlineList> {
  @override
  Widget build(BuildContext context) {
    final availableServers = ref.watch(availableServersProvider);
    final selectedTag = ref.watch(serverLocationProvider).serverName;

    return availableServers.when(
      data: (data) {
        final allLocations = data.lanternServerLocations;
        final userServers = data.userServers;
        if (allLocations.isEmpty && userServers.isEmpty) {
          return const SizedBox.shrink();
        }

        final grouped = _groupLocationsByCountry(allLocations);
        final countryEntries = grouped.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        final tiles = countryEntries.map((entry) {
          final countryLocations = entry.value;

          if (countryLocations.length == 1) {
            final serverData = countryLocations.first;
            return SingleCityServerView(
              key: ValueKey(serverData.tag),
              onServerSelected: onServerSelected,
              server: serverData,
              isSelected: selectedTag == serverData.tag,
            );
          }

          return _CountryCityListView(
            country: entry.key,
            locations: countryLocations,
            selectedServerTag: selectedTag,
            onServerSelected: onServerSelected,
          );
        }).toList();

        final children = <Widget>[];
        // User-imported configs first — configs added through the ➕ button
        // are the user's own servers and deserve the top spot on the lobby.
        if (userServers.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: HeaderText('your_server'.i18n),
            ),
          );
          for (var i = 0; i < userServers.length; i++) {
            final server = userServers[i];
            children.add(_UserServerTile(
              key: ValueKey('user.${server.tag}'),
              server: server,
              isSelected: selectedTag == server.tag,
              onSelected: onUserServerSelected,
            ));
            children.add(const DividerSpace());
          }
        }
        if (tiles.isNotEmpty) {
          if (userServers.isNotEmpty) {
            children.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: HeaderText('lantern_servers'.i18n),
              ),
            );
          }
          for (var i = 0; i < tiles.length; i++) {
            children.add(tiles[i]);
            if (i < tiles.length - 1) {
              children.add(const DividerSpace());
            }
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Spinner()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Text(
          error.localizedDescription,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: context.textTertiary,
              ),
        ),
      ),
    );
  }
}

/// A single user-imported config row for the inline lobby list. Same visual
/// language as the private-server list: flag, tag as label, city/protocol
/// subtitle, and a checkmark when this config is the active connection.
class _UserServerTile extends StatelessWidget {
  final Server server;
  final bool isSelected;
  final ValueChanged<Server> onSelected;

  const _UserServerTile({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppTile(
      tileKey: Key('server_selection.user_server.${server.tag}'),
      onPressed: () => onSelected(server),
      selected: isSelected,
      icon: Flag(
        countryCode: server.location.countryCode,
        size: const Size(40, 28),
      ),
      label: server.tag,
      subtitle: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          // Imported configs have no geo-located city — show the server
          // host instead so the row isn't just a dangling protocol type.
          '${server.location.city.isEmpty ? server.serverIP : server.location.city} - ${server.type}',
          style: textTheme.labelMedium!.copyWith(
            color: context.textTertiary,
          ),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.blue6)
          : // Real probe latency for imported configs too — the core probes
            // every server once the tunnel is up, not just Lantern ones.
            pingChipFor(
              context: context,
              lastSuccessDelayMs:
                  server.selectionHistory?.lastSuccessDelayMs ?? 0,
              isProbedUnreachable: server.hasFailedProbeEvidence &&
                  !server.hasSuccessfulProbe,
              isAwaitingProbe: false,
            ),
    );
  }
}
