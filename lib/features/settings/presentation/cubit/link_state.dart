import 'package:equatable/equatable.dart';

/// Where the last link a page opened is.
///
/// Every attempt starts with [opening], so each [failed] is a new transition
/// a `BlocListener` sees, however many come in a row.
enum LinkStatus {
  /// No link was opened yet.
  idle,

  /// A link is being handed to the browser.
  opening,

  /// The browser (or the app that handles the link) took it.
  opened,

  /// Nothing on the phone could open [LinkState.failedLink].
  failed,
}

/// The outcome of the last link a Settings page opened.
final class LinkState extends Equatable {
  const LinkState({this.status = LinkStatus.idle, this.failedLink});

  final LinkStatus status;

  /// The link that could not be opened, for "Copy link".
  final Uri? failedLink;

  @override
  List<Object?> get props => <Object?>[status, failedLink];
}
