import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/maqha_design_system.dart';
import '../../rendering/wood_table.dart';

/// Store-compliance screen ("حول المقهى والخصوصية والشروط") providing:
/// 1. App version & heritage Café identity (`المقهى v1.0.0`).
/// 2. Explicit Virtual Currency / Non-Gambling declaration required by Google
///    Play & Apple App Store reviewers (`دينار المقهى` has zero cash value).
/// 3. Privacy, permissions, and in-app account deletion rights disclosure.
class AboutLegalScreen extends StatelessWidget {
  const AboutLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAr ? 'حول المقهى والخصوصية' : 'About & Privacy Policy',
          style: const TextStyle(fontSize: 17),
        ),
      ),
      body: WoodTable(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _InfoSection(
                icon: Icons.local_cafe_rounded,
                title: isAr ? 'المقهى — الإصدار 1.0.0' : 'Al-Maqha — v1.0.0',
                body: isAr
                    ? 'منصة اجتماعية وترفيهية تجمع أصالة المقاهي التراثية وألعاب الطاولة الجماعية (بدءاً من الدومينو العراقي) مع دعم اللعب الفردي ضد الذكاء الاصطناعي، اللعب المحلي القريب بدون إنترنت، والمنافسات الأونلاين.'
                    : 'An authentic heritage Café social board-game platform featuring Iraqi Domino across single-player AI, offline local P2P, and online rooms & tournaments.',
              ),
              _InfoSection(
                icon: Icons.verified_outlined,
                title: isAr
                    ? 'إقرار العملة الافتراضية واللعب النزيه'
                    : 'Virtual Currency & Fair Play Notice',
                body: isAr
                    ? 'عملة "دينار المقهى" وكافة المقتنيات داخل التطبيق هي عناصر ترفيهية افتراضية بالكامل للاستخدام داخل اللعبة فقط. لا يمكن بيعها أو تحويلها أو سحبها مقابل أموال حقيقية أو جوائز نقدية بأي شكل من الأشكال، ولا يتضمن التطبيق أي مراهنات مالية حقيقية.'
                    : '"Al-Maqha Dinars" and all shop items are strictly virtual entertainment items with zero real-world monetary value. They cannot be cashed out, redeemed, or exchanged for real money or prizes.',
              ),
              _InfoSection(
                icon: Icons.privacy_tip_outlined,
                title: isAr
                    ? 'سياسة الخصوصية وصلاحيات الجهاز'
                    : 'Privacy Policy & Device Permissions',
                body: isAr
                    ? '• البلوتوث والشبكة المحلية (Wi-Fi): تُستخدم حصراً لاكتشاف الغرف القريبة عند اختيار "اللعب المحلي" مع الأصدقاء دون جمع أو تخزين موقعك الجغرافي.\n'
                      '• بيانات الحساب: يُحفظ اسم العرض والبريد الإلكتروني والإحصائيات لمزامنة تقدمك وترتيبك على السيرفر.\n'
                      '• حذف الحساب والبيانات: يمكنك في أي وقت حذف حسابك وجميع بياناتك نهائياً وبضغطة واحدة من شاشة الإعدادات.'
                    : '• Bluetooth & Local Network: used strictly to connect nearby devices during Local Play without tracking location.\n'
                      '• Account Data: display name, email, and game stats are stored solely to sync your profile and leaderboard rank.\n'
                      '• Account Deletion: you can permanently delete your account and all associated server data anytime directly from Settings.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MaqhaColors.cardCharcoal,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MaqhaColors.borderSubtle),
        boxShadow: MaqhaShadows.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: AppColors.ivory.withValues(alpha: 0.86),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
