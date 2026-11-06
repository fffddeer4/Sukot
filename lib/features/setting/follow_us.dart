import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'FollowUs')
class FollowUs extends StatelessWidget {
  const FollowUs({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(title: 'follow_us'.i18n, body: _buildBody());
  }

  Widget _buildBody() {
    return Card(child: FollowUsListView());
  }
}

class FollowUsListView extends StatelessWidget {
  final ScrollController? scrollController;

  const FollowUsListView({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    // Sukot keeps a single official channel — the Sukot Telegram channel.
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        AppTile.link(
          label: 'telegram'.i18n,
          icon: AppImagePaths.telegram,
          url: AppUrls.telegramChannel,
        ),
      ],
    );
  }
}
