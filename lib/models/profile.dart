import 'package:flutter/material.dart';

@immutable
class Profile {
  const Profile({
    required this.label,
    this.isDefault = false,
    this.isVertical = false,
  });

  final String label;
  final bool isDefault;
  final bool isVertical;
}
