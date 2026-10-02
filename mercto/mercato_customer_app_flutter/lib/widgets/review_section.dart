import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/api_client.dart';
import 'package:mercato/providers/auth_provider.dart';
import 'package:mercato/screens/login_screen.dart';

String _reviewTx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class ReviewSection extends StatefulWidget {
  const ReviewSection(
      {super.key, required this.storeSlug, this.productId, this.accentColor});
  final String storeSlug;
  final String? productId;
  final Color? accentColor;

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final _comment = TextEditingController();
  Map<String, dynamic> _data = const {};
  int _rating = 5;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String get _path {
    final base = '/stores/${Uri.encodeComponent(widget.storeSlug)}/reviews';
    final product = widget.productId;
    return product == null
        ? base
        : '$base?product_id=${Uri.encodeQueryComponent(product)}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await ApiClient.instance.get(_path, auth: false)
          as Map<String, dynamic>;
      if (mounted)
        setState(() {
          _data = result;
          _error = null;
        });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = _reviewTx(
            context, 'تعذر تحميل التقييمات', 'Could not load reviews'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final comment = _comment.text.trim();
    if (comment.length < 2) {
      setState(() => _error = _reviewTx(
          context,
          'اكتب تعليقًا قصيرًا قبل الإرسال',
          'Write a short comment before submitting'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ApiClient.instance.post(
          '/stores/${Uri.encodeComponent(widget.storeSlug)}/reviews',
          body: {
            'rating': _rating,
            'comment': comment,
            if (widget.productId != null) 'product_id': widget.productId,
          });
      _comment.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = _reviewTx(
            context,
            'تعذر إرسال التقييم. حاول مرة أخرى.',
            'Could not submit your review. Try again.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    final reviews = (_data['reviews'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final average = (_data['average'] as num?)?.toDouble() ?? 0;
    final count = (_data['count'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_reviewTx(context, 'التقييمات والتعليقات', 'Ratings & reviews'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Text(average.toStringAsFixed(1),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
            const SizedBox(width: 6),
            Text(_reviewTx(context, 'من $count تقييم', '$count reviews'),
                style: TextStyle(color: Theme.of(context).hintColor)),
          ]),
          const SizedBox(height: 10),
          Row(
              children: List.generate(
                  5,
                  (index) => Icon(Icons.star_rounded,
                      size: 27,
                      color: index < _rating
                          ? const Color(0xFFFFB300)
                          : Colors.grey.shade300))),
          Slider(
              value: _rating.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: accent,
              label: '$_rating',
              onChanged: (value) => setState(() => _rating = value.round())),
          TextField(
              controller: _comment,
              minLines: 2,
              maxLines: 4,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                  labelText:
                      _reviewTx(context, 'اكتب تعليقك', 'Write a comment'),
                  border: const OutlineInputBorder())),
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _sending ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  child: Text(_sending
                      ? _reviewTx(context, 'جارٍ الإرسال...', 'Sending...')
                      : _reviewTx(context, 'إرسال التقييم', 'Submit review')))),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red))),
          const Divider(height: 22),
          if (_loading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator()))
          else if (reviews.isEmpty)
            Text(
                _reviewTx(context, 'كن أول من يقيّم',
                    'Be the first to leave a review'),
                style: TextStyle(color: Theme.of(context).hintColor))
          else
            ...reviews.map((review) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  review['author']?.toString() ??
                                      _reviewTx(context, 'عميل', 'Customer'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))),
                          const Icon(Icons.star_rounded,
                              size: 18, color: Color(0xFFFFB300)),
                          Text('${review['rating'] ?? 0}')
                        ]),
                        const SizedBox(height: 4),
                        Text(review['comment']?.toString() ?? ''),
                        const Divider(height: 18),
                      ]),
                )),
        ]),
      ),
    );
  }
}
