import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/scan_code.dart';
import 'package:mobile/features/stock/domain/entities.dart';
import 'package:mobile/features/stock/domain/product_lookup.dart';

void main() {
  group('parseScanCode', () {
    test('código simples vale quantidade 1', () {
      expect(parseScanCode('7891234567895'), const ScanCode('7891234567895', 1));
    });

    test('remove espaços nas pontas', () {
      expect(parseScanCode('  ABC-1 \n'), const ScanCode('ABC-1', 1));
    });

    test('aceita quantidade após vírgula ou ponto e vírgula', () {
      expect(parseScanCode('ABC,5'), const ScanCode('ABC', 5));
      expect(parseScanCode('ABC;12'), const ScanCode('ABC', 12));
      expect(parseScanCode('ABC , 3'), const ScanCode('ABC', 3));
    });

    test('quantidade decimal com vírgula ou ponto', () {
      expect(parseScanCode('ABC;2,5'), const ScanCode('ABC', 2.5));
      expect(parseScanCode('ABC,0.25'), const ScanCode('ABC', 0.25));
    });

    test('leitura vazia ou só espaços é inválida', () {
      expect(parseScanCode(''), isNull);
      expect(parseScanCode('   '), isNull);
    });

    test('quantidade zero é inválida', () {
      expect(parseScanCode('ABC,0'), isNull);
    });

    test('vírgula sem quantidade numérica mantém o texto como código', () {
      expect(parseScanCode('A,B'), const ScanCode('A,B', 1));
    });
  });

  group('parseScanCode sem quantidade (separação)', () {
    test('o texto todo é o código, mesmo com vírgula e número', () {
      expect(parseScanCode('000001,25', allowQuantity: false), const ScanCode('000001,25', 1));
    });

    test('SKU puro continua valendo 1', () {
      expect(parseScanCode(' 000001 ', allowQuantity: false), const ScanCode('000001', 1));
    });

    test('vazio é inválido', () {
      expect(parseScanCode('  ', allowQuantity: false), isNull);
    });
  });

  group('decodeWeightBarcode', () {
    // 2 + 000123 + 01500 (1,5 kg) + DV 2 — mesma regra do encodeWeightBarcode do web.
    test('etiqueta válida devolve SKU e peso em kg', () {
      expect(decodeWeightBarcode('2000123015002'), const ScanCode('000123', 1.5));
    });

    test('dígito verificador errado é rejeitado', () {
      expect(decodeWeightBarcode('2000123015003'), isNull);
    });

    test('não começa com 2, tamanho errado ou não numérico é rejeitado', () {
      expect(decodeWeightBarcode('7891234567895'), isNull);
      expect(decodeWeightBarcode('200012301500'), isNull);
      expect(decodeWeightBarcode('20001230150AB'), isNull);
    });

    test('peso zero é rejeitado', () {
      // 2 + 000123 + 00000 + DV 8
      expect(decodeWeightBarcode('2000123000008'), isNull);
    });

    test('aceita espaços nas pontas', () {
      expect(decodeWeightBarcode(' 2000123015002\n')?.code, '000123');
    });
  });

  group('sameCode', () {
    test('ignora caixa e espaços nas pontas', () {
      expect(sameCode(' abc ', 'ABC'), isTrue);
      expect(sameCode('abc', 'abd'), isFalse);
    });
  });

  group('ScanDebouncer', () {
    final t0 = DateTime(2026, 1, 1, 10);

    test('primeira leitura é aceita', () {
      expect(ScanDebouncer().accept('A', t0), isTrue);
    });

    test('mesmo código dentro do intervalo é ignorado', () {
      final d = ScanDebouncer()..accept('A', t0);
      expect(d.accept('A', t0.add(const Duration(milliseconds: 500))), isFalse);
      expect(d.accept('a', t0.add(const Duration(milliseconds: 1400))), isFalse);
    });

    test('mesmo código após o intervalo é aceito de novo', () {
      final d = ScanDebouncer()..accept('A', t0);
      expect(d.accept('A', t0.add(const Duration(milliseconds: 1500))), isTrue);
    });

    test('código diferente é aceito na hora', () {
      final d = ScanDebouncer()..accept('A', t0);
      expect(d.accept('B', t0.add(const Duration(milliseconds: 10))), isTrue);
    });

    test('ignorar uma repetição não prolonga o intervalo', () {
      final d = ScanDebouncer()..accept('A', t0);
      d.accept('A', t0.add(const Duration(milliseconds: 1000)));
      expect(d.accept('A', t0.add(const Duration(milliseconds: 1600))), isTrue);
    });
  });

  group('findProductByCode', () {
    const a = Product(id: '1', sku: 'SKU-A', name: 'A', barcode: '789001');
    const b = Product(id: '2', sku: 'SKU-B', name: 'B');
    final all = [a, b];

    test('acha por código de barras', () {
      expect(findProductByCode(all, '789001')?.id, '1');
    });

    test('acha por SKU sem diferenciar caixa', () {
      expect(findProductByCode(all, 'sku-b')?.id, '2');
    });

    test('não casa código vazio com produto sem código de barras', () {
      expect(findProductByCode(all, ''), isNull);
    });

    test('código desconhecido retorna null', () {
      expect(findProductByCode(all, '000'), isNull);
    });
  });
}
