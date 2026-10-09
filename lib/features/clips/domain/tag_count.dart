import 'package:equatable/equatable.dart';

/// One tag of a profile's vocabulary: its name (the casing seen first) and
/// how many visible clips carry it.
final class TagCount extends Equatable {
  const TagCount({required this.name, required this.count});

  final String name;
  final int count;

  @override
  List<Object?> get props => <Object?>[name, count];
}
