class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    this.roleId = '',
    this.roleCode = '',
    this.roleName = '',
    this.menuPermissions = const {},
  });

  final String id;
  final String email;
  final String name;
  final String roleId;
  final String roleCode;
  final String roleName;

  /// Web menu key (e.g. `/estoque/saldos`) -> level (0 none, 1 view, 2 edit).
  /// Only populated for the signed-in user.
  final Map<String, int> menuPermissions;
}
