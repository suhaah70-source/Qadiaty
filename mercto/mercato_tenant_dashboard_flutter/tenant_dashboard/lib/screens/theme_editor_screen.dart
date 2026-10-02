import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_theme.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';

Color _hexToColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

class ThemeEditorScreen extends StatefulWidget {
  const ThemeEditorScreen({super.key});

  @override
  State<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  final double hue;
  final double saturation;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final point = Offset(saturation * size.width, (1 - value) * size.height);
    canvas.drawCircle(point, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      point,
      8,
      Paint()
        ..color = HSVColor.fromAHSV(1, hue, saturation, value).toColor()
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      point,
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.saturation != saturation ||
      oldDelegate.value != value;
}

class _ThemeEditorScreenState extends State<ThemeEditorScreen> {
  StoreTheme _theme = StoreTheme(
      primaryColor: '#0D330E',
      secondaryColor: '#477023',
      backgroundColor: '#F3F5EF',
      textColor: '#071E07');
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  bool _uploading = false;
  final _logoController = TextEditingController();
  final _bannerController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  List<Map<String, dynamic>> _designElements = [];
  String? _selectedElementId;

  String? get _tenantId => context.read<AuthProvider>().tenantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tenantId = _tenantId;
    if (tenantId == null) return;
    final res = await ApiClient.instance.get('/tenants/$tenantId/theme')
        as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _theme = StoreTheme.fromJson(res);
      _logoController.text = _theme.logoUrl ?? '';
      _bannerController.text = _theme.bannerUrl ?? '';
      _storeNameController.text = _theme.storeName;
      _storeDescriptionController.text = _theme.storeDescription;
      _designElements = _theme.designElements
          .map((element) => Map<String, dynamic>.from(element))
          .toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saved = false;
    });
    final theme = _theme.copyWith(
      logoUrl: _logoController.text.isEmpty ? null : _logoController.text,
      bannerUrl: _bannerController.text.isEmpty ? null : _bannerController.text,
      storeName: _storeNameController.text.trim(),
      storeDescription: _storeDescriptionController.text.trim(),
      designElements: _designElements,
    );
    await ApiClient.instance
        .patch('/tenants/$_tenantId/theme', body: theme.toJson());
    if (!mounted) return;
    setState(() {
      _theme = theme;
      _saving = false;
      _saved = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  void _addDesignElement(String type) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final element = <String, dynamic>{
      'id': id,
      'type': type,
      'text': type == 'button' ? 'اكتشف منتجاتنا' : 'عنوان جديد',
      'x': .12,
      'y': .12 + (_designElements.length % 4) * .13,
      'width': .76,
      'height': type == 'shape' ? .18 : (type == 'image' ? .28 : .1),
      'color': type == 'shape' ? _theme.accentColor : _theme.primaryColor,
      'image_url': '',
      'font_size': 17.0,
      'radius': 14.0,
    };
    setState(() {
      _designElements = [..._designElements, element];
      _selectedElementId = id;
    });
  }

  Future<void> _addImageElement() async {
    try {
      final image = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (image == null) return;
      setState(() => _uploading = true);
      final url = await ApiClient.instance
          .uploadVendorImage(await image.readAsBytes(), image.name);
      if (!mounted) return;
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      setState(() {
        _designElements = [
          ..._designElements,
          {
            'id': id,
            'type': 'image',
            'text': '',
            'x': .2,
            'y': .12,
            'width': .6,
            'height': .3,
            'color': _theme.primaryColor,
            'image_url': url,
            'font_size': 16.0,
            'radius': 12.0,
          },
        ];
        _selectedElementId = id;
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _updateDesignElement(String id, Map<String, dynamic> changes) {
    setState(() {
      _designElements = _designElements.map((item) {
        if (item['id'] != id) return item;
        return {...item, ...changes};
      }).toList();
    });
  }

  void _moveDesignElement(String id, double dx, double dy) {
    final index = _designElements.indexWhere((item) => item['id'] == id);
    if (index < 0) return;
    final item = _designElements[index];
    final x = (item['x'] as num).toDouble();
    final y = (item['y'] as num).toDouble();
    final width = (item['width'] as num).toDouble();
    final height = (item['height'] as num).toDouble();
    _updateDesignElement(id, {
      'x': (x + dx).clamp(0.0, 1.0 - width),
      'y': (y + dy).clamp(0.0, 1.0 - height),
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _bannerController.dispose();
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload({required bool logo}) async {
    try {
      final image = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (image == null) return;
      setState(() => _uploading = true);
      final url = await ApiClient.instance
          .uploadVendorImage(await image.readAsBytes(), image.name);
      if (!mounted) return;
      setState(() {
        if (logo) {
          _logoController.text = url;
        } else {
          _theme = _theme.copyWith(
            backgroundImageUrl: url,
            backgroundStyle: 'image',
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(logo ? 'تم رفع الشعار' : 'تم رفع خلفية المتجر')));
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر اختيار الصورة أو رفعها')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _mediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${kApiBaseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '')}$path';
  }

  Widget _colorField(BuildContext context, String label, String value,
      void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface))),
          GestureDetector(
            onTap: () => _showAdvancedColorPicker(value, onChanged),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: _hexToColor(value),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.ashLight)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: TextEditingController(text: value)
                ..selection = TextSelection.collapsed(offset: value.length),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              onSubmitted: onChanged,
              onChanged: (v) {
                if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v)) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAdvancedColorPicker(
      String current, void Function(String) onChanged) {
    var hsv = HSVColor.fromColor(_hexToColor(current));
    final controller = TextEditingController(text: current);
    String toHex(Color color) =>
        '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اختار أي لون'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                height: 42,
                decoration: BoxDecoration(
                    color: hsv.toColor(),
                    borderRadius: BorderRadius.circular(8)),
              ),
              Slider(
                value: hsv.hue,
                min: 0,
                max: 360,
                activeColor: hsv.toColor(),
                onChanged: (value) => setDialogState(() {
                  hsv = hsv.withHue(value);
                  controller.text = toHex(hsv.toColor());
                }),
              ),
              SizedBox(
                width: 280,
                height: 160,
                child: LayoutBuilder(builder: (context, bounds) {
                  void update(Offset point) => setDialogState(() {
                        hsv = hsv
                            .withSaturation(
                                (point.dx / bounds.maxWidth).clamp(0.0, 1.0))
                            .withValue(1 -
                                (point.dy / bounds.maxHeight).clamp(0.0, 1.0));
                        controller.text = toHex(hsv.toColor());
                      });
                  return GestureDetector(
                    onPanDown: (event) => update(event.localPosition),
                    onPanUpdate: (event) => update(event.localPosition),
                    child: CustomPaint(
                      painter: _SaturationValuePainter(
                        hue: hsv.hue,
                        saturation: hsv.saturation,
                        value: hsv.value,
                      ),
                    ),
                  );
                }),
              ),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'HEX مثل #34A1FF'),
                onChanged: (value) {
                  if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
                    setDialogState(
                        () => hsv = HSVColor.fromColor(_hexToColor(value)));
                  }
                },
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var index = 0; index < 24; index++)
                  GestureDetector(
                    onTap: () => setDialogState(() {
                      hsv = HSVColor.fromAHSV(1, index * 15.0, .78, .82);
                      controller.text = toHex(hsv.toColor());
                    }),
                    child: CircleAvatar(
                        radius: 13,
                        backgroundColor:
                            HSVColor.fromAHSV(1, index * 15.0, .78, .82)
                                .toColor()),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () {
                  final value =
                      RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(controller.text)
                          ? controller.text
                          : toHex(hsv.toColor());
                  onChanged(value);
                  Navigator.pop(dialogContext);
                },
                child: const Text('اختيار')),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: Text('جارٍ تحميل تصميم المتجر...',
              style: TextStyle(color: AppColors.ash)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تصميم المتجر',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text('خصّص ألوان المتجر وخلفيته وشعاره وطريقة عرض المنتجات',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 720;
            final form = _buildForm(context);
            final preview = _buildPreview(context);
            if (wide) {
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: form),
                    const SizedBox(width: 24),
                    Expanded(child: preview),
                  ]);
            }
            return Column(
                children: [form, const SizedBox(height: 24), preview]);
          }),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: AppColors.ashLight),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _storeNameController,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.sentences,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
                labelText:
                    '\u0627\u0633\u0645 \u0627\u0644\u0645\u062a\u062c\u0631'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _storeDescriptionController,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText:
                    '\u0646\u0628\u0630\u0629 \u0627\u0644\u0645\u062a\u062c\u0631'),
          ),
          const SizedBox(height: 16),
          const Text('عناصر الهوية على واجهة المتجر',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _addDesignElement('text'),
              icon: const Icon(Icons.title_rounded),
              label: const Text('إضافة نص'),
            ),
            OutlinedButton.icon(
              onPressed: () => _addDesignElement('button'),
              icon: const Icon(Icons.smart_button_outlined),
              label: const Text('إضافة زر'),
            ),
            OutlinedButton.icon(
              onPressed: () => _addDesignElement('shape'),
              icon: const Icon(Icons.crop_square_rounded),
              label: const Text('إضافة شكل'),
            ),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _addImageElement,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('إضافة صورة'),
            ),
          ]),
          if (_selectedElementId != null) _buildSelectedElementEditor(context),
          const SizedBox(height: 12),
          _colorField(context, 'اللون الأساسي', _theme.primaryColor,
              (v) => setState(() => _theme = _theme.copyWith(primaryColor: v))),
          _colorField(
              context,
              'اللون الثانوي',
              _theme.secondaryColor,
              (v) =>
                  setState(() => _theme = _theme.copyWith(secondaryColor: v))),
          _colorField(
              context,
              'لون الخلفية',
              _theme.backgroundColor,
              (v) =>
                  setState(() => _theme = _theme.copyWith(backgroundColor: v))),
          _colorField(context, 'لون النص', _theme.textColor,
              (v) => setState(() => _theme = _theme.copyWith(textColor: v))),
          _colorField(context, 'لون التمييز', _theme.accentColor,
              (v) => setState(() => _theme = _theme.copyWith(accentColor: v))),
          _colorField(context, 'لون البطاقات', _theme.cardColor,
              (v) => setState(() => _theme = _theme.copyWith(cardColor: v))),
          _colorField(
              context,
              'بداية تدرج الخلفية',
              _theme.backgroundGradientStart,
              (v) => setState(
                  () => _theme = _theme.copyWith(backgroundGradientStart: v))),
          _colorField(
              context,
              'نهاية تدرج الخلفية',
              _theme.backgroundGradientEnd,
              (v) => setState(
                  () => _theme = _theme.copyWith(backgroundGradientEnd: v))),
          DropdownButtonFormField<String>(
            initialValue: _theme.backgroundStyle,
            decoration: const InputDecoration(labelText: 'طريقة الخلفية'),
            items: const [
              DropdownMenuItem(value: 'solid', child: Text('لون عادي')),
              DropdownMenuItem(value: 'gradient', child: Text('تدرج لوني')),
              DropdownMenuItem(value: 'image', child: Text('صورة كاملة')),
              DropdownMenuItem(value: 'blend', child: Text('صورة مع تدرج')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(
                    () => _theme = _theme.copyWith(backgroundStyle: value));
              }
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _theme.backgroundImageFit,
            decoration: const InputDecoration(
                labelText:
                    '\u0645\u0644\u0627\u0621\u0645\u0629 \u0635\u0648\u0631\u0629 \u0627\u0644\u062e\u0644\u0641\u064a\u0629'),
            items: const [
              DropdownMenuItem(
                  value: 'contain',
                  child: Text(
                      '\u0625\u0638\u0647\u0627\u0631 \u0627\u0644\u0635\u0648\u0631\u0629 \u0643\u0627\u0645\u0644\u0629')),
              DropdownMenuItem(
                  value: 'cover',
                  child: Text(
                      '\u0645\u0644\u0621 \u0627\u0644\u062e\u0644\u0641\u064a\u0629 \u0648\u0642\u0635 \u0627\u0644\u0623\u0637\u0631\u0627\u0641')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(
                    () => _theme = _theme.copyWith(backgroundImageFit: value));
              }
            },
          ),
          const SizedBox(height: 12),
          const Text('مكان أزرار التصفية والتصنيفات عند الزبون'),
          const Text('يمين / يسار'),
          Slider(
            value: _theme.controlsX.clamp(0, 1).toDouble(),
            onChanged: (value) =>
                setState(() => _theme = _theme.copyWith(controlsX: value)),
          ),
          const Text('فوق / تحت'),
          Slider(
            value: _theme.controlsY.clamp(0, 1).toDouble(),
            onChanged: (value) =>
                setState(() => _theme = _theme.copyWith(controlsY: value)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _theme.productImageShape,
            decoration: const InputDecoration(labelText: 'شكل صور المنتجات'),
            items: const [
              DropdownMenuItem(
                  value: 'rounded', child: Text('مستطيل بزوايا دائرية')),
              DropdownMenuItem(value: 'square', child: Text('مربع')),
              DropdownMenuItem(value: 'circle', child: Text('دائري')),
              DropdownMenuItem(value: 'portrait', child: Text('مستطيل طولي')),
              DropdownMenuItem(value: 'triangle', child: Text('مثلث')),
              DropdownMenuItem(value: 'diamond', child: Text('معيّن')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(
                    () => _theme = _theme.copyWith(productImageShape: value));
              }
            },
          ),
          const SizedBox(height: 8),
          Text('حجم صورة المنتج: ${(_theme.productImageScale * 100).round()}%'),
          Slider(
            min: .5,
            max: 1,
            divisions: 10,
            value: _theme.productImageScale.clamp(.5, 1).toDouble(),
            onChanged: (value) => setState(
                () => _theme = _theme.copyWith(productImageScale: value)),
          ),
          const SizedBox(height: 12),
          const Text('تنسيق المتجر من الداخل',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _theme.productLayout,
            decoration: const InputDecoration(labelText: 'طريقة عرض المنتجات'),
            items: const [
              DropdownMenuItem(value: 'grid', child: Text('شبكة')),
              DropdownMenuItem(value: 'list', child: Text('قائمة')),
            ],
            onChanged: (value) {
              if (value != null)
                setState(() => _theme = _theme.copyWith(productLayout: value));
            },
          ),
          DropdownButtonFormField<int>(
            initialValue: _theme.productColumns.clamp(1, 4),
            decoration:
                const InputDecoration(labelText: 'عدد المنتجات في الصف'),
            items: const [1, 2, 3, 4]
                .map((value) =>
                    DropdownMenuItem(value: value, child: Text('$value')))
                .toList(),
            onChanged: (value) {
              if (value != null)
                setState(() => _theme = _theme.copyWith(productColumns: value));
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _theme.categoryStyle,
            decoration: const InputDecoration(labelText: 'شكل الفئات'),
            items: const [
              DropdownMenuItem(value: 'chips', child: Text('أزرار')),
              DropdownMenuItem(value: 'cards', child: Text('بطاقات')),
            ],
            onChanged: (value) {
              if (value != null)
                setState(() => _theme = _theme.copyWith(categoryStyle: value));
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _theme.productCardStyle,
            decoration: const InputDecoration(labelText: 'تصميم بطاقة المنتج'),
            items: const [
              DropdownMenuItem(value: 'classic', child: Text('كلاسيكي')),
              DropdownMenuItem(value: 'minimal', child: Text('بسيط')),
              DropdownMenuItem(value: 'poster', child: Text('صورة بارزة')),
            ],
            onChanged: (value) {
              if (value != null)
                setState(
                    () => _theme = _theme.copyWith(productCardStyle: value));
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('إظهار خلفية بطاقة المنتج'),
            value: _theme.showProductCard,
            onChanged: (value) => setState(
                () => _theme = _theme.copyWith(showProductCard: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إظهار وصف المنتج في المتجر'),
            value: _theme.showProductDescriptions,
            onChanged: (value) => setState(
                () => _theme = _theme.copyWith(showProductDescriptions: value)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _theme.storeCategory,
            decoration: const InputDecoration(labelText: 'تصنيف المتجر'),
            items: const [
              DropdownMenuItem(value: 'clothing', child: Text('ملابس')),
              DropdownMenuItem(value: 'shoes', child: Text('أحذية')),
              DropdownMenuItem(value: 'pharmacy', child: Text('صيدلية')),
              DropdownMenuItem(value: 'electronics', child: Text('إلكترونيات')),
              DropdownMenuItem(value: 'home', child: Text('منزل')),
              DropdownMenuItem(value: 'beauty', child: Text('جمال وعناية')),
              DropdownMenuItem(value: 'grocery', child: Text('مواد غذائية')),
              DropdownMenuItem(value: 'general', child: Text('متنوع')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _theme = _theme.copyWith(storeCategory: value));
              }
            },
          ),
          const SizedBox(height: 8),
          Text('شعار المتجر',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 6),
          TextField(
              controller: _logoController,
              decoration: const InputDecoration(hintText: 'https://...')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploading ? null : () => _pickAndUpload(logo: true),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('اختيار الشعار من الاستديو'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _theme.logoPosition,
            decoration: const InputDecoration(labelText: 'مكان الشعار'),
            items: const [
              DropdownMenuItem(value: 'topRight', child: Text('أعلى اليمين')),
              DropdownMenuItem(value: 'topCenter', child: Text('أعلى المنتصف')),
              DropdownMenuItem(value: 'topLeft', child: Text('أعلى اليسار')),
              DropdownMenuItem(
                  value: 'centerRight', child: Text('منتصف اليمين')),
              DropdownMenuItem(value: 'center', child: Text('المنتصف')),
              DropdownMenuItem(
                  value: 'centerLeft', child: Text('منتصف اليسار')),
              DropdownMenuItem(
                  value: 'bottomRight', child: Text('أسفل اليمين')),
              DropdownMenuItem(
                  value: 'bottomCenter', child: Text('أسفل المنتصف')),
              DropdownMenuItem(value: 'bottomLeft', child: Text('أسفل اليسار')),
            ],
            onChanged: (value) {
              if (value != null)
                setState(() => _theme = _theme.copyWith(logoPosition: value));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _theme.logoShape,
            decoration: const InputDecoration(
                labelText:
                    '\u0634\u0643\u0644 \u0625\u0637\u0627\u0631 \u0627\u0644\u0634\u0639\u0627\u0631'),
            items: const [
              DropdownMenuItem(
                  value: 'circle',
                  child: Text('\u062f\u0627\u0626\u0631\u0629')),
              DropdownMenuItem(
                  value: 'square', child: Text('\u0645\u0631\u0628\u0639')),
              DropdownMenuItem(
                  value: 'rounded',
                  child: Text(
                      '\u0645\u0631\u0628\u0639 \u0628\u062d\u0648\u0627\u0641 \u0646\u0627\u0639\u0645\u0629')),
              DropdownMenuItem(
                  value: 'triangle', child: Text('\u0645\u062b\u0644\u062b')),
              DropdownMenuItem(
                  value: 'diamond', child: Text('\u0645\u0639\u064a\u0646')),
              DropdownMenuItem(
                  value: 'hexagon',
                  child: Text('\u0633\u062f\u0627\u0633\u064a')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _theme = _theme.copyWith(logoShape: value));
              }
            },
          ),
          const SizedBox(height: 12),
          Text('خلفية المتجر',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 6),
          TextField(
              controller: _bannerController,
              decoration: const InputDecoration(hintText: 'https://...')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploading ? null : () => _pickAndUpload(logo: false),
            icon: const Icon(Icons.wallpaper_outlined),
            label: const Text('اختيار خلفية من الاستديو'),
          ),
          const SizedBox(height: 8),
          Text(
              'تعتيم الخلفية: ${(_theme.backgroundOverlayOpacity * 100).round()}٪'),
          Slider(
            value: _theme.backgroundOverlayOpacity.clamp(0, .85).toDouble(),
            min: 0,
            max: .85,
            divisions: 17,
            label: '${(_theme.backgroundOverlayOpacity * 100).round()}٪',
            onChanged: (value) => setState(() =>
                _theme = _theme.copyWith(backgroundOverlayOpacity: value)),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving
                ? 'جارٍ الحفظ...'
                : (_saved ? 'تم الحفظ ✓' : 'حفظ التغييرات')),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedElementEditor(BuildContext context) {
    final selected = _designElements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['id'] == _selectedElementId,
          orElse: () => null,
        );
    if (selected == null) return const SizedBox.shrink();
    final id = _selectedElementId!;
    final isShape = selected['type'] == 'shape';
    final isImage = selected['type'] == 'image';
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(
                child: Text('تعديل العنصر المختار',
                    style: TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: 'حذف العنصر',
              onPressed: () => setState(() {
                _designElements.removeWhere((element) => element['id'] == id);
                _selectedElementId = null;
              }),
              icon: const Icon(Icons.delete_outline, color: AppColors.rust),
            ),
          ]),
          if (!isShape && !isImage)
            TextFormField(
              key: ValueKey('element-text-$id'),
              initialValue: selected['text'] as String? ?? '',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'النص'),
              onChanged: (value) => _updateDesignElement(id, {'text': value}),
            ),
          const SizedBox(height: 10),
          if (!isImage)
            Row(children: [
              const Expanded(child: Text('لون العنصر')),
              GestureDetector(
                onTap: () => _showAdvancedColorPicker(
                  selected['color'] as String? ?? _theme.primaryColor,
                  (color) => _updateDesignElement(id, {'color': color}),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        _hexToColor(selected['color'] as String? ?? '#4B1724'),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.ashLight),
                  ),
                ),
              ),
            ]),
          const SizedBox(height: 8),
          Text(
              'العرض: ${((selected['width'] as num).toDouble() * 100).round()}%'),
          Slider(
            value: (selected['width'] as num)
                .toDouble()
                .clamp(.12, 1 - (selected['x'] as num).toDouble()),
            min: .12,
            max: math.max(.12, 1 - (selected['x'] as num).toDouble()),
            onChanged: (value) => _updateDesignElement(id, {'width': value}),
          ),
          Text(
              'الارتفاع: ${((selected['height'] as num).toDouble() * 100).round()}%'),
          Slider(
            value: (selected['height'] as num)
                .toDouble()
                .clamp(.08, 1 - (selected['y'] as num).toDouble()),
            min: .08,
            max: math.max(.08, 1 - (selected['y'] as num).toDouble()),
            onChanged: (value) => _updateDesignElement(id, {'height': value}),
          ),
          if (!isShape && !isImage) ...[
            const SizedBox(height: 8),
            Text('حجم النص: ${(selected['font_size'] as num? ?? 17).round()}'),
            Slider(
              value: (selected['font_size'] as num? ?? 17)
                  .toDouble()
                  .clamp(10, 40),
              min: 10,
              max: 40,
              onChanged: (value) =>
                  _updateDesignElement(id, {'font_size': value}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('معاينة المتجر',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 10),
        Container(
          height: 380,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.ashLight),
              color: _hexToColor(_theme.backgroundColor),
              gradient: _theme.backgroundStyle == 'gradient' ||
                      _theme.backgroundStyle == 'blend'
                  ? LinearGradient(colors: [
                      _hexToColor(_theme.backgroundGradientStart),
                      _hexToColor(_theme.backgroundGradientEnd),
                    ])
                  : null,
              image: (_theme.backgroundStyle == 'image' ||
                          _theme.backgroundStyle == 'blend') &&
                      _mediaUrl(_theme.backgroundImageUrl ??
                              _bannerController.text) !=
                          null
                  ? DecorationImage(
                      image: NetworkImage(_mediaUrl(_theme.backgroundImageUrl ??
                          _bannerController.text)!),
                      fit: _theme.backgroundImageFit == 'contain'
                          ? BoxFit.contain
                          : BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                          _hexToColor(_theme.backgroundColor).withValues(
                              alpha: _theme.backgroundOverlayOpacity),
                          BlendMode.srcOver),
                    )
                  : null),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: LayoutBuilder(builder: (context, canvas) {
                  return Stack(fit: StackFit.expand, children: [
                    if (_mediaUrl(_theme.backgroundImageUrl) != null)
                      Image.network(_mediaUrl(_theme.backgroundImageUrl)!,
                          fit: _theme.backgroundImageFit == 'contain'
                              ? BoxFit.contain
                              : BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    Container(
                        color: _hexToColor(_theme.backgroundColor).withValues(
                            alpha: _theme.backgroundOverlayOpacity)),
                    Align(
                      alignment: switch (_theme.logoPosition) {
                        'topLeft' => Alignment.topLeft,
                        'topCenter' => Alignment.topCenter,
                        'centerLeft' => Alignment.centerLeft,
                        'center' => Alignment.center,
                        'centerRight' => Alignment.centerRight,
                        'bottomLeft' => Alignment.bottomLeft,
                        'bottomCenter' => Alignment.bottomCenter,
                        'bottomRight' => Alignment.bottomRight,
                        _ => Alignment.topRight,
                      },
                      child: _mediaUrl(_logoController.text) == null
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Icon(Icons.storefront, size: 40))
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: ClipPath(
                                clipper: _LogoShapeClipper(_theme.logoShape),
                                child: Image.network(
                                  _mediaUrl(_logoController.text)!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                ),
                              )),
                    ),
                    for (final element in _designElements)
                      Positioned(
                        left:
                            (element['x'] as num).toDouble() * canvas.maxWidth,
                        top:
                            (element['y'] as num).toDouble() * canvas.maxHeight,
                        width: (element['width'] as num).toDouble() *
                            canvas.maxWidth,
                        height: (element['height'] as num).toDouble() *
                            canvas.maxHeight,
                        child: GestureDetector(
                          onTap: () => setState(() =>
                              _selectedElementId = element['id'] as String),
                          onPanUpdate: (details) => _moveDesignElement(
                            element['id'] as String,
                            details.delta.dx / canvas.maxWidth,
                            details.delta.dy / canvas.maxHeight,
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: element['type'] == 'text'
                                  ? Colors.transparent
                                  : _hexToColor(element['color'] as String)
                                      .withValues(
                                          alpha: element['type'] == 'shape'
                                              ? .42
                                              : 1),
                              borderRadius: BorderRadius.circular(
                                  (element['radius'] as num).toDouble()),
                              border: _selectedElementId == element['id']
                                  ? Border.all(color: Colors.blue, width: 2)
                                  : null,
                            ),
                            child: element['type'] == 'shape'
                                ? null
                                : element['type'] == 'image'
                                    ? Image.network(
                                        _mediaUrl(element['image_url']
                                                as String?) ??
                                            element['image_url'] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                Icons.broken_image_outlined),
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          element['text'] as String? ?? '',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: element['type'] == 'button'
                                                ? Colors.white
                                                : _hexToColor(
                                                    element['color'] as String),
                                            fontSize:
                                                (element['font_size'] as num)
                                                    .toDouble(),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                            height: 78,
                            color: _hexToColor(_theme.primaryColor)
                                .withValues(alpha: .88),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _storeNameController.text.trim().isEmpty
                                      ? 'متجري'
                                      : _storeNameController.text.trim(),
                                  style: TextStyle(
                                      color: _hexToColor(_theme.secondaryColor),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19),
                                ),
                                if (_storeDescriptionController.text
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    _storeDescriptionController.text.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _hexToColor(_theme.secondaryColor)
                                          .withValues(alpha: .82),
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ))),
                  ]);
                }),
              ),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -48),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _hexToColor(_theme.secondaryColor),
                                border: Border.all(
                                    color: _hexToColor(_theme.backgroundColor),
                                    width: 4)),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('اسم المنتج',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: _hexToColor(_theme.textColor))),
                              const SizedBox(height: 4),
                              Text('وصف مختصر للمنتج وسعره',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: _hexToColor(_theme.textColor)
                                          .withValues(alpha: 0.7))),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                    color: _hexToColor(_theme.primaryColor),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text('أضف إلى السلة',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _hexToColor(
                                            _theme.secondaryColor))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final label in ['الكل', 'جديد', 'الأكثر طلباً'])
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: _theme.categoryStyle == 'cards'
                                    ? _hexToColor(_theme.cardColor)
                                    : _hexToColor(_theme.accentColor),
                                borderRadius: BorderRadius.circular(
                                    _theme.categoryStyle == 'cards' ? 10 : 24),
                                border: Border.all(
                                    color: _hexToColor(_theme.accentColor)),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: _theme.categoryStyle == 'cards'
                                          ? _hexToColor(_theme.textColor)
                                          : Colors.white)),
                            ),
                        ]),
                        const SizedBox(height: 12),
                        Text(
                            _theme.productLayout == 'list'
                                ? 'عرض المنتجات: قائمة'
                                : 'عرض المنتجات: ${_theme.productColumns} في الصف',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 7),
                        LayoutBuilder(builder: (context, constraints) {
                          final count = _theme.productLayout == 'list'
                              ? 1
                              : _theme.productColumns.clamp(1, 4);
                          final width =
                              (constraints.maxWidth - (count - 1) * 8) / count;
                          return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(
                                  3,
                                  (index) => Container(
                                        width: width,
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                            color: _theme.showProductCard
                                                ? _hexToColor(_theme.cardColor)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                                _theme.showProductCard
                                                    ? (_theme.productCardStyle ==
                                                            'minimal'
                                                        ? 4
                                                        : 11)
                                                    : 0),
                                            border: _theme.showProductCard
                                                ? Border.all(
                                                    color: _hexToColor(
                                                            _theme.accentColor)
                                                        .withValues(alpha: .35))
                                                : null),
                                        child: _theme.productLayout == 'list'
                                            ? Row(children: [
                                                SizedBox(
                                                  width: 34 *
                                                      _theme.productImageScale,
                                                  height: 34 *
                                                      _theme.productImageScale,
                                                  child: ClipPath(
                                                    clipper: _PreviewProductShape(
                                                        _theme
                                                            .productImageShape),
                                                    child: Container(
                                                        color: _hexToColor(_theme
                                                            .backgroundColor)),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Expanded(
                                                    child: Text('منتج المتجر',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontSize: 9)))
                                              ])
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                    AspectRatio(
                                                      aspectRatio: 1,
                                                      child: LayoutBuilder(
                                                          builder: (context,
                                                              constraints) {
                                                        final side = constraints
                                                                .maxWidth *
                                                            _theme
                                                                .productImageScale;
                                                        return Container(
                                                          color: _hexToColor(
                                                              _theme.cardColor),
                                                          alignment:
                                                              Alignment.center,
                                                          child: SizedBox(
                                                            width: side,
                                                            height: side,
                                                            child: ClipPath(
                                                              clipper:
                                                                  _PreviewProductShape(
                                                                      _theme
                                                                          .productImageShape),
                                                              child: Container(
                                                                  color: _hexToColor(
                                                                      _theme
                                                                          .backgroundColor)),
                                                            ),
                                                          ),
                                                        );
                                                      }),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    const Text('منتج المتجر',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: TextStyle(
                                                            fontSize: 9)),
                                                    if (_theme
                                                        .showProductDescriptions)
                                                      const Text(
                                                          'وصف مختصر للمنتج',
                                                          maxLines: 1,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                              fontSize: 7)),
                                                  ]),
                                      )));
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoShapeClipper extends CustomClipper<Path> {
  const _LogoShapeClipper(this.shape);
  final String shape;

  @override
  Path getClip(Size size) {
    if (shape == 'circle') return Path()..addOval(Offset.zero & size);
    if (shape == 'triangle') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    if (shape == 'diamond') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    if (shape == 'hexagon') {
      return Path()
        ..moveTo(size.width * .25, 0)
        ..lineTo(size.width * .75, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width * .75, size.height)
        ..lineTo(size.width * .25, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    if (shape == 'rounded') {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size, const Radius.circular(12)));
    }
    return Path()..addRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant _LogoShapeClipper oldClipper) =>
      oldClipper.shape != shape;
}

class _PreviewProductShape extends CustomClipper<Path> {
  const _PreviewProductShape(this.shape);
  final String shape;

  @override
  Path getClip(Size size) {
    if (shape == 'circle') return Path()..addOval(Offset.zero & size);
    if (shape == 'triangle') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    if (shape == 'diamond') {
      return Path()
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(0, size.height / 2)
        ..close();
    }
    if (shape == 'rounded') {
      return Path()
        ..addRRect(RRect.fromRectAndRadius(
            Offset.zero & size, const Radius.circular(8)));
    }
    return Path()..addRect(Offset.zero & size);
  }

  @override
  bool shouldReclip(covariant _PreviewProductShape oldClipper) =>
      oldClipper.shape != shape;
}
