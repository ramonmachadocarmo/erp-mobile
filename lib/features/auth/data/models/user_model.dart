import '../../domain/entities/user.dart';

class UserModel {
  const UserModel({
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
  final Map<String, int> menuPermissions;

  /// [menus] overrides `menu_permissions` when the server sends it beside the
  /// user object (login) instead of inside it (`/auth/me`, session cache).
  factory UserModel.fromJson(Map<String, dynamic> json, {Object? menus}) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      roleId: json['role_id']?.toString() ?? '',
      roleCode: json['role_code']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      menuPermissions: _menus(menus ?? json['menu_permissions']),
    );
  }

  static Map<String, int> _menus(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is num) e.key.toString(): (e.value as num).toInt(),
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role_id': roleId,
        'role_code': roleCode,
        'role_name': roleName,
        'menu_permissions': menuPermissions,
      };

  User toEntity() => User(
        id: id,
        email: email,
        name: name,
        roleId: roleId,
        roleCode: roleCode,
        roleName: roleName,
        menuPermissions: menuPermissions,
      );
}
