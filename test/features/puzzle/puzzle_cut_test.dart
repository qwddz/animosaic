import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzles/features/puzzle/domain/difficulty.dart';
import 'package:puzzles/features/puzzle/domain/piece_geometry.dart';
import 'package:puzzles/features/puzzle/domain/puzzle_cut.dart';

void main() {
  const boardSize = Size(800, 600);

  for (final difficulty in Difficulty.values) {
    group('${difficulty.name} ${difficulty.columns}x${difficulty.rows}', () {
      final cut = PuzzleCut.generate(
        columns: difficulty.columns,
        rows: difficulty.rows,
        seed: 42,
      );
      final geometry = PieceGeometry(cut: cut, boardSize: boardSize);

      test('has one piece per cell', () {
        expect(cut.pieceCount, difficulty.pieceCount);
      });

      test('border sides are flat and inner sides are not', () {
        for (var i = 0; i < cut.pieceCount; i++) {
          final kinds = cut.edgeKinds(i);
          final r = cut.rowOf(i), c = cut.columnOf(i);
          expect(kinds[0] == EdgeKind.flat, r == 0, reason: 'top of $i');
          expect(kinds[1] == EdgeKind.flat, c == cut.columns - 1);
          expect(kinds[2] == EdgeKind.flat, r == cut.rows - 1);
          expect(kinds[3] == EdgeKind.flat, c == 0);
        }
      });

      test('neighbours have a tab against a blank', () {
        for (var i = 0; i < cut.pieceCount; i++) {
          final r = cut.rowOf(i), c = cut.columnOf(i);
          if (c < cut.columns - 1) {
            final right = cut.edgeKinds(i)[1];
            final neighbourLeft = cut.edgeKinds(i + 1)[3];
            expect({right, neighbourLeft}, {EdgeKind.tab, EdgeKind.blank});
          }
          if (r < cut.rows - 1) {
            final bottom = cut.edgeKinds(i)[2];
            final neighbourTop = cut.edgeKinds(i + cut.columns)[0];
            expect({bottom, neighbourTop}, {EdgeKind.tab, EdgeKind.blank});
          }
        }
      });

      test('every outline fits its box and covers its cell centre', () {
        final box = Offset.zero & geometry.pieceSize;
        for (var i = 0; i < cut.pieceCount; i++) {
          final path = geometry.piecePath(i);
          final bounds = path.getBounds();
          expect(box.inflate(0.01).contains(bounds.topLeft), isTrue);
          expect(box.inflate(0.01).contains(bounds.bottomRight), isTrue);
          final centre =
              geometry.targetCenter(i) - geometry.pieceBox(i).topLeft;
          expect(path.contains(centre), isTrue, reason: 'piece $i');
        }
      });

      test('a knob belongs to exactly one of the two pieces', () {
        bool coveredBy(int piece, Offset boardPoint) => geometry
            .piecePath(piece)
            .contains(boardPoint - geometry.pieceBox(piece).topLeft);

        for (var i = 0; i < cut.pieceCount; i++) {
          final c = cut.columnOf(i);
          final edge = cut.rightEdge(i);
          if (edge == null || c == cut.columns - 1) continue;
          final cell = geometry.cellRect(i);
          // Middle of the knob head, on the side the knob bulges to.
          final knob = Offset(
            cell.right + edge.bulge * geometry.tabSize * edge.size * 0.75,
            cell.top + cell.height * edge.center,
          );
          final owner = edge.bulge > 0 ? i : i + 1;
          final other = edge.bulge > 0 ? i + 1 : i;
          expect(coveredBy(owner, knob), isTrue, reason: 'owner of $i');
          expect(coveredBy(other, knob), isFalse, reason: 'other of $i');
        }
      });
    });
  }

  test('the same seed gives the same cut, another seed a different one', () {
    List<List<EdgeKind>> kinds(int seed) {
      final cut = PuzzleCut.generate(columns: 6, rows: 4, seed: seed);
      return [for (var i = 0; i < cut.pieceCount; i++) cut.edgeKinds(i)];
    }

    expect(kinds(7), kinds(7));
    expect(kinds(7), isNot(kinds(8)));
  });
}
