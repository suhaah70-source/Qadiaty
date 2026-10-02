/// Converts Arabic-Indic and Persian digits to Western digits for API fields
/// that require numeric values. Arabic text in other fields remains unchanged.
String normalizeInputDigits(String value) {
  return String.fromCharCodes(value.runes.map((rune) {
    if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
    if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
    return rune;
  }));
}
