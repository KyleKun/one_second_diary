/// Button heights and radii.
enum OsdButtonSize {
  compact(48, 14),

  dense(50, 16),

  standard(52, 16),

  medium(54, 16),

  large(56, 18),

  hero(58, 18);

  const OsdButtonSize(this.height, this.radius);

  /// The minimum height; it grows under large text.
  final double height;

  final double radius;
}
