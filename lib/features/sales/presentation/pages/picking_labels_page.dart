import 'package:flutter/material.dart';

import '../../../../app/widgets/form_kit.dart';
import '../../domain/entities.dart';

class PickingLabelsPage extends StatelessWidget {
  const PickingLabelsPage({
    super.key,
    required this.order,
    required this.customerName,
    this.address = '',
  });

  final SalesOrder order;
  final String customerName;
  final String address;

  @override
  Widget build(BuildContext context) {
    final n = order.volumeCount < 1 ? 1 : order.volumeCount;
    return Scaffold(
      appBar: AppBar(title: const Text('Etiquetas')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: n,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _LabelCard(
          order: order,
          customerName: customerName,
          address: address.isEmpty ? order.address.label : address,
          volume: i + 1,
          total: n,
        ),
      ),
    );
  }
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({
    required this.order,
    required this.customerName,
    required this.address,
    required this.volume,
    required this.total,
  });

  final SalesOrder order;
  final String customerName;
  final String address;
  final int volume;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.black, fontSize: 16, height: 1.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Pedido ${orderNo(order.id)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text('$volume/$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ],
              ),
              Text('Separação ${sepNo(order.pickingNumber)}'),
              const SizedBox(height: 8),
              Text(customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(address),
              const SizedBox(height: 8),
              Text('Volumes $total'),
            ],
          ),
        ),
      ),
    );
  }
}
