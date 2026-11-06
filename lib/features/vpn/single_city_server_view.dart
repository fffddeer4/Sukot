import 'package:flutter/material.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/widgets/ping_chip.dart';
import 'package:lantern/features/vpn/server_selection_callbacks.dart';

import '../../core/common/common.dart';

// single_city_server_view.dart

class SingleCityServerView extends StatefulWidget {
  final Server server;
  final OnServerSelected onServerSelected;
  final bool isSelected;
  final bool nested;

  const SingleCityServerView({
    super.key,
    required this.onServerSelected,
    required this.server,
    this.isSelected = false,
    this.nested = false,
  });

  @override
  State<SingleCityServerView> createState() => _SingleCityServerViewState();
}

class _SingleCityServerViewState extends State<SingleCityServerView> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final server = widget.server;
    return AppTile(
      label: widget.nested
          ? server.location.city
          : '${server.location.country} - ${server.location.city}',
      selected: widget.isSelected,
      subtitle: server.type.isEmpty
          ? null
          : Text(
              server.type.capitalize,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium!.copyWith(
                color: context.textTertiary,
              ),
            ),
      icon: Flag(countryCode: server.location.countryCode),
      // Real probe latency for this server, straight from the core.
      trailing: pingChipFor(
        context: context,
        lastSuccessDelayMs: server.selectionHistory?.lastSuccessDelayMs,
        isProbedUnreachable: server.isProbedUnreachable,
        isAwaitingProbe: server.isAwaitingProbe,
      ),
      onPressed: () {
        widget.onServerSelected(server);
      },
    );
  }
}
