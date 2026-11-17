import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/book_button.dart';
import '../../app/widgets/paper_background.dart';
import '../../app/widgets/round_icon_button.dart';
import '../../l10n/app_localizations.dart';
import '../content/data/picture_store.dart';
import '../settings/data/settings_controller.dart';
import 'domain/difficulty.dart';
import 'domain/puzzle_board.dart';
import 'domain/puzzle_layout.dart';
import 'domain/puzzle_session.dart';
import 'game/puzzle_game.dart';
import 'puzzle_controller.dart';
import 'win_overlay.dart';

String puzzleRoute(String puzzleId, Difficulty difficulty) =>
    '/puzzle/$puzzleId?difficulty=${difficulty.name}';

class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.puzzleId,
    required this.difficulty,
  });

  final String puzzleId;
  final Difficulty difficulty;

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  /// Puzzle screens alive right now. "Next" mounts the new screen before
  /// the old one is disposed, so full screen is left only at zero.
  static var _activeScreens = 0;

  /// Lets the snap animation finish before the win overlay appears.
  static const _winDelay = Duration(milliseconds: 450);

  late final PuzzleArgs _args = (
    puzzleId: widget.puzzleId,
    difficulty: widget.difficulty,
  );
  PuzzleGame? _game;
  Size? _gameSize;
  PuzzleSession? _gameSession;
  bool? _gameShowsHint;
  bool? _gameHandHint;
  bool? _gameReducedMotion;
  Timer? _winTimer;
  bool _showWin = false;

  @override
  void initState() {
    super.initState();
    _activeScreens++;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _winTimer?.cancel();
    if (--_activeScreens == 0) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  /// One game per session, play area size, hint settings and motion mode.
  PuzzleGame _gameFor(
    Size size,
    PuzzleState state, {
    required bool showHint,
    required bool handHint,
    required bool reducedMotion,
  }) {
    final existing = _game;
    if (existing != null &&
        _gameSize == size &&
        _gameShowsHint == showHint &&
        _gameHandHint == handHint &&
        _gameReducedMotion == reducedMotion &&
        identical(_gameSession, state.session)) {
      return existing;
    }
    _gameSize = size;
    _gameSession = state.session;
    _gameShowsHint = showHint;
    _gameHandHint = handHint;
    _gameReducedMotion = reducedMotion;
    return _game = PuzzleGame(
      image: state.setup.image,
      session: state.session,
      layout: PuzzleLayout.compute(size),
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      showHint: showHint,
      handHint: handHint,
      firstPuzzle: state.firstPuzzle,
      reducedMotion: reducedMotion,
      onPiecePicked: () =>
          ref.read(puzzleControllerProvider(_args).notifier).piecePicked(),
      onPieceDropped: _onPieceDropped,
    );
  }

  void _onPieceDropped(DropResult result) {
    if (result == DropResult.placed) HapticFeedback.lightImpact();
    ref.read(puzzleControllerProvider(_args).notifier).pieceDropped(result);
  }

  void _onStateChanged(PuzzleState? previous, PuzzleState? next) {
    final completed = next?.completed ?? false;
    if (completed && !(previous?.completed ?? false)) {
      _winTimer = Timer(_winDelay, () {
        if (mounted) setState(() => _showWin = true);
      });
    } else if (!completed) {
      _winTimer?.cancel();
      _showWin = false;
    }
  }

  void _leave() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = puzzleControllerProvider(_args);
    ref.listen(provider, (previous, next) {
      _onStateChanged(previous?.value, next.value);
    });
    final puzzle = ref.watch(provider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          child: switch (puzzle) {
            AsyncData(:final value) => _buildGame(value, l10n),
            AsyncError(:final error) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(switch (error) {
                    PuzzleLockedException() => l10n.pictureLocked,
                    PictureLoadException(failure: PictureLoadFailure.network) =>
                      l10n.pictureOffline,
                    PictureLoadException(failure: PictureLoadFailure.corrupt) =>
                      l10n.pictureCorrupt,
                    PictureLoadException(
                      failure: PictureLoadFailure.unavailable,
                    ) =>
                      l10n.pictureUnavailable,
                    _ => l10n.loadError,
                  }, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    children: [
                      BookButton(
                        kind: BookButtonKind.text,
                        onPressed: _leave,
                        label: l10n.back,
                      ),
                      BookButton(
                        onPressed: () => ref.read(provider.notifier).retry(),
                        label: l10n.retry,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _ => _buildLoading(l10n),
          },
        ),
      ),
    );
  }

  /// A spinner, or the download share while a CDN picture comes in.
  Widget _buildLoading(AppLocalizations l10n) {
    final progress = ref.watch(
      pictureDownloadProgressProvider(widget.puzzleId),
    );
    if (progress == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress),
          const SizedBox(height: 12),
          Text(l10n.downloadingPicture((progress * 100).round())),
        ],
      ),
    );
  }

  Widget _buildGame(PuzzleState state, AppLocalizations l10n) {
    final next = ref.watch(nextPlayableProvider(widget.puzzleId));
    final controller = ref.read(puzzleControllerProvider(_args).notifier);
    final showHint = ref.watch(settingsProvider.select((s) => s.showHint));
    final handHint = ref.watch(settingsProvider.select((s) => s.handHint));
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final game = _gameFor(
          constraints.biggest,
          state,
          showHint: showHint,
          handHint: handHint,
          reducedMotion: reducedMotion,
        );
        return Stack(
          children: [
            // Any finger on the game hides the hand hint and restarts its
            // countdown; the listener never takes the gesture itself.
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => game.touchDown(),
              onPointerUp: (_) => game.touchUp(),
              onPointerCancel: (_) => game.touchUp(),
              child: GameWidget(key: ObjectKey(game), game: game),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: RoundIconButton(
                tooltip: l10n.back,
                icon: Icons.arrow_back_rounded,
                onPressed: _leave,
              ),
            ),
            if (_showWin && state.completed)
              Positioned.fill(
                child: WinOverlay(
                  board: game.layout.board,
                  onBack: _leave,
                  onPlayAgain: controller.playAgain,
                  onNext: next == null
                      ? null
                      : () => context.pushReplacement(
                          puzzleRoute(next.id, widget.difficulty),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}
