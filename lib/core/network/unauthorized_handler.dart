class UnauthorizedHandler {
  void Function()? _listener;

  void listen(void Function() fn) => _listener = fn;

  void notify() => _listener?.call();

  void clear() => _listener = null;
}
