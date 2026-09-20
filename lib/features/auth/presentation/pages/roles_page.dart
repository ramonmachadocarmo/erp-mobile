import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/nav.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/access.dart';
import '../../domain/entities/role.dart';
import '../providers/auth_notifier.dart';
import '../roles_providers.dart';

const _rolesPath = '/config/perfis';

class RolesPage extends ConsumerWidget {
  const RolesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(rolesProvider);
    final canEdit = ref.watch(accessProvider).canEdit(_rolesPath);
    return CrudList<Role>(
      value: roles,
      onRefresh: () => ref.read(rolesProvider.notifier).reload(),
      titleOf: (r) => r.name,
      subtitleOf: (r) => r.isMaster ? '${r.code} · acesso total' : r.code,
      onCreate: () => pushForm(context, const _RoleForm()),
      onEdit: (r) => pushForm(context, _RoleForm(role: r)),
      onDelete: (r) async {
        if (r.isMaster || r.isSystem) {
          showError(context, 'Perfis do sistema não podem ser excluídos');
          return;
        }
        try {
          await ref.read(rolesProvider.notifier).delete(r.id);
        } catch (e) {
          if (context.mounted) showError(context, '$e');
        }
      },
      extraActions: (_) => const [
        PopupMenuItem(value: 'permissions', child: Text('Permissões')),
      ],
      onAction: (r, _) => _openPermissions(context, r, canEdit),
      onTap: (r) => _openPermissions(context, r, canEdit),
    );
  }

  void _openPermissions(BuildContext context, Role role, bool canEdit) {
    pushForm(context, RolePermissionsPage(role: role, canEdit: canEdit && !role.isMaster));
  }
}

class _RoleForm extends ConsumerStatefulWidget {
  const _RoleForm({this.role});

  final Role? role;

  @override
  ConsumerState<_RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends ConsumerState<_RoleForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.role?.name ?? '');
  late final _code = TextEditingController(text: widget.role?.code ?? '');
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.role == null;
    return Form(
      key: _form,
      child: FormScaffold(
        title: creating ? 'Novo perfil' : 'Editar perfil',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpField('Nome', _name, required: true),
            // The code identifies the role and cannot change after creation.
            if (creating) ErpField('Código', _code, required: true),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(rolesProvider.notifier).save(
            Role(
              id: widget.role?.id ?? '',
              code: _code.text.trim().toUpperCase(),
              name: _name.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class RolePermissionsPage extends ConsumerStatefulWidget {
  const RolePermissionsPage({super.key, required this.role, required this.canEdit});

  final Role role;
  final bool canEdit;

  @override
  ConsumerState<RolePermissionsPage> createState() => _RolePermissionsPageState();
}

class _RolePermissionsPageState extends ConsumerState<RolePermissionsPage> {
  Map<String, int>? _modules;
  Map<String, int>? _menus;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(rolePermissionsProvider(widget.role.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role.name),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.canEdit)
            TextButton(
              onPressed: _saving || _menus == null ? null : _save,
              child: Text(_saving ? 'Salvando...' : 'Salvar'),
            ),
        ],
      ),
      body: loaded.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', style: const TextStyle(color: erpDanger)),
          ),
        ),
        data: (perms) {
          _modules ??= {...perms.modules};
          _menus ??= {...perms.menus};
          return _matrix();
        },
      ),
    );
  }

  Widget _matrix() {
    final modules = _modules!;
    final menus = _menus!;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (widget.role.isMaster)
          const _Notice('O perfil MASTER tem acesso total e não é editável.')
        else if (!widget.canEdit)
          const _Notice('Somente leitura para o seu perfil.'),
        const _Heading('Acesso por módulo (APIs)'),
        for (final (key, label) in accessModules)
          _LevelRow(
            label: label,
            level: widget.role.isMaster ? permEdit : modules[key] ?? 0,
            onChanged: widget.canEdit ? (v) => setState(() => modules[key] = v) : null,
          ),
        const _Heading('Acesso por menu'),
        for (final group in menuCatalog) ...[
          _SubHeading(group.title),
          for (final item in group.items)
            _LevelRow(
              label: item.label,
              level: widget.role.isMaster ? permEdit : menus[item.menuKey] ?? 0,
              onChanged: widget.canEdit ? (v) => setState(() => menus[item.menuKey] = v) : null,
            ),
        ],
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      (await ref.read(rolesRepositoryProvider).setPermissions(
                widget.role.id,
                RolePermissions(modules: _modules!, menus: _menus!),
              ))
          .getOrThrow();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      );
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(text, style: const TextStyle(color: erpMuted, fontWeight: FontWeight.w600)),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(text, style: const TextStyle(color: erpMuted)),
      );
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.label, required this.level, required this.onChanged});

  final String label;
  final int level;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: DropdownButton<int>(
        value: level,
        underline: const SizedBox.shrink(),
        onChanged: onChanged == null ? null : (v) => onChanged!(v ?? 0),
        items: const [
          DropdownMenuItem(value: 0, child: Text('Sem acesso')),
          DropdownMenuItem(value: 1, child: Text('Visualizar')),
          DropdownMenuItem(value: 2, child: Text('Editar')),
        ],
      ),
    );
  }
}
