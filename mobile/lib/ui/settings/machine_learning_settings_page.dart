import "dart:async";

import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/service_locator.dart";
import "package:photos/services/machine_learning/machine_learning_controller.dart";
import "package:photos/services/machine_learning/ml_service.dart";
import 'package:photos/services/machine_learning/semantic_search/semantic_search_service.dart';
import "package:photos/services/remote_assets_service.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/common/loading_widget.dart";
import "package:photos/ui/components/buttons/icon_button_widget.dart";
import "package:photos/ui/components/captioned_text_widget.dart";
import "package:photos/ui/components/menu_item_widget/menu_item_widget.dart";
import "package:photos/ui/components/menu_section_description_widget.dart";
import "package:photos/ui/components/menu_section_title.dart";
import "package:photos/ui/components/title_bar_title_widget.dart";
import "package:photos/ui/components/title_bar_widget.dart";
import "package:photos/ui/components/toggle_switch_widget.dart";
import "package:photos/utils/data_util.dart";
import "package:photos/utils/ml_util.dart";
import "package:photos/utils/wakelock_util.dart";

class MachineLearningSettingsPage extends StatefulWidget {
  const MachineLearningSettingsPage({super.key});

  @override
  State<MachineLearningSettingsPage> createState() =>
      _MachineLearningSettingsPageState();
}

