/// Physical or logical medium used to connect players into a match session.
///
/// All three local channels ([wifiOffline], [bluetooth], [localWifi]) and both
/// Phase 7 online channels ([onlineRandom], [onlineRoom]) run over the exact
/// same wire protocol, seat mapper, and [GameDataCenter] identity.
enum SessionChannel {
  /// Single-player offline against AI personas.
  aiOffline('ai_offline', isLocalMultiplayer: false, isOnline: false),

  /// Direct peer-to-peer Wi-Fi without internet (Wi-Fi Direct / Offline Hotspot).
  wifiOffline('wifi_offline', isLocalMultiplayer: true, isOnline: false),

  /// Direct peer-to-peer Bluetooth (RFCOMM on Android / Multipeer on iOS).
  bluetooth('bluetooth', isLocalMultiplayer: true, isOnline: false),

  /// Shared local Wi-Fi router / LAN.
  localWifi('local_wifi', isLocalMultiplayer: true, isOnline: false),

  /// Phase 7: Public online matchmaking with bot-takeover on disconnect.
  onlineRandom('online_random', isLocalMultiplayer: false, isOnline: true),

  /// Phase 7: Private online room with room code & seat selection.
  onlineRoom('online_room', isLocalMultiplayer: false, isOnline: true);

  const SessionChannel(
    this.id, {
    required this.isLocalMultiplayer,
    required this.isOnline,
  });

  final String id;
  final bool isLocalMultiplayer;
  final bool isOnline;

  /// The three Local Multiplayer options required in Phase 6.
  static const List<SessionChannel> localChannels = [
    SessionChannel.wifiOffline,
    SessionChannel.bluetooth,
    SessionChannel.localWifi,
  ];

  String label(bool isAr) => switch (this) {
    SessionChannel.aiOffline => isAr ? 'ضد الكمبيوتر' : 'Play vs AI',
    SessionChannel.wifiOffline =>
      isAr ? 'واي فاي بدون إنترنت' : 'Offline Wi-Fi (Direct / Hotspot)',
    SessionChannel.bluetooth => isAr ? 'بلوتوث' : 'Bluetooth',
    SessionChannel.localWifi => isAr ? 'شبكة الواي فاي (Wi-Fi)' : 'Local Wi-Fi',
    SessionChannel.onlineRandom =>
      isAr ? 'لعب عشوائي (أونلاين)' : 'Random Online',
    SessionChannel.onlineRoom => isAr ? 'غرفة أصدقاء' : 'Friends Room',
  };

  String subtitle(bool isAr) => switch (this) {
    SessionChannel.aiOffline =>
      isAr ? 'أوفلاين ضد شخصيات الذكاء الاصطناعي' : 'Offline vs AI personas',
    SessionChannel.wifiOffline => isAr
        ? 'اتصال مباشر أو نقطة اتصال هاتف بدون رصيد إنترنت'
        : 'Direct P2P or phone hotspot with zero internet',
    SessionChannel.bluetooth => isAr
        ? 'ربط مباشر عبر البلوتوث مع الأصدقاء القريبين'
        : 'Direct Bluetooth link with nearby friends',
    SessionChannel.localWifi => isAr
        ? 'اكتشاف تلقائي فوري على نفس شبكة الواي فاي'
        : 'Instant auto-discovery on the same Wi-Fi network',
    SessionChannel.onlineRandom =>
      isAr ? 'بحث تلقائي عبر السيرفر' : 'Server matchmaking',
    SessionChannel.onlineRoom =>
      isAr ? 'غرفة خاصة بكود ودعوات' : 'Private room with code',
  };

  static SessionChannel byId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return SessionChannel.localWifi;
  }
}
