import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/scan_code.dart';
import '../theme.dart';

/// Resposta do tratador de leitura no modo contínuo: aparece como faixa sobre a câmera.
class ScanFeedback {
  const ScanFeedback.ok(this.message) : ok = true;
  const ScanFeedback.error(this.message) : ok = false;

  final bool ok;
  final String message;
}

typedef ScanHandler = Future<ScanFeedback> Function(String code);

/// Abre a câmera, devolve o primeiro código lido (ou digitado) e fecha. Null se cancelar.
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScanPage()));
}

/// Modo contínuo: a câmera continua aberta e cada código lido é entregue a [onCode] (uma leitura
/// por vez, sem repetir o mesmo código a cada frame), até o usuário tocar em "Concluir".
Future<void> scanBarcodes(
  BuildContext context, {
  required ScanHandler onCode,
  String title = 'Bipar',
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => BarcodeScanPage(onCode: onCode, title: title)),
  );
}

class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({super.key, this.onCode, this.title = 'Bipar'});

  /// Null = leitura única (fecha devolvendo o código); preenchido = modo contínuo.
  final ScanHandler? onCode;
  final String title;

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  final _controller = MobileScannerController();
  final _debouncer = ScanDebouncer();
  var _done = false;
  var _processing = false;
  ScanFeedback? _feedback;

  bool get _continuous => widget.onCode != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw, {bool manual = false}) async {
    final code = raw.trim();
    if (code.isEmpty || _done || _processing) return;
    if (!manual && !_debouncer.accept(code, DateTime.now())) return;
    if (!_continuous) {
      _done = true;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(code);
      return;
    }
    _processing = true;
    try {
      final fb = await widget.onCode!(code);
      if (fb.ok) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
      if (mounted) setState(() => _feedback = fb);
    } catch (e) {
      if (mounted) setState(() => _feedback = ScanFeedback.error('$e'));
    } finally {
      _processing = false;
    }
  }

  Future<void> _typeManually() async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Digitar código'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Código de barras ou SKU'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('OK')),
        ],
      ),
    );
    ctl.dispose();
    if (code != null) await _handle(code, manual: true);
  }

  Widget _error(BuildContext context, MobileScannerException e) {
    final denied = e.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              denied
                  ? 'Sem permissão para usar a câmera. Libere o acesso nas configurações do aparelho ou digite o código.'
                  : 'Não foi possível abrir a câmera. Digite o código.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _typeManually,
              icon: const Icon(Icons.keyboard),
              label: const Text('Digitar código'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = _feedback;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) return const SizedBox.shrink();
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Desligar lanterna' : 'Ligar lanterna',
                onPressed: _controller.toggleTorch,
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
              );
            },
          ),
          IconButton(
            tooltip: 'Trocar câmera',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch),
          ),
          IconButton(
            tooltip: 'Digitar código',
            onPressed: _typeManually,
            icon: const Icon(Icons.keyboard),
          ),
        ],
      ),
      backgroundColor: erpBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, e) => _error(context, e),
            onDetect: (capture) {
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null && v.trim().isNotEmpty) {
                  _handle(v);
                  break;
                }
              }
            },
          ),
          if (fb != null)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: (fb.ok ? Colors.green : erpDanger).withValues(alpha: 0.92),
                child: Row(
                  children: [
                    Icon(fb.ok ? Icons.check_circle : Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(fb.message, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Aponte para o código de barras ou QR',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (_continuous) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Concluir'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
