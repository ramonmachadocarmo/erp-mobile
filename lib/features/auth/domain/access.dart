import '../../../app/nav.dart';
import 'entities/user.dart';

const permNone = 0;
const permView = 1;
const permEdit = 2;

const masterRoleCode = 'MASTER';

/// What the signed-in user's role may see and change. Mirrors
/// `apps/web/packages/shared/src/permissions.ts`; the gateway is what actually
/// enforces module access, this only shapes the UI.
class Access {
  const Access(this._user);

  static const none = Access(null);

  final User? _user;

  bool get isMaster => _user?.roleCode == masterRoleCode;

  int levelForKey(String menuKey) {
    if (isMaster) return permEdit;
    return _user?.menuPermissions[menuKey] ?? permNone;
  }

  /// Level for an app route (`/estoque/saldos`, `/logistica/conferencia/42`).
  /// Routes that are not menu screens (login, redirects) are unrestricted.
  int levelForPath(String path) {
    final item = _itemFor(path);
    return item == null ? permEdit : levelForKey(item.menuKey);
  }

  bool canView(String path) => levelForPath(path) >= permView;

  bool canEdit(String path) => levelForPath(path) >= permEdit;

  /// First menu screen the user may open, used as landing page.
  String? get firstAllowedPath {
    for (final g in navGroups) {
      for (final i in g.items) {
        if (levelForKey(i.menuKey) >= permView) return i.path;
      }
    }
    return null;
  }

  List<NavGroup> filterNav(List<NavGroup> groups) {
    if (isMaster) return groups;
    return [
      for (final g in groups)
        if (g.items.any((i) => levelForKey(i.menuKey) >= permView))
          NavGroup(
            title: g.title,
            items: [
              for (final i in g.items)
                if (levelForKey(i.menuKey) >= permView) i,
            ],
          ),
    ];
  }

  // Longest-prefix match, like the web's `hasRouteAccess`.
  NavItem? _itemFor(String path) {
    NavItem? best;
    for (final g in navGroups) {
      for (final i in g.items) {
        final hit = path == i.path || path.startsWith('${i.path}/');
        if (hit && (best == null || i.path.length > best.path.length)) best = i;
      }
    }
    return best;
  }
}
