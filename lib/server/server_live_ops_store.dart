import 'dart:convert';
import 'dart:io';

import '../data/cafe_events_and_tournaments.dart';
import '../data/cafe_progression.dart';

/// Server-side persistent store for Dynamic Events (Fixed Recurring, Seasonal
/// Ramadan/Eid, and Custom Sponsored Image Events) and Tournament Tiers.
/// Pure Dart.
class ServerLiveOpsStore {
  ServerLiveOpsStore({this.storageFilePath}) {
    _seedDefaults();
    _loadFromDisk();
  }

  final String? storageFilePath;

  final List<CafeEventDefinition> _events = [];
  final List<CafeTournamentTier> _tournaments = [];

  List<CafeEventDefinition> get allEvents => List.unmodifiable(_events);
  List<CafeTournamentTier> get allTournaments =>
      List.unmodifiable(_tournaments);

  List<CafeEventDefinition> activeEvents([String? dateKey]) {
    final key = dateKey ?? CafeProgression.todayDateKey();
    return [
      for (final e in _events)
        if (e.isActiveOn(key)) e,
    ];
  }

  List<CafeTournamentTier> get activeTournaments => [
    for (final t in _tournaments)
      if (t.enabled) t,
  ];

  void upsertEvent(CafeEventDefinition event) {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      _events[idx] = event;
    } else {
      _events.insert(0, event);
    }
    _saveToDisk();
  }

  bool deleteEvent(String id) {
    final before = _events.length;
    _events.removeWhere((e) => e.id == id);
    if (_events.length != before) {
      _saveToDisk();
      return true;
    }
    return false;
  }

  void upsertTournament(CafeTournamentTier tier) {
    final idx = _tournaments.indexWhere((t) => t.id == tier.id);
    if (idx >= 0) {
      _tournaments[idx] = tier;
    } else {
      _tournaments.add(tier);
    }
    _saveToDisk();
  }

  bool deleteTournament(String id) {
    final before = _tournaments.length;
    _tournaments.removeWhere((t) => t.id == id);
    if (_tournaments.length != before) {
      _saveToDisk();
      return true;
    }
    return false;
  }

  void _seedDefaults() {
    _events
      ..clear()
      ..addAll(CafeLiveOpsDefaults.events);
    _tournaments
      ..clear()
      ..addAll(CafeLiveOpsDefaults.tournaments);
  }

  void _loadFromDisk() {
    final path = storageFilePath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) return;

      final rawEvents = decoded['events'] as List<Object?>?;
      if (rawEvents != null && rawEvents.isNotEmpty) {
        _events
          ..clear()
          ..addAll([
            for (final item in rawEvents)
              if (item is Map<String, Object?>)
                CafeEventDefinition.fromJson(item),
          ]);
      }

      final rawTournaments = decoded['tournaments'] as List<Object?>?;
      if (rawTournaments != null && rawTournaments.isNotEmpty) {
        _tournaments
          ..clear()
          ..addAll([
            for (final item in rawTournaments)
              if (item is Map<String, Object?>)
                CafeTournamentTier.fromJson(item),
          ]);
      }
    } catch (_) {}
  }

  void _saveToDisk() {
    final path = storageFilePath;
    if (path == null || path.isEmpty) return;
    try {
      File(path).writeAsStringSync(
        jsonEncode({
          'events': [for (final e in _events) e.toJson()],
          'tournaments': [for (final t in _tournaments) t.toJson()],
        }),
      );
    } catch (_) {}
  }
}

