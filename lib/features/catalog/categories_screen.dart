import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/book_palette.dart';
import '../../app/widgets/paper_background.dart';
import '../../app/widgets/round_icon_button.dart';
import '../../l10n/app_localizations.dart';
import '../content/content_config.dart';
import '../content/thumb_image.dart';
import '../progress/data/progress_controller.dart';
import '../progress/domain/puzzle_progress.dart';
import 'catalog_grid.dart';
import 'data/manifest_provider.dart';
import 'domain/content_manifest.dart';

/// Start screen: one card per category with collected pictures.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final manifest = ref.watch(manifestProvider);
    final progress =
        ref.watch(progressProvider).value ?? const PuzzleProgress();
    final cdnBaseUrl = ref.watch(cdnBaseUrlProvider);
    final bundledAssets = ref.watch(bundledAssetsProvider).value;
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CatalogHeader(
                title: l10n.appTitle,
                trailing: RoundIconButton(
                  tooltip: l10n.settings,
                  icon: Icons.settings_rounded,
                  onPressed: () => context.push('/settings'),
                ),
              ),
              Expanded(
                // Data first: a reload keeps the previous catalog on screen.
                child: switch (manifest) {
                  AsyncValue(:final value?) => CatalogGrid(
                    itemCount: value.categories.length,
                    itemBuilder: (context, index) {
                      final category = value.categories[index];
                      return _CategoryCard(
                        index: index,
                        category: category,
                        thumb: thumbImage(
                          category.puzzles.firstOrNull,
                          cdnBaseUrl,
                          bundledAssets,
                        ),
                        progress: progress,
                      );
                    },
                  ),
                  AsyncError() => CatalogMessage(
                    text: l10n.catalogLoadError,
                    actionLabel: l10n.retry,
                    onAction: () => ref.invalidate(manifestProvider),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.index,
    required this.category,
    required this.thumb,
    required this.progress,
  });

  final int index;
  final CategoryEntry category;
  final ImageProvider? thumb;

  /// Null while progress loads; the counter is hidden until then.
  final PuzzleProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final ids = category.puzzles.map((p) => p.id);
    final progress = this.progress;
    return PictureCard(
      index: index,
      image: thumb,
      onTap: () => context.push('/category/${category.id}'),
      caption: Row(
        children: [
          Expanded(
            child: Text(
              category.title.resolve(language),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: BookPalette.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (progress != null) ...[
            const Icon(Icons.star_rounded, size: 18, color: BookPalette.star),
            const SizedBox(width: 2),
            Text(
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: BookPalette.textMuted),
              l10n.collectedCount(
                progress.completedCount(ids),
                category.puzzles.length,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
