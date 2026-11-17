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
import '../purchase/data/purchase_providers.dart';
import '../purchase/paywall_screen.dart';
import '../puzzle/difficulty_labels.dart';
import '../puzzle/domain/difficulty.dart';
import 'catalog_grid.dart';
import 'data/manifest_provider.dart';
import 'difficulty_dialog.dart';
import 'domain/content_manifest.dart';

/// Pictures of one category with the best completed difficulty.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final manifest = ref.watch(manifestProvider);
    final category = manifest.value?.categoryById(categoryId);
    final progress = ref.watch(progressProvider).value;
    final cdnBaseUrl = ref.watch(cdnBaseUrlProvider);
    final bundledAssets = ref.watch(bundledAssetsProvider).value;
    void leave() => context.canPop() ? context.pop() : context.go('/');
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CatalogHeader(
                title: category?.title.resolve(language) ?? '',
                leading: RoundIconButton(
                  tooltip: l10n.back,
                  icon: Icons.arrow_back_rounded,
                  onPressed: leave,
                ),
              ),
              Expanded(
                // Data first: a reload keeps the previous catalog on screen.
                child: switch (manifest) {
                  AsyncValue(hasValue: true) when category == null =>
                    CatalogMessage(
                      text: l10n.categoryMissing,
                      actionLabel: l10n.back,
                      onAction: leave,
                    ),
                  AsyncValue(hasValue: true) => CatalogGrid(
                    itemCount: category!.puzzles.length,
                    itemBuilder: (context, index) {
                      final entry = category.puzzles[index];
                      return _PuzzleCard(
                        index: index,
                        entry: entry,
                        thumb: thumbImage(entry, cdnBaseUrl, bundledAssets),
                        best: progress?.bestFor(entry.id),
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

class _PuzzleCard extends ConsumerWidget {
  const _PuzzleCard({
    required this.index,
    required this.entry,
    required this.thumb,
    required this.best,
  });

  final int index;
  final PuzzleEntry entry;
  final ImageProvider? thumb;
  final Difficulty? best;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final best = this.best;
    final locked = !ref.watch(canPlayProvider(entry));
    return PictureCard(
      index: index,
      image: thumb,
      lockedLabel: locked ? l10n.lockedPicture : null,
      onTap: locked
          ? () => openPaywallThroughGate(context, ref)
          : () => showDifficultyDialog(context, entry),
      caption: Text(
        entry.title.resolve(language),
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: BookPalette.text),
        overflow: TextOverflow.ellipsis,
      ),
      badge: best == null
          ? null
          : Tooltip(
              message: l10n.bestDifficulty(best.label(l10n)),
              child: DifficultyStars(best: best),
            ),
    );
  }
}

/// One star per difficulty level, filled up to the best completed one.
class DifficultyStars extends StatelessWidget {
  const DifficultyStars({super.key, required this.best});

  final Difficulty best;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BookPalette.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final level in Difficulty.values)
              Icon(
                level.index <= best.index
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 20,
                color: BookPalette.star,
              ),
          ],
        ),
      ),
    );
  }
}
