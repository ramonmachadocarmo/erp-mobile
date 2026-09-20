class Role {
  const Role({
    required this.id,
    required this.code,
    required this.name,
    this.isMaster = false,
    this.isSystem = false,
  });

  final String id;
  final String code;
  final String name;
  final bool isMaster;
  final bool isSystem;
}

/// A role's permission matrix: module / menu key -> level (0 none, 1 view, 2 edit).
class RolePermissions {
  const RolePermissions({this.modules = const {}, this.menus = const {}});

  final Map<String, int> modules;
  final Map<String, int> menus;
}
