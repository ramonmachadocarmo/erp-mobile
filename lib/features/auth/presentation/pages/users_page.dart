import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/crud_list.dart';
import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities/user.dart';
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
      subtitleOf: (u) => u.email,
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
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(usersProvider.notifier).save(
            user: User(
              id: widget.user?.id ?? '',
              name: _name.text.trim(),
              email: _email.text.trim(),
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
