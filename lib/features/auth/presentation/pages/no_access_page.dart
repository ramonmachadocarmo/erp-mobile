import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class NoAccessPage extends StatelessWidget {
  const NoAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Seu perfil ainda não tem acesso a nenhuma tela.\n'
          'Peça a um administrador para liberar o acesso.',
          textAlign: TextAlign.center,
          style: TextStyle(color: erpMuted),
        ),
      ),
    );
  }
}
