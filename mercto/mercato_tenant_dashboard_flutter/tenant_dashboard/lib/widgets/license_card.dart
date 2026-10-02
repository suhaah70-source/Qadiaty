import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/models.dart';

/// بطاقة تعرض بيانات المتجر والخطة الحالية.
class LicenseCard extends StatelessWidget {
  final Tenant tenant;
  const LicenseCard({super.key, required this.tenant});

  @override
  Widget build(BuildContext context) {
    final isActive = tenant.status == 'ACTIVE';
    final statusColor = isActive ? AppColors.jade : AppColors.rust;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: AppColors.ink, borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          const Positioned.fill(child: HeritagePattern(opacity: 0.05)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بيانات المتجر',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tenant.name,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('رمز المتجر: ${tenant.code}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.7))),
                          const SizedBox(width: 10),
                          Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white24)),
                          const SizedBox(width: 10),
                          Text('الرابط: /${tenant.slug}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.7))),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withValues(alpha: 0.1),
                    border: Border.all(color: statusColor, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    kTenantStatusLabels[tenant.status] ?? tenant.status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
