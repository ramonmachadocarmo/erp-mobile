import 'package:flutter/material.dart';

import '../theme.dart';

class StatusView {
  const StatusView({required this.label, required this.hint, required this.color});

  final String label;
  final String hint;
  final Color color;
}

StatusView statusView(String status) {
  switch (status) {
    case 'PENDING_RESERVATION':
      return const StatusView(label: 'Aguardando reserva', hint: 'Estoque ainda não foi reservado para este pedido.', color: Color(0xFFE6B84D));
    case 'APPROVED':
      return const StatusView(label: 'Aprovado', hint: 'Pedido liberado, aguardando separação.', color: erpAccent);
    case 'PICKING':
      return const StatusView(label: 'Em separação', hint: 'Itens estão sendo separados no almoxarifado.', color: Color(0xFFE6B84D));
    case 'PICKED':
      return const StatusView(label: 'Separado', hint: 'Pronto para roteirizar e entregar.', color: erpAccent);
    case 'DELIVERED':
      return const StatusView(label: 'Entregue', hint: 'Entrega confirmada ao cliente.', color: Color(0xFF3ECF8E));
    case 'UNDELIVERED':
      return const StatusView(label: 'Não entregue', hint: 'Tentativa de entrega não realizada.', color: erpDanger);
    case 'INVOICED':
      return const StatusView(label: 'Faturado', hint: 'Nota fiscal emitida.', color: Color(0xFF3ECF8E));
    case 'RECEIVED':
      return const StatusView(label: 'Recebido', hint: 'Mercadoria recebida, aguardando conferência.', color: erpAccent);
    case 'CONFERRED':
      return const StatusView(label: 'Conferido', hint: 'Conferência concluída.', color: Color(0xFF3ECF8E));
    case 'CANCELLED':
      return const StatusView(label: 'Cancelado', hint: 'Pedido cancelado.', color: erpDanger);
    case 'PLANNED':
      return const StatusView(label: 'Planejada', hint: 'Rota montada, ainda não confirmada.', color: erpMuted);
    case 'CONFIRMED':
      return const StatusView(label: 'Confirmada', hint: 'Rota confirmada para execução.', color: erpAccent);
    case 'IN_PROGRESS':
      return const StatusView(label: 'Em andamento', hint: 'Algumas paradas já foram entregues.', color: Color(0xFFE6B84D));
    case 'DONE':
      return const StatusView(label: 'Concluída', hint: 'Todas as paradas da rota foram entregues.', color: Color(0xFF3ECF8E));
    default:
      return StatusView(label: status, hint: status, color: erpMuted);
  }
}

Widget statusChip(String status, {String extra = ''}) {
  final s = statusView(status);
  final hint = extra.isEmpty ? s.hint : '${s.hint} Motivo: $extra';
  return Tooltip(
    message: hint,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: erpPanel2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(s.label, style: TextStyle(color: s.color, fontSize: 11, fontWeight: FontWeight.w700)),
    ),
  );
}
