import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../app/theme.dart';
import '../../../../core/error/failure.dart';
import '../providers/auth_notifier.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Device has biometrics enrolled.
  var _bioAvailable = false;
  // Credentials are stored, so the fingerprint can sign in.
  var _bioEnabled = false;
  // "Enable on this device" checkbox for a password sign-in.
  var _enableBio = true;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _initBiometrics() async {
    final available = await ref.read(biometricServiceProvider).isAvailable();
    final saved = available
        ? await ref.read(sessionStoreProvider).readBiometricCredentials()
        : null;
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEnabled = saved != null;
    });
    // Offer the fingerprint right away, like the usual banking-app flow.
    if (saved != null) _signInWithBiometrics();
  }

  Future<void> _signInWithBiometrics() async {
    final store = ref.read(sessionStoreProvider);
    final saved = await store.readBiometricCredentials();
    if (saved == null) {
      if (mounted) setState(() => _bioEnabled = false);
      return;
    }
    final ok = await ref
        .read(biometricServiceProvider)
        .authenticate('Confirme sua identidade para entrar');
    if (!ok || !mounted) return;
    final failure = await ref
        .read(authNotifierProvider.notifier)
        .login(email: saved.email, password: saved.password);
    // A rejected password (changed or revoked) makes the stored one useless.
    if (failure is UnauthorizedFailure) {
      await store.clearBiometricCredentials();
      if (mounted) setState(() => _bioEnabled = false);
    }
  }

  Future<void> _disableBiometrics() async {
    await ref.read(sessionStoreProvider).clearBiometricCredentials();
    if (mounted) setState(() => _bioEnabled = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ERP',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Entre com sua conta',
                        style: TextStyle(color: erpMuted),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Informe o e-mail'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(labelText: 'Senha'),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Informe a senha' : null,
                      ),
                      if (_bioAvailable && !_bioEnabled)
                        CheckboxListTile(
                          value: _enableBio,
                          onChanged: (v) =>
                              setState(() => _enableBio = v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text(
                            'Entrar com biometria neste aparelho',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      if (auth.loginError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.loginError!,
                          style: const TextStyle(color: erpDanger),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: auth.loggingIn ? null : _submit,
                        child: Text(auth.loggingIn ? 'Entrando...' : 'Entrar'),
                      ),
                      if (_bioEnabled) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: auth.loggingIn
                              ? null
                              : _signInWithBiometrics,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Entrar com biometria'),
                        ),
                        TextButton(
                          onPressed: _disableBiometrics,
                          child: const Text('Desativar biometria'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final password = _password.text;
    final store = ref.read(sessionStoreProvider);
    final remember = _bioAvailable && !_bioEnabled && _enableBio;
    final failure = await ref
        .read(authNotifierProvider.notifier)
        .login(email: email, password: password);
    // Only a working password is worth keeping. `store` was read up front
    // because a successful login navigates away and disposes this page.
    if (failure == null && remember) {
      await store.saveBiometricCredentials(email: email, password: password);
    }
  }
}
