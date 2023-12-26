class Profile {
  const Profile({
    required this.label,
    required this.storageString,
    this.isDefault = false,
    this.isVertical = false,
  });

  final String label;
  final String storageString;
  final bool isDefault;
  final bool isVertical;
}
