import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';

/// Screen 16 — chapters already available offline in the app bundle.
class OfflineDownloadScreen extends StatelessWidget {
  const OfflineDownloadScreen({super.key});

  static const routeName = '/downloads';

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
        title: const Text('Offline chapters'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Download hero illustration (storyboard frame 16).
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  'assets/illustrations/offline_download.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primarySoft,
                    child: const Icon(Icons.offline_pin_rounded,
                        size: 64, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Every chapter is included with the app. Stories, audio, grammar '
              'lessons and quizzes work offline — no download needed.',
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
                            Text('Included', style: text.bodyMedium),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success),
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
