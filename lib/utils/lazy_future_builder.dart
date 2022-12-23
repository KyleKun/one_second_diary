import 'package:flutter/widgets.dart';

typedef GetFuture<T> = Future<T> Function();

/// The Lazy Future Builder should be used in cases where you need the future passed to
/// [FutureBuilder] to run only once. i.e the first time the screen is built.
class LazyFutureBuilder<T> extends StatefulWidget {
  final GetFuture<T>? future;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  const LazyFutureBuilder({
    Key? key,
    this.future,
    required this.builder,
    this.initialData,
  }) : super(key: key);

  @override
  State<LazyFutureBuilder<T>> createState() => _LazyFutureBuilderState<T>();
}

class _LazyFutureBuilderState<T> extends State<LazyFutureBuilder<T>> {
  Future<T>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.future!();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      initialData: widget.initialData,
      builder: widget.builder,
      future: _future,
    );
  }
}
