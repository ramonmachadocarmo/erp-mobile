import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/invoicing/domain/note_attachment.dart';

void main() {
  test('aceita XML, PDF e imagens sem diferenciar caixa', () {
    for (final n in ['nfe.xml', 'NOTA.PDF', 'foto.jpg', 'foto.JPEG', 'scan.png']) {
      expect(isAllowedNoteFile(n), isTrue, reason: n);
    }
  });

  test('rejeita outras extensões e nomes sem extensão', () {
    for (final n in ['nota.docx', 'foto.heic', 'semextensao', 'arquivo.', '']) {
      expect(isAllowedNoteFile(n), isFalse, reason: n);
    }
  });

  test('usa só a última extensão', () {
    expect(isAllowedNoteFile('nota.pdf.exe'), isFalse);
    expect(isAllowedNoteFile('nota.exe.pdf'), isTrue);
  });
}