class _MachineLearningSettingsPageState
    extends State<MachineLearningSettingsPage> {
  final EnteWakeLock _wakeLock = EnteWakeLock();

  @override
  void initState() {
    super.initState();
    _wakeLock.enable();
    MachineLearningController.instance.forceOverrideML(turnOn: true);
  }

  @override
  void dispose() {
    super.dispose();
    _wakeLock.disable();
    MachineLearningController.instance.forceOverrideML(turnOn: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        primary: false,
        slivers: <Widget>[
          TitleBarWidget(
            flexibleSpaceTitle: TitleBarTitleWidget(
              title: S.of(context).machineLearning,
            ),
            actionIcons: [
              IconButtonWidget(
                icon: Icons.close_outlined,
                iconButtonType: IconButtonType.secondary,
                onTap: () {
                  Navigator.pop(context);
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
              ),
            ],
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (delegateBuildContext, index) => Padding(
                padding: const EdgeInsets.only(left: 16, right: 16),
                child: Text(
                  S.of(context).mlIndexingDescription,
                  textAlign: TextAlign.left,
                  style: getEnteTextTheme(context)
                      .mini
                      .copyWith(color: getEnteColorScheme(context).textMuted),
                ),
              ),
              childCount: 1,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (delegateBuildContext, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: _getMlSettings(context),
                  ),
                );
              },
              childCount: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getMlSettings(BuildContext context) {
    final colorScheme = getEnteColorScheme(context);
    final hasEnabled = localSettings.isFaceIndexingEnabled;
    return Column(
      children: [
        MenuItemWidget(
          captionedTextWidget: CaptionedTextWidget(
            title: S.of(context).mlFunctions,
          ),
          menuItemColor: colorScheme.fillFaint,
          trailingWidget: ToggleSwitchWidget(
            value: () => localSettings.isFaceIndexingEnabled,
            onChanged: () async {
              final isEnabled = await localSettings.toggleFaceIndexing();
              if (isEnabled) {
                await MLService.instance.init();
                await SemanticSearchService.instance.init();
                unawaited(MLService.instance.runAllML(force: true));
              } else {}
              if (mounted) {
                setState(() {});
              }
            },
          ),
          singleBorderRadius: 8,
          alignCaptionedTextToLeft: true,
          isGestureDetectorDisabled: true,
        ),
        const SizedBox(
          height: 12,
        ),
        hasEnabled
            ? MLService.instance.allModelsLoaded
                ? const MLStatusWidget()
                : const ModelLoadingState()
            : const SizedBox.shrink(),
      ],
    );
  }
}

class ModelLoadingState extends StatefulWidget {
  const ModelLoadingState({
    Key? key,
  }) : super(key: key);

  @override
  State<ModelLoadingState> createState() => _ModelLoadingStateState();
}

class _ModelLoadingStateState extends State<ModelLoadingState> {
  StreamSubscription<(String, int, int)>? _progressStream;
  final Map<String, (int, int)> _progressMap = {};
  @override
  void initState() {
    _progressStream =
        RemoteAssetsService.instance.progressStream.listen((event) {
      final String url = event.$1;
      String title = "";
      if (url.contains("clip-image")) {
        title = "Image Model";
      } else if (url.contains("clip-text")) {
        title = "Text Model";
      } else if (url.contains("yolov5s_face")) {
        title = "Face Detection Model";
      } else if (url.contains("mobilefacenet")) {
        title = "Face Embedding Model";
      }
      if (title.isNotEmpty) {
        _progressMap[title] = (event.$2, event.$3);
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _progressStream?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MenuSectionTitle(title: S.of(context).status),
        MenuItemWidget(
          captionedTextWidget: CaptionedTextWidget(
            title: _getTitle(context),
          ),
          trailingWidget: EnteLoadingWidget(
            size: 12,
            color: getEnteColorScheme(context).fillMuted,
          ),
          singleBorderRadius: 8,
          alignCaptionedTextToLeft: true,
          isGestureDetectorDisabled: true,
        ),
        // show the progress map if in debug mode
        if (flagService.internalUser)
          ..._progressMap.entries.map((entry) {
            return MenuItemWidget(
              key: ValueKey(entry.value),
              captionedTextWidget: CaptionedTextWidget(
                title: entry.key,
              ),
              trailingWidget: Text(
                entry.value.$1 == entry.value.$2
                    ? "Done"
                    : "${formatBytes(entry.value.$1)} / ${formatBytes(entry.value.$2)}",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              singleBorderRadius: 8,
              alignCaptionedTextToLeft: true,
              isGestureDetectorDisabled: true,
            );
          }).toList(),
      ],
    );
  }

  String _getTitle(BuildContext context) {
    // TODO: uncomment code below to actually check for high bandwidth
    // final usableConnection = await canUseHighBandwidth();
    // if (!usableConnection) {
    //   return S.of(context).waitingForWifi;
    // }
    return S.of(context).loadingModel;
  }
}

class MLStatusWidget extends StatefulWidget {
  const MLStatusWidget({
    super.key,
  });

  @override
  State<MLStatusWidget> createState() => MLStatusWidgetState();
}

class MLStatusWidgetState extends State<MLStatusWidget> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      setState(() {});
    });
  }

  Future<IndexStatus> _getIndexStatus() async {
    final status = await getIndexStatus();
    return status;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            MenuSectionTitle(title: S.of(context).status),
            Expanded(child: Container()),
          ],
        ),
        FutureBuilder(
          future: _getIndexStatus(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final bool isDeviceHealthy =
                  MachineLearningController.instance.isDeviceHealthy;
              final int indexedFiles = snapshot.data!.indexedItems;
              final int pendingFiles = snapshot.data!.pendingItems;

              if (!isDeviceHealthy && pendingFiles > 0) {
                return MenuSectionDescriptionWidget(
                  content: S.of(context).indexingIsPaused,
                );
              }

              return Column(
                children: [
                  MenuItemWidget(
                    captionedTextWidget: CaptionedTextWidget(
                      title: S.of(context).indexedItems,
                    ),
                    trailingWidget: Text(
                      NumberFormat().format(indexedFiles),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    singleBorderRadius: 8,
                    alignCaptionedTextToLeft: true,
                    isGestureDetectorDisabled: true,
                    key: ValueKey("indexed_items_" + indexedFiles.toString()),
                  ),
                  MenuItemWidget(
                    captionedTextWidget: CaptionedTextWidget(
                      title: S.of(context).pendingItems,
                    ),
                    trailingWidget: Text(
                      NumberFormat().format(pendingFiles),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    singleBorderRadius: 8,
                    alignCaptionedTextToLeft: true,
                    isGestureDetectorDisabled: true,
                    key: ValueKey("pending_items_" + pendingFiles.toString()),
                  ),
                  MLService.instance.showClusteringIsHappening
                      ? MenuItemWidget(
                          captionedTextWidget: CaptionedTextWidget(
                            title: S.of(context).clusteringProgress,
                          ),
                          trailingWidget: Text(
                            "currently running",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          singleBorderRadius: 8,
                          alignCaptionedTextToLeft: true,
                          isGestureDetectorDisabled: true,
                        )
                      : const SizedBox.shrink(),
                ],
              );
            }
            return const EnteLoadingWidget();
          },
        ),
      ],
    );
  }
}
