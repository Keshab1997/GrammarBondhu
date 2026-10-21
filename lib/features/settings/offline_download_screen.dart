import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';

/// Screen 16 — manage locally available chapter content.
///
/// v1 ships all chapters inside the app bundle, so every chapter is already
/// offline. The per-chapter action is kept ready for future downloadable
/// content packs (honest label: "Bundled with app").
class OfflineDownloadScreen extends StatefulWidget {
  const OfflineDownloadScreen({super.key});

  static const routeName = '/downloads';

  @override
  State<OfflineDownloadScreen> createState() => _OfflineDownloadScreenState();
}

class _OfflineDownloadScreenState extends State<OfflineDownloadScreen> {
  final _downloaded = <String>{};

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final chapters = context.watch<ContentController>().chapters;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Download Chapter'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'All chapters include story images, grammar lessons and quiz data. '
              'They work fully offline.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final chapter in chapters)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Row(
                    children: [
                      ChapterThumbnail(
                        assetPath: chapter.thumbnailAsset,
                        fallbackIcon: Icons.auto_stories_rounded,
                        size: 56,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chapter.title.en, style: text.titleMedium),
                            Text('Images + Audio + JSON Data',
                                style: text.bodyMedium),
                          ],
                        ),
                      ),
                      if (_downloaded.contains(chapter.id))
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success)
                      else
                        AppButton(
                          label: 'Download',
                          variant: AppButtonVariant.blue,
                          expand: false,
                          onPressed: () {
                            setState(() => _downloaded.add(chapter.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${chapter.title.en} is bundled with the app — ready offline.',
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