/// Comprehensive 4-tab Arabic Online Control Panel served at `GET /admin`:
/// 1. Live Server Overview & Active Rooms Control
/// 2. Players & Accounts Moderation (Search, Temporary Ban, Unban, Adjust Dinars/VIP, Cancel/Delete Account)
/// 3. Recurring Events & Sponsored Ad Events with Custom Image Upload/URL
/// 4. Tournaments Management
const String kAdminDashboardHtml = r'''<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>لوحة إدارة المقهى الشاملة — التحكم الكامل بالأونلاين</title>
<style>
  body { background:#140B07; color:#FBF6E9; font-family:system-ui,-apple-system,sans-serif; margin:0; padding:18px; }
  .wrap { max-width:1100px; margin:0 auto; }
  h1, h2, h3 { color:#D4AF37; margin-top:0; }
  .card { background:#21130C; border:1px solid rgba(212,175,55,0.35); border-radius:14px; padding:16px; margin-bottom:16px; }
  input, select { background:#120905; color:#FBF6E9; border:1px solid rgba(212,175,55,0.4); border-radius:8px; padding:8px 10px; width:100%; box-sizing:border-box; margin-bottom:10px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:10px; }
  .stats-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); gap:10px; margin-bottom:16px; }
  .stat-box { background:#180D08; border:1px solid rgba(212,175,55,0.35); border-radius:12px; padding:12px; text-align:center; }
  .stat-box b { font-size:22px; color:#D4AF37; display:block; }
  .tabs { display:flex; gap:8px; flex-wrap:wrap; margin-bottom:16px; }
  .tab-btn { background:#24150D; color:#FBF6E9; border:1px solid rgba(212,175,55,0.4); border-radius:10px; padding:9px 15px; font-weight:800; cursor:pointer; }
  .tab-btn.active { background:linear-gradient(90deg,#E5C158,#B8860B); color:#1A0E06; border-color:#D4AF37; }
  button { background:linear-gradient(90deg,#E5C158,#B8860B); color:#1A0E06; border:none; border-radius:8px; padding:8px 13px; font-weight:800; cursor:pointer; margin-left:5px; margin-bottom:5px; }
  button.sec { background:#2E1B11; color:#D4AF37; border:1px solid #D4AF37; }
  button.warn { background:#8D4E12; color:#fff; }
  button.del { background:#6E1E1E; color:#fff; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  th, td { border-bottom:1px solid rgba(212,175,55,0.16); padding:9px 6px; text-align:right; }
  th { color:#D4AF37; }
  .row-item { display:flex; justify-content:space-between; align-items:center; gap:10px; border-bottom:1px solid rgba(212,175,55,0.15); padding:10px 0; flex-wrap:wrap; }
  .pill { font-size:11.5px; padding:2px 8px; border-radius:99px; background:rgba(212,175,55,0.18); color:#D4AF37; }
  .pill.ban { background:rgba(229,57,53,0.25); color:#FF8A80; }
  .hidden { display:none; }
</style>
</head>
<body>
<div class="wrap">
  <h1>☕ لوحة إدارة المقهى الشاملة — التحكم الكامل بالأونلاين</h1>
  <div class="card">
    <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
      <label>مفتاح الإدارة السري (ADMIN_SECRET):</label>
      <input id="secret" type="password" value="maqha_admin_2026" style="max-width:260px;margin:0;" />
      <button onclick="loadOverview()">اتصال وتحديث البيانات ↻</button>
      <span id="status" style="color:#81C784;font-size:13px;"></span>
    </div>
  </div>

  <div class="stats-grid">
    <div class="stat-box"><b id="st_accounts">0</b>إجمالي الحسابات</div>
    <div class="stat-box"><b id="st_banned">0</b>محظورون حالياً</div>
    <div class="stat-box"><b id="st_rooms">0</b>الغرف الأونلاين النشطة</div>
    <div class="stat-box"><b id="st_events">0</b>الإيفنتات المفعّلة</div>
    <div class="stat-box"><b id="st_cups">0</b>البطولات المفعّلة</div>
  </div>

  <div class="tabs">
    <button class="tab-btn active" id="tb_players" onclick="showTab('players')">👥 اللاعبون والحسابات والحظر</button>
    <button class="tab-btn" id="tb_events" onclick="showTab('events')">📢 الإيفنتات الدورية وإعلانات الرعاة بالصور</button>
    <button class="tab-btn" id="tb_cups" onclick="showTab('cups')">🏆 إدارة البطولات</button>
    <button class="tab-btn" id="tb_rooms" onclick="showTab('rooms')">🌐 الغرف الحية</button>
  </div>

  <!-- TAB 1: PLAYERS & MODERATION -->
  <div id="sec_players" class="card">
    <h2>👥 إدارة حسابات اللاعبين (حظر مؤقت، إلغاء حساب، وتعديل الرصيد)</h2>
    <input id="player_search" placeholder="ابحث بالاسم أو الإيميل أو معرف اللاعب..." oninput="renderPlayers()" />
    <div style="overflow-x:auto;">
      <table>
        <thead>
          <tr>
            <th>اللاعب</th><th>البريد / الطريقة</th><th>المستوى / التقييم</th><th>دينار المقهى</th><th>الحالة</th><th>إجراءات الإدارة</th>
          </tr>
        </thead>
        <tbody id="players_tbody"></tbody>
      </table>
    </div>
  </div>

  <!-- TAB 2: RECURRING & SPONSORED AD EVENTS -->
  <div id="sec_events" class="card hidden">
    <h2>📢 تصميم إيفنت (دوري ثابت / موسمي رمضان / إعلان لبرنامج أو خدمة بصورتهم)</h2>
    <div style="margin-bottom:10px;">
      <button class="sec" onclick="fillPreset('sponsored')">📢 قالب إعلان لبرنامج / خدمة بصورة</button>
      <button class="sec" onclick="fillPreset('ramadan')">🌙 قالب شهر رمضان</button>
      <button class="sec" onclick="fillPreset('daily')">🔄 قالب إيفنت يومي ثابت</button>
      <button class="sec" onclick="fillPreset('monthly')">📅 قالب إيفنت شهري ثابت</button>
    </div>
    <div class="grid">
      <input id="ev_id" placeholder="معرف فريد مثل ev_sponsor_app1" />
      <input id="ev_titleAr" placeholder="عنوان الإيفنت بالعربي" />
      <input id="ev_titleEn" placeholder="English Title" />
      <select id="ev_recurrence">
        <option value="once">لمرة واحدة / فترة محددة</option>
        <option value="daily">ثابت يتجدد يومياً 🔄</option>
        <option value="weekly">ثابت يتجدد أسبوعياً 🔄</option>
        <option value="monthly">ثابت يتجدد شهرياً 🔄</option>
      </select>
      <select id="ev_theme">
        <option value="sponsored">إيفنت إعلاني / برعاية رسمية 📢</option>
        <option value="ramadan">موسم رمضان 🌙</option>
        <option value="eid">مهرجان العيد 🎉</option>
        <option value="monthly">إيفنت دوري 📅</option>
        <option value="cafe_night">أمسية المقهى ☕</option>
      </select>
      <select id="ev_metric">
        <option value="matches_won">الفوز بالمباريات</option>
        <option value="rounds_won">الفوز بالجولات</option>
        <option value="domino_wins">صكات الدومينو</option>
        <option value="blocked_wins">الفوز بقفلة</option>
        <option value="tournaments_won">الفوز بالبطولات</option>
      </select>
      <input id="ev_target" type="number" placeholder="الهدف المطلوب" value="3" />
      <input id="ev_dinars" type="number" placeholder="مكافأة دينار المقهى" value="300" />
      <input id="ev_xp" type="number" placeholder="مكافأة XP" value="200" />
      <input id="ev_start" placeholder="تاريخ البدء YYYY-MM-DD (اختياري)" />
      <input id="ev_end" placeholder="تاريخ الانتهاء YYYY-MM-DD (اختياري)" />
    </div>
    <input id="ev_descAr" placeholder="وصف الإيفنت أو العرض الترويجي للاعبين" />

    <h3>🖼️ بيانات الإعلان والراعي (اختياري — لإعلانات البرامج والخدمات)</h3>
    <div class="grid">
      <input id="ev_sponsorName" placeholder="اسم البرنامج أو الخدمة الراعية (مثل: تطبيق طلبات)" />
      <input id="ev_ctaLabel" placeholder="نص زر الإعلان (مثل: حمّل التطبيق الآن)" />
      <input id="ev_sponsorUrl" placeholder="رابط الموقع أو التطبيق (https://...)" />
    </div>
    <div class="grid">
      <div>
        <label style="font-size:12px;">ارفع صورة الإعلان مباشرة من جهازك:</label>
        <input type="file" accept="image/*" onchange="encodeBannerFile(this)" />
      </div>
      <div>
        <label style="font-size:12px;">أو ضع رابط صورة مباشر (URL):</label>
        <input id="ev_bannerUrl" placeholder="https://... أو تملأ تلقائياً عند رفع صورة" />
      </div>
    </div>
    <img id="ev_preview" style="max-height:110px;border-radius:10px;display:none;margin-bottom:10px;border:1px solid #D4AF37;" />
    <div><button onclick="saveEvent(true)">نشر وتفعيل الإيفنت في التطبيق فوراً ✓</button></div>

    <hr style="border-color:rgba(212,175,55,0.2);margin:18px 0;" />
    <h3>📋 جميع الإيفنتات الحالية على السيرفر</h3>
    <div id="events_list"></div>
  </div>

  <!-- TAB 3: TOURNAMENTS -->
  <div id="sec_cups" class="card hidden">
    <h2>🏆 إدارة بطولات المقهى</h2>
    <div class="grid">
      <input id="cup_id" placeholder="معرف البطولة مثل cup_special_1000" />
      <input id="cup_titleAr" placeholder="اسم البطولة بالعربي" />
      <input id="cup_fee" type="number" placeholder="رسم الدخول بدينار المقهى" value="1000" />
      <select id="cup_pc"><option value="4">4 لاعبين</option><option value="2">لاعبان (1 ضد 1)</option></select>
      <input id="cup_target" type="number" placeholder="هدف النقاط" value="151" />
      <input id="cup_xp" type="number" placeholder="مكافأة XP للفائز" value="200" />
    </div>
    <button onclick="saveCup()">إضافة / تحديث البطولة ✓</button>
    <div id="tournaments_list" style="margin-top:14px;"></div>
  </div>

  <!-- TAB 4: LIVE ROOMS -->
  <div id="sec_rooms" class="card hidden">
    <h2>🌐 الغرف الأونلاين النشطة حالياً</h2>
    <div id="rooms_list"></div>
  </div>
</div>

<script>
let cachedPlayers = [];
function headers() {
  return { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + document.getElementById('secret').value };
}
function showTab(name) {
  for (const k of ['players','events','cups','rooms']) {
    document.getElementById('sec_' + k).classList.toggle('hidden', k !== name);
    document.getElementById('tb_' + k).classList.toggle('active', k === name);
  }
}
function encodeBannerFile(input) {
  const file = input.files && input.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = e => {
    ev_bannerUrl.value = e.target.result;
    ev_preview.src = e.target.result;
    ev_preview.style.display = 'block';
  };
  reader.readAsDataURL(file);
}
function fillPreset(kind) {
  const stamp = Date.now().toString().slice(-5);
  if (kind === 'sponsored') {
    ev_id.value = 'ev_sponsor_' + stamp;
    ev_titleAr.value = 'بطولة وإيفنت برعاية خاصة';
    ev_titleEn.value = 'Special Sponsored Event';
    ev_descAr.value = 'اربح 3 مباريات في المقهى واحصل على مكافأة الراعي الرسمي!';
    ev_theme.value = 'sponsored'; ev_recurrence.value = 'once'; ev_target.value = 3; ev_dinars.value = 350; ev_xp.value = 200;
    ev_sponsorName.value = 'اسم البرنامج / الخدمة';
    ev_ctaLabel.value = 'تعرف على الخدمة';
  } else if (kind === 'ramadan') {
    ev_id.value = 'ev_ramadan_' + stamp;
    ev_titleAr.value = 'أمسيات شهر رمضان المبارك 🌙';
    ev_titleEn.value = 'Ramadan Majlis Nights';
    ev_descAr.value = 'اربح 5 مباريات في أمسيات رمضان واستلم هدية المقهى!';
    ev_theme.value = 'ramadan'; ev_recurrence.value = 'once'; ev_target.value = 5; ev_dinars.value = 450; ev_xp.value = 300;
  } else if (kind === 'daily') {
    ev_id.value = 'ev_daily_' + stamp;
    ev_titleAr.value = 'تحدي المقهى اليومي الثابت';
    ev_descAr.value = 'يتجدد كل يوم — اربح مباراتين اليوم لكسب الدنانير';
    ev_theme.value = 'cafe_night'; ev_recurrence.value = 'daily'; ev_target.value = 2; ev_dinars.value = 70; ev_xp.value = 80;
  } else {
    ev_id.value = 'ev_monthly_' + stamp;
    ev_titleAr.value = 'تحدي الشهر الثابت في المقهى';
    ev_descAr.value = 'يتجدد كل شهر — اربح 15 جولة لكسب مكافأة الشهر';
    ev_theme.value = 'monthly'; ev_recurrence.value = 'monthly'; ev_target.value = 15; ev_dinars.value = 300; ev_xp.value = 240;
  }
}
async function loadOverview() {
  const res = await fetch('/api/admin/overview', { headers: headers() });
  const data = await res.json();
  if (!res.ok) { status.textContent = 'خطأ: ' + (data.error || res.status); status.style.color='#EF5350'; return; }
  status.textContent = 'متصل بالسيرفر بنجاح ✓';
  status.style.color='#81C784';
  st_accounts.textContent = data.stats.totalAccounts;
  st_banned.textContent = data.stats.bannedAccounts;
  st_rooms.textContent = data.stats.activeRooms;
  st_events.textContent = data.stats.activeEvents;
  st_cups.textContent = data.stats.activeTournaments;
  cachedPlayers = data.accounts || [];
  renderPlayers();
  renderEvents(data.events || []);
  renderCups(data.tournaments || []);
  renderRooms(data.rooms || []);
}
function renderPlayers() {
  const q = (player_search.value || '').toLowerCase();
  const rows = cachedPlayers.filter(p => !q || p.displayName.toLowerCase().includes(q) || p.email.toLowerCase().includes(q) || p.playerId.toLowerCase().includes(q));
  players_tbody.innerHTML = rows.length ? rows.map(p => `
    <tr>
      <td><b>${p.displayName}</b> ${p.isVip ? '<span class="pill">VIP</span>' : ''}<div style="font-size:11px;opacity:0.65;">${p.playerId}</div></td>
      <td>${p.email || '-'}<div style="font-size:11px;opacity:0.7;">${p.provider}</div></td>
      <td>Lv.${p.level} • تقييم ${p.rating}<div style="font-size:11px;opacity:0.7;">فوز: ${p.matchesWon}/${p.matchesPlayed}</div></td>
      <td><b>${p.cafeDinars} د</b></td>
      <td>${p.isBanned ? `<span class="pill ban">محظور مؤقتاً (${p.banReason || 'بدون سبب'})</span>` : '<span class="pill">نشط 🟢</span>'}</td>
      <td>
        ${p.isBanned
          ? `<button class="sec" onclick="unbanUser('${p.playerId}')">فك الحظر ✓</button>`
          : `<button class="warn" onclick="promptBan('${p.playerId}')">حظر مؤقت</button>`}
        <button class="sec" onclick="promptDinars('${p.playerId}', ${p.cafeDinars})">تعديل الدنانير</button>
        <button class="sec" onclick="toggleVip('${p.playerId}', ${!p.isVip})">${p.isVip ? 'إلغاء VIP' : 'منح VIP'}</button>
        <button class="del" onclick="deleteUser('${p.playerId}', '${p.displayName}')">إلغاء الحساب</button>
      </td>
    </tr>`).join('') : '<tr><td colspan="6">لا توجد حسابات مطابقة حالياً</td></tr>';
}
function renderEvents(events) {
  events_list.innerHTML = events.map(e => `
    <div class="row-item">
      <div>
        <strong>${e.titleAr}</strong>
        <span class="pill">${e.enabled ? 'مفعّل 🟢' : 'متوقف ⚪'}</span>
        <span class="pill">التكرار: ${e.recurrence}</span>
        ${e.sponsorName ? `<span class="pill">📢 برعاية: ${e.sponsorName}</span>` : ''}
        <div style="font-size:12px;opacity:0.8;">${e.descAr} | الجائزة: ${e.rewardDinars} دينار + ${e.rewardBonusXp} XP</div>
      </div>
      <div>
        <button class="sec" onclick='toggleEv(${JSON.stringify(e).replace(/'/g,"&#39;")})'>${e.enabled ? 'إيقاف' : 'تفعيل'}</button>
        <button class="del" onclick="delEv('${e.id}')">حذف</button>
      </div>
    </div>`).join('');
}
function renderCups(cups) {
  tournaments_list.innerHTML = cups.map(t => `
    <div class="row-item">
      <div>
        <strong>${t.titleAr}</strong> <span class="pill">${t.enabled ? 'مفعّلة 🟢' : 'متوقفة ⚪'}</span>
        <div style="font-size:12px;opacity:0.8;">الدخول: ${t.entryFeeDinars} د (${t.playerCount} لاعبين) | الهدف: ${t.targetScore}</div>
      </div>
      <div>
        <button class="sec" onclick='toggleCup(${JSON.stringify(t).replace(/'/g,"&#39;")})'>${t.enabled ? 'إيقاف' : 'تفعيل'}</button>
        <button class="del" onclick="delCup('${t.id}')">حذف</button>
      </div>
    </div>`).join('');
}
function renderRooms(rooms) {
  rooms_list.innerHTML = rooms.length ? rooms.map(r => `
    <div class="row-item">
      <div><strong>غرفة #${r.roomCode}</strong> — المضيف: ${r.hostName} (${r.connectedPlayers}/${r.maxPlayers} لاعبين)</div>
      <button class="del" onclick="closeRoom('${r.roomCode}')">إغلاق الغرفة</button>
    </div>`).join('') : '<p style="opacity:0.7;">لا توجد غرف أونلاين مفتوحة في هذه اللحظة.</p>';
}
async function promptBan(userId) {
  const hours = prompt('أدخل مدة الحظر المؤقت بالساعات (مثلاً 24 ليوم، 72 لـ 3 أيام، 168 لأسبوع):', '24');
  if (!hours) return;
  const reason = prompt('سبب الحظر (يظهر للاعب عند محاولة الدخول):', 'مخالفة قوانين المقهى') || '';
  await fetch('/api/admin/accounts/ban', { method:'POST', headers:headers(), body:JSON.stringify({ userId, durationHours: Number(hours), reason }) });
  loadOverview();
}
async function unbanUser(userId) {
  await fetch('/api/admin/accounts/unban', { method:'POST', headers:headers(), body:JSON.stringify({ userId }) });
  loadOverview();
}
async function promptDinars(userId, current) {
  const next = prompt('أدخل الرصيد الجديد من دينار المقهى لهذا اللاعب:', String(current));
  if (next === null) return;
  await fetch('/api/admin/accounts/update', { method:'POST', headers:headers(), body:JSON.stringify({ userId, cafeDinars: Number(next) }) });
  loadOverview();
}
async function toggleVip(userId, isVip) {
  await fetch('/api/admin/accounts/update', { method:'POST', headers:headers(), body:JSON.stringify({ userId, isVip }) });
  loadOverview();
}
async function deleteUser(userId, name) {
  if (!confirm('هل أنت متأكد من إلغاء وحذف حساب "' + name + '" نهائياً؟')) return;
  await fetch('/api/admin/accounts/delete', { method:'POST', headers:headers(), body:JSON.stringify({ userId }) });
  loadOverview();
}
async function closeRoom(roomCode) {
  await fetch('/api/admin/rooms/close', { method:'POST', headers:headers(), body:JSON.stringify({ roomCode }) });
  loadOverview();
}
async function saveEvent(enabled) {
  const body = {
    id: ev_id.value || ('ev_' + Date.now()),
    titleAr: ev_titleAr.value, titleEn: ev_titleEn.value || ev_titleAr.value,
    descAr: ev_descAr.value, descEn: ev_descAr.value,
    theme: ev_theme.value, recurrence: ev_recurrence.value, metric: ev_metric.value,
    targetValue: Number(ev_target.value), rewardDinars: Number(ev_dinars.value), rewardBonusXp: Number(ev_xp.value),
    startDateIso: ev_start.value, endDateIso: ev_end.value,
    isSponsored: Boolean(ev_sponsorName.value || ev_bannerUrl.value),
    sponsorName: ev_sponsorName.value, bannerImageUrl: ev_bannerUrl.value,
    sponsorCtaLabel: ev_ctaLabel.value, sponsorUrl: ev_sponsorUrl.value,
    enabled: enabled
  };
  await fetch('/api/admin/events/upsert', { method:'POST', headers:headers(), body:JSON.stringify(body) });
  loadOverview();
}
async function toggleEv(ev) { ev.enabled = !ev.enabled; await fetch('/api/admin/events/upsert', { method:'POST', headers:headers(), body:JSON.stringify(ev) }); loadOverview(); }
async function delEv(id) { await fetch('/api/admin/events/delete', { method:'POST', headers:headers(), body:JSON.stringify({id}) }); loadOverview(); }
async function saveCup() {
  const body = {
    id: cup_id.value || ('cup_' + Date.now()),
    titleAr: cup_titleAr.value, titleEn: cup_titleAr.value,
    descAr: Number(cup_pc.value) + ' لاعبين • عمولة المقهى 10%', descEn: '10% Café rake',
    entryFeeDinars: Number(cup_fee.value), playerCount: Number(cup_pc.value),
    targetScore: Number(cup_target.value), bonusXpForWinner: Number(cup_xp.value), enabled: true
  };
  await fetch('/api/admin/tournaments/upsert', { method:'POST', headers:headers(), body:JSON.stringify(body) });
  loadOverview();
}
async function toggleCup(t) { t.enabled = !t.enabled; await fetch('/api/admin/tournaments/upsert', { method:'POST', headers:headers(), body:JSON.stringify(t) }); loadOverview(); }
async function delCup(id) { await fetch('/api/admin/tournaments/delete', { method:'POST', headers:headers(), body:JSON.stringify({id}) }); loadOverview(); }
loadOverview();
</script>
</body>
</html>
''';
