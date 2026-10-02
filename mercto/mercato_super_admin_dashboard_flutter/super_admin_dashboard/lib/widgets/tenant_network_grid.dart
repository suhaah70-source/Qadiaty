import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/models.dart';

const _statusColor = {
  'ACTIVE': AppColors.jade,
  'PENDING': AppColors.brass,
  'SUSPENDED': AppColors.rust,
  'CLOSED': AppColors.ash,
};

/// شبكة توضح توزيع المتاجر وحالتها ضمن المنصة.
class TenantNetworkGrid extends StatelessWidget {
  final List<Tenant> tenants;
  const TenantNetworkGrid({super.key, required this.tenants});

  @override
  Widget build(BuildContext context) {
    final shown = tenants.take(40).toList();
    final overflow = tenants.length - shown.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.ink, borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          const Positioned.fill(child: HeritagePattern(opacity: 0.05)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('شبكة المتاجر',
                            style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 2,
                                color: Colors.white.withValues(alpha: 0.5))),
                        const SizedBox(height: 4),
                        Text('توزيع المتاجر · ${tenants.length} متجر',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  Wrap(spacing: 12, children: [
                    _legend('نشط', AppColors.jade),
                    _legend('قيد المراجعة', AppColors.brass),
                    _legend('موقوف', AppColors.rust),
                  ]),
                ],
              ),
              const SizedBox(height: 16),
              if (shown.isEmpty)
                Text('لا توجد متاجر لعرضها حاليًا.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13))
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ...shown.map((t) => Tooltip(
                          message: '${t.name} — ${t.code}',
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      _statusColor[t.status] ?? AppColors.ash,
                                  width: 2),
                            ),
                            child: Text(
                                t.name.isNotEmpty
                                    ? t.name.substring(0, 1)
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        )),
                    if (overflow > 0)
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        child: Text('+$overflow',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.5))),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6))),
    ]);
  }
}
