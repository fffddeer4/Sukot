import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/setting/follow_us.dart' hide FollowUs;
import 'package:lantern/features/support/app_version.dart';

@RoutePage(name: 'Support')
class Support extends ConsumerWidget {
  const Support({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BaseScreen(
      title: toBeginningOfSentenceCase('support'.i18n),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Center(
              child: AppImage(
                path: AppImagePaths.supportIllustration,
                useThemeColor: false,
                type: AssetType.svg,
                height: 180.h,
                width: 180.w,
              ),
            ),
            gap16,
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Community help now lives in the Sukot Telegram channel.
                  AppTile.link(
                    icon: Icons.forum_outlined,
                    label: 'lantern_user_forum'.i18n,
                    url: AppUrls.telegramChannel,
                    open: (u) =>
                        UrlUtils.tryLaunchExternalUrl(context, Uri.parse(u)),
                  ),
                  const DividerSpace(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  AppTile(
                    label: 'follow_us'.i18n,
                    icon: AppImagePaths.thumb,
                    onPressed: () {
                      if (PlatformUtils.isDesktop) {
                        appRouter.push(const FollowUs());
                        return;
                      }
                      showFollowUsBottomSheet(context: context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: defaultSize),
            const AppVersion(),
            const SizedBox(height: size24),
          ],
        ),
      ),
    );
  }

  void showFollowUsBottomSheet({required BuildContext context}) {
    showAppBottomSheet(
      context: context,
      title: 'follow_us'.i18n,
      scrollControlDisabledMaxHeightRatio: context.isSmallDevice
          ? 0.39.h
          : 0.3.h,
      builder: (context, scrollController) {
        return Flexible(
          child: FollowUsListView(scrollController: scrollController),
        );
      },
    );
  }
}
