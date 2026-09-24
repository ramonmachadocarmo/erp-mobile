/// Lógica pura da bipagem (sem câmera nem widgets) — testável e compartilhada por separação,
/// conferência e cadastro de produto.
library;

/// Resultado de interpretar o texto lido: [code] é o código do produto e [quantity] a quantidade
/// (1 quando o código veio sem quantidade).
class ScanCode {
  const ScanCode(this.code, this.quantity);

  final String code;
  final double quantity;

  @override
  bool operator ==(Object other) =>
      other is ScanCode && other.code == code && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(code, quantity);

  @override
  String toString() => 'ScanCode($code, $quantity)';
}

final _withQty = RegExp(r'^(.+?)\s*[,;]\s*(\d+(?:[.,]\d+)?)\s*$');

/// Aceita `CODIGO` ou, com [allowQuantity], `CODIGO,QTD` / `CODIGO;QTD` (QTD com ponto ou vírgula
/// decimal). Sem [allowQuantity] o texto todo é o código (ex.: separação, onde só vale o SKU).
/// Retorna null para leitura vazia ou quantidade <= 0.
ScanCode? parseScanCode(String raw, {bool allowQuantity = true}) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (!allowQuantity) return ScanCode(t, 1);
  final m = _withQty.firstMatch(t);
  if (m == null) return ScanCode(t, 1);
  final qty = double.tryParse(m.group(2)!.replaceAll(',', '.'));
  if (qty == null || qty <= 0) return null;
  return ScanCode(m.group(1)!.trim(), qty);
}

/// Comparação de códigos ignorando caixa e espaços nas pontas.
bool sameCode(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

/// Evita processar a mesma leitura várias vezes: a câmera reporta o mesmo código a cada frame
/// enquanto ele está à vista. Um código só é aceito de novo após [cooldown]; um código diferente
/// é aceito imediatamente.
class ScanDebouncer {
  ScanDebouncer({this.cooldown = const Duration(milliseconds: 1500)});

  final Duration cooldown;
  String? _last;
  DateTime? _lastAt;

  bool accept(String code, DateTime now) {
    if (_last != null && sameCode(_last!, code) && now.difference(_lastAt!) < cooldown) {
      return false;
    }
    _last = code;
    _lastAt = now;
    return true;
  }
}

int _ean13CheckDigit(String twelve) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(twelve[i]) * (i.isEven ? 1 : 3);
  }
  return (10 - sum % 10) % 10;
}

/// Etiqueta de pesagem (GS1 Brasil "prefixo 2", mesma do web em packages/shared/src/weightBarcode.ts):
/// `2` + SKU (6 dígitos) + peso em gramas (5 dígitos) + dígito verificador = 13 dígitos.
/// Devolve o SKU e o peso em kg como quantidade; null se não for uma etiqueta válida (formato,
/// dígito verificador errado ou peso zero).
ScanCode? decodeWeightBarcode(String raw) {
  final code = raw.trim();
  if (!RegExp(r'^2\d{12}$').hasMatch(code)) return null;
  if (_ean13CheckDigit(code.substring(0, 12)) != int.parse(code[12])) return null;
  final grams = int.parse(code.substring(7, 12));
  if (grams == 0) return null;
  return ScanCode(code.substring(1, 7), grams / 1000);
}
