import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/list_filters.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities/user.dart';
import '../roles_providers.dart';
import '../users_providers.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    return CrudList<User>(
      value: users,
      onRefresh: () => ref.read(usersProvider.notifier).reload(),
      titleOf: (u) => u.name,
      subtitleOf: (u) => u.roleName.isEmpty ? u.email : '${u.email} · ${u.roleName}',
      filters: [
        ListFilter<User>.byValue(label: 'Perfil', valueOf: (u) => u.roleName),
      ],
      onCreate: () => pushForm(context, const _UserForm()),
      onEdit: (u) => pushForm(context, _UserForm(user: u)),
    );
  }
}

class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({this.user});

  final User? user;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name ?? '');
  late final _email = TextEditingController(text: widget.user?.email ?? '');
  final _password = TextEditingController();
  late String? _roleId = (widget.user?.roleId.isEmpty ?? true) ? null : widget.user!.roleId;
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creating = widget.user == null;
    final roles = ref.watch(rolesProvider).valueOrNull ?? const [];
    return Form(
      key: _form,
      child: FormScaffold(
        title: creating ? 'Novo usuário' : 'Editar usuário',
        saving: _saving,
        onSave: _save,
        child: Column(
          children: [
            ErpField('Nome', _name, required: true),
            ErpField('E-mail', _email, required: true, keyboard: TextInputType.emailAddress),
            ErpField(
              creating ? 'Senha' : 'Senha (em branco para manter)',
              _password,
              required: creating,
              obscure: true,
              minLength: 6,
            ),
            ErpDropdown<String>(
              label: 'Perfil de acesso',
              value: roles.any((r) => r.id == _roleId) ? _roleId : null,
              items: [
                for (final r in roles) DropdownMenuItem(value: r.id, child: Text(r.name)),
              ],
              onChanged: (v) => setState(() => _roleId = v),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_roleId == null) {
      showError(context, 'Selecione o perfil de acesso');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(usersProvider.notifier).save(
            user: User(
              id: widget.user?.id ?? '',
              name: _name.text.trim(),
              email: _email.text.trim(),
              roleId: _roleId!,
            ),
            password: _password.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
