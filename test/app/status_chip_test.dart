import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/widgets/status_chip.dart';

void main() {
  test('statusView labels', () {
    expect(statusView('PICKED').label, 'Separado');
    expect(statusView('UNDELIVERED').label, 'Não entregue');
    expect(statusView('DELIVERED').label, 'Entregue');
    expect(statusView('PLANNED').label, 'Planejada');
    expect(statusView('CONFIRMED').label, 'Confirmada');
    expect(statusView('IN_PROGRESS').label, 'Em andamento');
    expect(statusView('DONE').label, 'Concluída');
    expect(statusView('XYZ').label, 'XYZ');
  });

  testWidgets('statusChip', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: statusChip('PICKED'))));
    expect(find.text('Separado'), findsOneWidget);
  });
}
