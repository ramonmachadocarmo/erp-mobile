// Regra de troca de item numa cesta/kit: o cliente tira um item da receita e leva outro no
// lugar, sem alterar o preço da cesta. O substituto entra na quantidade de mesmo valor de
// venda (arredondada ao passo da unidade de medida) e o valor do item nunca pode passar do
// valor do item original em mais de [maxPremium].
//
// Espelha apps/web/mfes/sales/src/kitSwap.ts — mesma regra dos dois lados, pra uma troca se
// comportar igual seja feita do app ou do web. Mantido como módulo puro (sem Flutter, sem I/O)
// pra ficar fácil comparar lado a lado quando um dos dois mudar.

/// Acréscimo máximo, sobre o valor do item removido, que a troca pode custar à loja.
const maxPremium = 0.15;

const _fractionalUoms = {'KG', 'L', 'LT', 'M', 'MT'};

/// Menor fração vendável: 0,1 para unidades de peso/volume/comprimento; inteiros pro resto
/// (UN, CX...).
double qtyStep(String? uom) =>
    _fractionalUoms.contains((uom ?? '').trim().toUpperCase()) ? 0.1 : 1;

double _round(double n) => double.parse(n.toStringAsFixed(4));

class Equivalence {
  const Equivalence._(this.ok, this.quantity, this.reason);

  factory Equivalence.ok(double quantity) => Equivalence._(true, quantity, '');
  factory Equivalence.fail(String reason) => Equivalence._(false, 0, reason);

  final bool ok;
  final double quantity;
  final String reason;
}

/// Quantidade do substituto pra repor [target] (valor do item removido) ao preço unitário
/// [price]. Prefere arredondar pra baixo (o cliente nunca leva mais que o valor removido),
/// desde que isso não perca mais que [maxPremium] do valor; senão sobe um passo, desde que não
/// exceda [maxPremium].
Equivalence equivalentQuantity(double target, double price, double step) {
  if (!(target > 0)) {
    return Equivalence.fail(
      'O item original não tem preço de venda, então não há valor equivalente para calcular.',
    );
  }
  if (!(price > 0)) {
    return Equivalence.fail('O item escolhido não tem preço de venda cadastrado.');
  }
  final raw = target / price / step;
  final down = _round((raw + 1e-9).floor() * step);
  final up = _round((raw - 1e-9).ceil() * step);
  if (down >= step && down * price >= target * (1 - maxPremium)) return Equivalence.ok(down);
  if (up >= step && up * price <= target * (1 + maxPremium)) return Equivalence.ok(up);
  final min = _round(step * price);
  final pct = (maxPremium * 100).round();
  return Equivalence.fail(
    'A menor quantidade vendável ($step) custa ${min.toStringAsFixed(2)}, mais de $pct% acima '
    'do item trocado (${target.toStringAsFixed(2)}).',
  );
}

/// Uma quantidade digitada à mão também respeita o teto de valor do item original.
bool withinPremium(double quantity, double price, double base) {
  if (!(base > 0) || !(price > 0)) return true;
  return quantity * price <= base * (1 + maxPremium) + 1e-9;
}
