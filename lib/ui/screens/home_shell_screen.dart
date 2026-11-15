import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Temporary home screen. It only proves that the app shell works
/// (theme, Arabic RTL, localization). It will be replaced in Phase 2.
class HomeShellScreen extends StatelessWidget {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Gives access to the translated strings for the current language.
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.casino_outlined, size: 72, color: AppColors.gold),
            const SizedBox(height: 16),
            Text(
              l10n.phaseOneReady,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.ivory,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}