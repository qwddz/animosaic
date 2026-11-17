/// Grid sizes from the plan. Columns × rows always gives near-square cells
/// on a 4:3 picture.
enum Difficulty {
  easy(3, 2),
  medium(4, 3),
  hard(6, 4),
  expert(8, 6);

  const Difficulty(this.columns, this.rows);

  final int columns;
  final int rows;

  int get pieceCount => columns * rows;

  static Difficulty? byName(String? name) {
    for (final difficulty in values) {
      if (difficulty.name == name) return difficulty;
    }
    return null;
  }
}
