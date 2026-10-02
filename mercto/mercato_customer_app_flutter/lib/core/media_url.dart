import 'package:mercato/core/constants.dart';

String? mediaUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  final api = Uri.parse(kApiBaseUrl);
  final root = api.replace(path: '', query: null, fragment: null);
  return root.resolve(value.startsWith('/') ? value : '/$value').toString();
}
