enum ActionStatus { success, failure, notSupported }

class NavigationAction {
  final ActionStatus status;
  final String? message;

  const NavigationAction({required this.status, this.message});

  static const success = NavigationAction(status: ActionStatus.success);

  factory NavigationAction.failure(String reason) =>
      NavigationAction(status: ActionStatus.failure, message: reason);

  factory NavigationAction.notSupported(String reason) =>
      NavigationAction(status: ActionStatus.notSupported, message: reason);

  bool get isSuccess => status == ActionStatus.success;

  @override
  String toString() => 'NavigationAction($status${message != null ? ': $message' : ''})';
}
