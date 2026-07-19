import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';

/// Displays the password requirements and their current completion state.
class PasswordRequirementsChecklist extends StatelessWidget {
  final String password;

  const PasswordRequirementsChecklist({super.key, required this.password});

  static bool hasMinimumLength(String password) => password.length >= 6;

  static bool hasUppercase(String password) =>
      RegExp(r'[A-Z]').hasMatch(password);

  static bool hasLowercase(String password) =>
      RegExp(r'[a-z]').hasMatch(password);

  static bool hasNumber(String password) => RegExp(r'[0-9]').hasMatch(password);

  static bool isValid(String password) =>
      hasMinimumLength(password) &&
      hasUppercase(password) &&
      hasLowercase(password) &&
      hasNumber(password);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final requirements = [
      (
        key: 'password-requirement-length',
        label: context.translate('password_requirement_length'),
        isMet: hasMinimumLength(password),
      ),
      (
        key: 'password-requirement-uppercase',
        label: context.translate('password_requirement_uppercase'),
        isMet: hasUppercase(password),
      ),
      (
        key: 'password-requirement-lowercase',
        label: context.translate('password_requirement_lowercase'),
        isMet: hasLowercase(password),
      ),
      (
        key: 'password-requirement-number',
        label: context.translate('password_requirement_number'),
        isMet: hasNumber(password),
      ),
    ];

    return Semantics(
      container: true,
      label: context.translate('password_requirements_title'),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.translate('password_requirements_title'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...requirements.map(
                (requirement) => _PasswordRequirementItem(
                  key: Key(requirement.key),
                  label: requirement.label,
                  isMet: requirement.isMet,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirementItem extends StatelessWidget {
  final String label;
  final bool isMet;

  const _PasswordRequirementItem({
    super.key,
    required this.label,
    required this.isMet,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isMet ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        checked: isMet,
        child: Row(
          children: [
            Icon(
              isMet
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: color,
              size: 17,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@Preview(
  name: 'Partial password',
  group: 'Authentication',
  size: Size(420, 260),
)
Widget passwordRequirementsChecklistPreview() {
  return MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('vi')],
    home: const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24),
        child: PasswordRequirementsChecklist(password: 'Runny1'),
      ),
    ),
  );
}
