import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../pages/subscription_page.dart';
import '../services/entitlement_service.dart';

/// Kiểm tra quyền dùng một tính năng AI cao cấp ('plan' | 'food').
/// Trả về true nếu được phép; nếu không, mở sheet nâng cấp và trả về false.
Future<bool> ensurePaywall(BuildContext context, String feature) async {
  final ent = context.read<EntitlementProvider>();
  if (ent.canUse(feature)) return true;
  await showUpgradeSheet(context);
  return false;
}

/// Mở bottom sheet mời nâng cấp; nút "Xem gói" điều hướng tới [SubscriptionPage]
/// rồi làm mới entitlement khi quay lại.
Future<void> showUpgradeSheet(BuildContext context, {String? message}) async {
  final theme = Theme.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.workspace_premium_rounded,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                sheetContext.translate('paywall_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message ?? sheetContext.translate('paywall_message'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context)
                      .push(MaterialPageRoute(
                        builder: (_) => const SubscriptionPage(),
                      ))
                      .then((_) {
                    if (context.mounted) {
                      context.read<EntitlementProvider>().refresh();
                    }
                  });
                },
                child: Text(sheetContext.translate('paywall_view_plans')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(sheetContext.translate('paywall_later')),
              ),
            ],
          ),
        ),
      );
    },
  );
}
