/// Formatos aceitos ao anexar a nota de entrada: XML/PDF da NF-e ou foto (JPG/PNG) da nota/recibo.
const noteFileExtensions = ['xml', 'pdf', 'jpg', 'jpeg', 'png'];

bool isAllowedNoteFile(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return false;
  return noteFileExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// Como o usuário anexa a nota de entrada.
enum NoteSource { file, photo, none }
