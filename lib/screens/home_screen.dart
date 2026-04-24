import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/haptic_service.dart';
import '../services/sound_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'record_screen.dart';

const _bg = Color(0xFFF7FBFF);
const _bgTop = Color(0xFFFAFDFF);
const _bgMid = Color(0xFFEFF7FF);
const _bgBottom = Color(0xFFF2FFF8);
const _surface = Color(0xFFFFFFFF);
const _skySurface = Color(0xFFEAF4FF);
const _mintSurface = Color(0xFFEAFBF0);
const _amberSurface = Color(0xFFFFF4E1);
const _roseSurface = Color(0xFFFFECEA);
const _ink = Color(0xFF1C1C1E);
const _muted = Color(0xFF6E6E73);
const _line = Color(0xFFD1D1D6);
const _primary = Color(0xFF007AFF);
const _sky = Color(0xFF32ADE6);
const _success = Color(0xFF34C759);
const _warning = Color(0xFFFF9500);
const _rose = Color(0xFFFF3B30);
const _radius = 8.0;
const _celebrationDuration = Duration(milliseconds: 1500);

List<BoxShadow> _softShadow([Color color = _primary]) => [
  BoxShadow(
    color: color.withValues(alpha: 0.07),
    blurRadius: 18,
    offset: const Offset(0, 8),
  ),
];

List<BoxShadow> _ambientShadow(Color color, {bool strong = false}) => [
  BoxShadow(
    color: color.withValues(alpha: strong ? 0.18 : 0.1),
    blurRadius: strong ? 30 : 20,
    offset: Offset(0, strong ? 14 : 9),
  ),
  BoxShadow(
    color: Colors.white.withValues(alpha: 0.8),
    blurRadius: 1,
    offset: const Offset(0, -1),
  ),
];

Color _surfaceAltColor(Color color) =>
    Color.alphaBlend(color.withValues(alpha: 0.035), _surface);

enum _HomeMode { checkIn, data, projects }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.84);
  bool _checkedUpdate = false;
  Timer? _updateTimer;
  Timer? _celebrationTimer;
  int _selectedIndex = 0;
  _HomeMode _mode = _HomeMode.checkIn;
  String? _celebratingEventId;
  int _celebrationTick = 0;

  /// Persisted synthesized sound per event (lazy-loaded).
  final Map<String, CheckInSound> _soundByEvent = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedUpdate) {
      return;
    }

    _checkedUpdate = true;
    _updateTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        UpdateService.checkForUpdate(context, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _celebrationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkIn(EventTemplate event) async {
    if (event.customFields.isNotEmpty) {
      final changed = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'close-record-form',
        barrierColor: Colors.black.withValues(alpha: 0.14),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, _, _) {
          return RecordScreen(
            eventId: event.id,
            modalPresentation: true,
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
      if (changed == true && mounted) {
        await _triggerCelebration(event);
      }
      return;
    }

    final data = DataScope.of(context);
    await HapticService.checkInTap();
    await data.addRecord(event.id, {});
    if (mounted) {
      await _triggerCelebration(event);
    }
  }

  Future<void> _editRecord(EventTemplate event, EventRecord record) async {
    await Navigator.pushNamed(
      context,
      '/record',
      arguments: RecordScreenArgs(eventId: event.id, recordId: record.id),
    );
  }

  Future<void> _triggerCelebration(EventTemplate event) async {
    _celebrationTimer?.cancel();
    await HapticService.celebrateCheckIn();
    final localAudio = SoundService.getLocalAudio(event.id);
    if (localAudio != null) {
      // ignore: unawaited_futures
      SoundService.playLocalAudio(localAudio.$2);
    } else {
      final sound =
          _soundByEvent[event.id] ??
          await SoundService.loadEventSound(event.id);
      _soundByEvent[event.id] = sound;
      // ignore: unawaited_futures
      SoundService.play(sound);
    }
    setState(() {
      _celebratingEventId = event.id;
      _celebrationTick++;
      _selectedIndex = 0; // pinned card is always at index 0
    });
    _pageController.jumpToPage(0);
    _celebrationTimer = Timer(_celebrationDuration, () {
      if (!mounted || _celebratingEventId != event.id) {
        return;
      }
      setState(() => _celebratingEventId = null);
    });
  }

  void _selectProject(int index) {
    setState(() {
      _selectedIndex = index;
      _mode = _HomeMode.checkIn;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = DataScope.of(context);

    if (data.loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: _AppBackground(child: SafeArea(child: _LoadingHome())),
      );
    }

    final rawStats = _HomeStats.from(data.events, data.records);

    // During celebration, pin the celebrating card to the front of the deck
    // so the flip animation is always visible regardless of sort order.
    final stats = (_celebratingEventId != null &&
            rawStats.deck.any((e) => e.id == _celebratingEventId))
        ? rawStats.copyWithPinnedDeck(_celebratingEventId!)
        : rawStats;

    if (_selectedIndex >= stats.deck.length) {
      _selectedIndex = stats.deck.isEmpty ? 0 : stats.deck.length - 1;
    }
    final selected = stats.deck.isEmpty ? null : stats.deck[_selectedIndex];

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: stats.deck.isEmpty
          ? null
          : _BottomSwitchBar(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
      body: _AppBackground(
        child: SafeArea(
          bottom: false,
          child: stats.deck.isEmpty
              ? _EmptyHome(
                  onCreate: () => Navigator.pushNamed(context, '/event/new'),
                  onCheckUpdate: () =>
                      UpdateService.checkForUpdate(context, silent: false),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _TopBar(
                        selected: selected!,
                        stats: stats,
                        onCreate: () =>
                            Navigator.pushNamed(context, '/event/new'),
                        onCheckUpdate: () => UpdateService.checkForUpdate(
                          context,
                          silent: false,
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: switch (_mode) {
                          _HomeMode.checkIn => _CheckInStage(
                            key: const ValueKey('checkIn'),
                            stats: stats,
                            selectedIndex: _selectedIndex,
                            pageController: _pageController,
                            celebratingEventId: _celebratingEventId,
                            celebrationTick: _celebrationTick,
                            onPageChanged: (index) =>
                                setState(() => _selectedIndex = index),
                            onCheckIn: _checkIn,
                            onAnalytics: (event) => Navigator.pushNamed(
                              context,
                              '/analytics',
                              arguments: event.id,
                            ),
                          ),
                          _HomeMode.data => _DataStage(
                            key: const ValueKey('data'),
                            stats: stats,
                            selected: selected,
                            onAnalytics: () => Navigator.pushNamed(
                              context,
                              '/analytics',
                              arguments: selected.id,
                            ),
                            onEditRecord: (record) =>
                                _editRecord(selected, record),
                          ),
                          _HomeMode.projects => _ProjectsStage(
                            key: const ValueKey('projects'),
                            stats: stats,
                            selectedIndex: _selectedIndex,
                            onSelect: _selectProject,
                            onCheckIn: _checkIn,
                            onAnalytics: (event) => Navigator.pushNamed(
                              context,
                              '/analytics',
                              arguments: event.id,
                            ),
                            onEdit: (event) => Navigator.pushNamed(
                              context,
                              '/event/edit',
                              arguments: event,
                            ),
                          ),
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AppBackground extends StatelessWidget {
  final Widget child;

  const _AppBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgMid, _bgBottom],
          stops: [0, 0.54, 1],
        ),
      ),
      child: child,
    );
  }
}

class _HomeStats {
  final List<EventTemplate> deck;
  final Map<String, EventTemplate> eventById;
  final Map<String, List<EventRecord>> recordsByEvent;
  final Map<String, int> totalByEvent;
  final Map<String, int> todayByEvent;
  final Map<String, EventRecord> latestByEvent;
  final List<EventRecord> recentRecords;
  final int totalRecords;
  final int todayCount;
  final int activeEventCountToday;

  const _HomeStats({
    required this.deck,
    required this.eventById,
    required this.recordsByEvent,
    required this.totalByEvent,
    required this.todayByEvent,
    required this.latestByEvent,
    required this.recentRecords,
    required this.totalRecords,
    required this.todayCount,
    required this.activeEventCountToday,
  });

  int totalFor(EventTemplate event) => totalByEvent[event.id] ?? 0;

  int todayFor(EventTemplate event) => todayByEvent[event.id] ?? 0;

  EventRecord? latestFor(EventTemplate event) => latestByEvent[event.id];

  List<EventRecord> recordsFor(EventTemplate event) =>
      recordsByEvent[event.id] ?? const [];

  int streakFor(EventTemplate event) {
    final days = <String>{};
    for (final record in recordsFor(event)) {
      final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      days.add(_dayKey(DateTime(time.year, time.month, time.day)));
    }

    var streak = 0;
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    while (days.contains(_dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  _HomeStats copyWithPinnedDeck(String pinnedId) {
    final pinned = deck.firstWhere((e) => e.id == pinnedId);
    final rest = deck.where((e) => e.id != pinnedId).toList();
    return _HomeStats(
      deck: [pinned, ...rest],
      eventById: eventById,
      recordsByEvent: recordsByEvent,
      totalByEvent: totalByEvent,
      todayByEvent: todayByEvent,
      latestByEvent: latestByEvent,
      recentRecords: recentRecords,
      totalRecords: totalRecords,
      todayCount: todayCount,
      activeEventCountToday: activeEventCountToday,
    );
  }

  List<_DayCount> weekFor(EventTemplate event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final counts = <String, int>{};

    for (final record in recordsFor(event)) {
      final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      final day = DateTime(time.year, time.month, time.day);
      counts[_dayKey(day)] = (counts[_dayKey(day)] ?? 0) + 1;
    }

    return [
      for (var index = 6; index >= 0; index--)
        () {
          final day = today.subtract(Duration(days: index));
          return _DayCount(day: day, count: counts[_dayKey(day)] ?? 0);
        }(),
    ];
  }

  factory _HomeStats.from(
    List<EventTemplate> events,
    List<EventRecord> records,
  ) {
    final now = DateTime.now();
    final eventById = {for (final event in events) event.id: event};
    final recordsByEvent = <String, List<EventRecord>>{
      for (final event in events) event.id: <EventRecord>[],
    };
    final totalByEvent = <String, int>{};
    final todayByEvent = <String, int>{};
    final latestByEvent = <String, EventRecord>{};
    var todayCount = 0;

    for (final record in records) {
      recordsByEvent
          .putIfAbsent(record.eventId, () => <EventRecord>[])
          .add(record);
      totalByEvent[record.eventId] = (totalByEvent[record.eventId] ?? 0) + 1;

      final latest = latestByEvent[record.eventId];
      if (latest == null || record.timestamp > latest.timestamp) {
        latestByEvent[record.eventId] = record;
      }

      final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      if (_isSameDay(time, now)) {
        todayCount++;
        todayByEvent[record.eventId] = (todayByEvent[record.eventId] ?? 0) + 1;
      }
    }

    for (final list in recordsByEvent.values) {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    final deck = List<EventTemplate>.from(events)
      ..sort((a, b) {
        final aToday = todayByEvent[a.id] ?? 0;
        final bToday = todayByEvent[b.id] ?? 0;
        if (aToday != bToday) {
          return aToday.compareTo(bToday);
        }

        final aLatest = latestByEvent[a.id]?.timestamp ?? 0;
        final bLatest = latestByEvent[b.id]?.timestamp ?? 0;
        if (aLatest != bLatest) {
          return aLatest.compareTo(bLatest);
        }

        return (totalByEvent[b.id] ?? 0).compareTo(totalByEvent[a.id] ?? 0);
      });

    final recentRecords = List<EventRecord>.from(records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return _HomeStats(
      deck: deck,
      eventById: eventById,
      recordsByEvent: recordsByEvent,
      totalByEvent: totalByEvent,
      todayByEvent: todayByEvent,
      latestByEvent: latestByEvent,
      recentRecords: recentRecords.take(5).toList(),
      totalRecords: records.length,
      todayCount: todayCount,
      activeEventCountToday: todayByEvent.keys.length,
    );
  }
}

class _DayCount {
  final DateTime day;
  final int count;

  const _DayCount({required this.day, required this.count});
}

class _TopBar extends StatelessWidget {
  final EventTemplate selected;
  final _HomeStats stats;
  final VoidCallback onCreate;
  final VoidCallback onCheckUpdate;

  const _TopBar({
    required this.selected,
    required this.stats,
    required this.onCreate,
    required this.onCheckUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final color = hexToColor(selected.color);

    return Row(
      children: [
        _EventMark(event: selected, color: color, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EveryTick',
                style: TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${DateFormat('M月d日').format(now)} · 今日 ${stats.todayCount} 次',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _IconButtonLight(
          icon: Icons.system_update_alt_rounded,
          label: '检查更新',
          onTap: onCheckUpdate,
        ),
        const SizedBox(width: 8),
        _PrimaryButton(label: '新建', icon: Icons.add_rounded, onTap: onCreate),
      ],
    );
  }
}

class _CheckInStage extends StatelessWidget {
  final _HomeStats stats;
  final int selectedIndex;
  final PageController pageController;
  final String? celebratingEventId;
  final int celebrationTick;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<EventTemplate> onCheckIn;
  final ValueChanged<EventTemplate> onAnalytics;

  const _CheckInStage({
    super.key,
    required this.stats,
    required this.selectedIndex,
    required this.pageController,
    required this.celebratingEventId,
    required this.celebrationTick,
    required this.onPageChanged,
    required this.onCheckIn,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final selected = stats.deck[selectedIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _SelectedDataStrip(stats: stats, selected: selected),
        ),
        Expanded(
          child: PageView.builder(
            controller: pageController,
            itemCount: stats.deck.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final event = stats.deck[index];
              return AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                scale: index == selectedIndex ? 1 : 0.94,
                child: _BigCheckInCard(
                  event: event,
                  stats: stats,
                  isSelected: index == selectedIndex,
                  isCelebrating: celebratingEventId == event.id,
                  celebrationTick: celebrationTick,
                  onCheckIn: () => onCheckIn(event),
                  onAnalytics: () => onAnalytics(event),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _WeekCapsule(stats: stats, selected: selected),
        ),
      ],
    );
  }
}

class _SelectedDataStrip extends StatelessWidget {
  final _HomeStats stats;
  final EventTemplate selected;

  const _SelectedDataStrip({required this.stats, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(selected.color);
    return Row(
      children: [
        Expanded(
          child: _MiniDataCard(
            label: '今日',
            value: '${stats.todayFor(selected)}',
            color: color,
            tint: color.withValues(alpha: 0.09),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniDataCard(
            label: '连续',
            value: '${stats.streakFor(selected)}',
            color: _warning,
            tint: _amberSurface,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniDataCard(
            label: '累计',
            value: '${stats.totalFor(selected)}',
            color: _success,
            tint: _mintSurface,
          ),
        ),
      ],
    );
  }
}

class _MiniDataCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color tint;

  const _MiniDataCard({
    required this.label,
    required this.value,
    required this.color,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 66,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tint,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: 0.96),
            Colors.white.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: Text(
              value,
              key: ValueKey('$label-$value'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigCheckInCard extends StatelessWidget {
  final EventTemplate event;
  final _HomeStats stats;
  final bool isSelected;
  final bool isCelebrating;
  final int celebrationTick;
  final VoidCallback onCheckIn;
  final VoidCallback onAnalytics;

  const _BigCheckInCard({
    required this.event,
    required this.stats,
    required this.isSelected,
    required this.isCelebrating,
    required this.celebrationTick,
    required this.onCheckIn,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(event.color);
    final latest = stats.latestFor(event);
    final card = _GlassSurface(
      padding: const EdgeInsets.all(18),
      accent: color,
      elevated: isSelected,
      borderColor: isSelected ? color.withValues(alpha: 0.44) : _line,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          color.withValues(alpha: isSelected ? 0.16 : 0.08),
          Colors.white.withValues(alpha: 0.76),
        ],
        stops: const [0, 0.46, 1],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusTag(
                    label: isCelebrating
                        ? '已完成记录'
                        : stats.todayFor(event) == 0
                        ? '推荐打卡'
                        : '今日已记录',
                    color: isCelebrating
                        ? color
                        : stats.todayFor(event) == 0
                        ? _warning
                        : _success,
                  ),
                  const Spacer(),
                  _IconButtonLight(
                    icon: Icons.bar_chart_rounded,
                    label: '查看分析',
                    onTap: onAnalytics,
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (isCelebrating)
                      _MultiRingPulse(
                        key: ValueKey('halo-${event.id}-$celebrationTick'),
                        color: color,
                      ),
                    AnimatedScale(
                      scale: isCelebrating ? 1.18 : isSelected ? 1 : 0.96,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutBack,
                      child: _EventMark(event: event, color: color, size: 94),
                    ),
                    if (isCelebrating)
                      Positioned(
                        bottom: -10,
                        child: _SuccessCapsule(
                          key: ValueKey('success-${event.id}-$celebrationTick'),
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  event.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Text(
                    isCelebrating
                        ? '刚刚完成一次记录'
                        : latest == null
                        ? '从第一次开始'
                        : '上次 ${_formatRelativeTime(latest.timestamp)}',
                    key: ValueKey('sub-${event.id}-$isCelebrating-${latest?.timestamp}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _ColorButton(
                label: isCelebrating
                    ? '已记录'
                    : event.customFields.isEmpty
                    ? '立即 +1'
                    : '填写并 +1',
                color: color,
                height: 58,
                onTap: onCheckIn,
              ),
            ],
          ),
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 18, 6, 18),
          child: isCelebrating
              ? _CardFlipMotion(
                  key: ValueKey('card-${event.id}-$celebrationTick'),
                  child: card,
                )
              : card,
        ),
      ],
    );
  }
}

class _WeekCapsule extends StatelessWidget {
  final _HomeStats stats;
  final EventTemplate selected;

  const _WeekCapsule({required this.stats, required this.selected});

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(selected.color);
    final buckets = stats.weekFor(selected);
    final maxCount = buckets.fold<int>(1, (max, bucket) {
      return bucket.count > max ? bucket.count : max;
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      height: 98,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '7日节奏',
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '随项目切换',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: buckets.map((bucket) {
                final isToday = _isSameDay(bucket.day, DateTime.now());
                final ratio = bucket.count / maxCount;
                final height = bucket.count == 0 ? 8.0 : 14 + ratio * 38;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          height: height,
                          decoration: BoxDecoration(
                            color: bucket.count == 0
                                ? _line
                                : isToday
                                ? color
                                : color.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(_radius),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _weekdayShort(bucket.day),
                          style: TextStyle(
                            color: isToday ? color : _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataStage extends StatelessWidget {
  final _HomeStats stats;
  final EventTemplate selected;
  final VoidCallback onAnalytics;
  final ValueChanged<EventRecord> onEditRecord;

  const _DataStage({
    super.key,
    required this.stats,
    required this.selected,
    required this.onAnalytics,
    required this.onEditRecord,
  });

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(selected.color);
    final records = stats.recordsFor(selected);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        _Panel(
          tint: color.withValues(alpha: 0.08),
          borderColor: color.withValues(alpha: 0.2),
          shadowColor: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: '${selected.name} 数据',
                subtitle: '当前滑动项目的数据概览',
                color: color,
              ),
              const SizedBox(height: 16),
              _SelectedDataStrip(stats: stats, selected: selected),
              const SizedBox(height: 16),
              _WeekCapsule(stats: stats, selected: selected),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ColorButton(
                      label: '查看完整分析',
                      color: color,
                      height: 48,
                      onTap: onAnalytics,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          tint: _surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: '打卡记录',
                subtitle: records.isEmpty
                    ? '还没有记录'
                    : '共 ${records.length} 条 · 点击可修改',
                color: _sky,
              ),
              const SizedBox(height: 8),
              if (records.isEmpty)
                const _EmptyLine(text: '这个项目还没有记录。')
              else
                ...records.map(
                  (record) => _RecordLine(
                    event: selected,
                    record: record,
                    onTap: () => onEditRecord(record),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectsStage extends StatelessWidget {
  final _HomeStats stats;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<EventTemplate> onCheckIn;
  final ValueChanged<EventTemplate> onAnalytics;
  final ValueChanged<EventTemplate> onEdit;

  const _ProjectsStage({
    super.key,
    required this.stats,
    required this.selectedIndex,
    required this.onSelect,
    required this.onCheckIn,
    required this.onAnalytics,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: stats.deck.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Panel(
            tint: _roseSurface,
            borderColor: const Color(0xFFFFD1CC),
            shadowColor: _rose,
            child: _SectionTitle(
              title: '项目切换',
              subtitle: '${stats.deck.length} 个项目 · 点击后回到大卡片',
              color: _rose,
            ),
          );
        }

        final projectIndex = index - 1;
        final event = stats.deck[projectIndex];
        return _ProjectRow(
          event: event,
          selected: projectIndex == selectedIndex,
          todayCount: stats.todayFor(event),
          totalCount: stats.totalFor(event),
          onSelect: () => onSelect(projectIndex),
          onCheckIn: () => onCheckIn(event),
          onAnalytics: () => onAnalytics(event),
          onEdit: () => onEdit(event),
        );
      },
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final EventTemplate event;
  final bool selected;
  final int todayCount;
  final int totalCount;
  final VoidCallback onSelect;
  final VoidCallback onCheckIn;
  final VoidCallback onAnalytics;
  final VoidCallback onEdit;

  const _ProjectRow({
    required this.event,
    required this.selected,
    required this.todayCount,
    required this.totalCount,
    required this.onSelect,
    required this.onCheckIn,
    required this.onAnalytics,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(event.color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(_radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : _surface,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      color.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.82),
                    ]
                  : [_surface, _surfaceAltColor(color)],
            ),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.32) : _line,
            ),
            boxShadow: selected ? _softShadow(color) : null,
          ),
          child: Row(
            children: [
              _EventMark(event: event, color: color, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatusTag(
                          label: '今日 $todayCount',
                          color: todayCount > 0 ? _success : _muted,
                        ),
                        _StatusTag(label: '累计 $totalCount', color: color),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TinyIcon(icon: Icons.add_rounded, label: '打卡', onTap: onCheckIn),
              const SizedBox(width: 6),
              _TinyIcon(
                icon: Icons.bar_chart_rounded,
                label: '分析',
                onTap: onAnalytics,
              ),
              const SizedBox(width: 6),
              _TinyIcon(icon: Icons.tune_rounded, label: '编辑', onTap: onEdit),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  final EventTemplate event;
  final EventRecord record;
  final VoidCallback onTap;

  const _RecordLine({
    required this.event,
    required this.record,
    required this.onTap,
  });

  /// Brief summary of field values (up to 2 fields).
  static String _fieldSummary(EventTemplate event, EventRecord record) {
    if (event.customFields.isEmpty || record.fieldValues.isEmpty) return '';
    final parts = <String>[];
    for (final field in event.customFields) {
      final val = record.fieldValues[field.id];
      if (val == null) continue;
      final s = switch (field.type) {
        FieldType.toggle => val == true ? field.name : null,
        FieldType.number ||
        FieldType.duration ||
        FieldType.cost => '$val${field.unit.isNotEmpty ? ' ${field.unit}' : ''}',
        FieldType.text ||
        FieldType.notes => val is String && val.isNotEmpty ? val : null,
        FieldType.singleSelect =>
          val is String && val.isNotEmpty ? val : null,
        FieldType.multiSelect =>
          val is List && val.isNotEmpty ? val.join('、') : null,
        _ => val.toString().isNotEmpty ? val.toString() : null,
      };
      if (s != null) parts.add(s);
      if (parts.length >= 2) break;
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(event.color);
    final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final dateStr = DateFormat('MM/dd').format(time);
    final timeStr = DateFormat('HH:mm').format(time);
    final summary = _fieldSummary(event, record);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Column(
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: summary.isNotEmpty
                    ? Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      )
                    : const Text(
                        '点击修改',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MultiRingPulse extends StatelessWidget {
  final Color color;

  const _MultiRingPulse({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.linear,
      builder: (context, value, _) {
        return SizedBox(
          width: 118,
          height: 118,
          child: CustomPaint(
            painter: _RingPulsePainter(color: color, progress: value),
          ),
        );
      },
    );
  }
}

class _RingPulsePainter extends CustomPainter {
  final Color color;
  final double progress;

  _RingPulsePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final delay = i * 0.2;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final eased = Curves.easeOutCubic.transform(t);
      final radius = 28 + eased * 52;
      final opacity = (1 - eased) * (0.35 - i * 0.08);
      if (opacity <= 0) continue;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8 - eased * 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPulsePainter old) =>
      old.progress != progress;
}

class _CardFlipMotion extends StatelessWidget {
  final Widget child;

  const _CardFlipMotion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 3 整圈（6π），easeOut：开始飞快、末尾柔和停下
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: math.pi * 6),
      duration: _celebrationDuration,
      curve: Curves.easeOut,
      builder: (context, angle, builtChild) {
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012) // 透视深度
          ..rotateY(angle);
        return Transform(
          transform: matrix,
          alignment: Alignment.center,
          child: builtChild,
        );
      },
      // RepaintBoundary 先把卡片光栅化为位图，
      // 避免 BackdropFilter 在变换坐标系下重新计算，
      // 确保旋转时与静止时视觉完全一致。
      child: RepaintBoundary(child: child),
    );
  }
}

class _SuccessCapsule extends StatelessWidget {
  final Color color;

  const _SuccessCapsule({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value.clamp(0.0, 1.15),
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: _ambientShadow(color, strong: true),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 15, color: Colors.white),
            SizedBox(width: 5),
            Text(
              '+1 已记下',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 5,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Color tint;
  final Color borderColor;
  final Color shadowColor;

  const _Panel({
    required this.child,
    this.tint = _surface,
    this.borderColor = _line,
    this.shadowColor = _primary,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassSurface(
      padding: const EdgeInsets.all(16),
      accent: shadowColor,
      tint: tint,
      borderColor: borderColor,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint.withValues(alpha: 0.92),
          Colors.white.withValues(alpha: 0.78),
        ],
      ),
      child: child,
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final Color tint;
  final Color borderColor;
  final Gradient? gradient;
  final bool elevated;

  const _GlassSurface({
    required this.child,
    required this.accent,
    this.padding = EdgeInsets.zero,
    this.tint = _surface,
    this.borderColor = _line,
    this.gradient,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: _ambientShadow(accent, strong: elevated),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.72),
            gradient: gradient,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 1,
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: elevated ? 0.92 : 0.68),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EventMark extends StatelessWidget {
  final EventTemplate event;
  final Color color;
  final double size;

  const _EventMark({
    required this.event,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      alignment: Alignment.center,
      child: Text(
        _eventMark(event),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: color,
          fontSize: size * 0.44,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;

  const _PressableScale({required this.child});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) {
      return;
    }
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: _PressableScale(
        child: Material(
          color: _primary,
          borderRadius: BorderRadius.circular(_radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorButton extends StatelessWidget {
  final String label;
  final Color color;
  final double height;
  final VoidCallback onTap;

  const _ColorButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: _PressableScale(
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(_radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            child: SizedBox(
              height: height,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButtonLight extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconButtonLight({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: _PressableScale(
        child: Material(
          color: _surface,
          borderRadius: BorderRadius.circular(_radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: _line),
              ),
              child: Icon(icon, color: _muted, size: 19),
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TinyIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: _PressableScale(
        child: Material(
          color: _surface,
          borderRadius: BorderRadius.circular(_radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_radius),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(color: _line),
              ),
              child: Icon(icon, color: _muted, size: 17),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomSwitchBar extends StatelessWidget {
  final _HomeMode mode;
  final ValueChanged<_HomeMode> onChanged;

  const _BottomSwitchBar({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _line),
            boxShadow: _softShadow(_primary),
          ),
          child: Row(
            children: [
              _SwitchItem(
                label: '打卡',
                icon: Icons.add_task_rounded,
                selected: mode == _HomeMode.checkIn,
                color: _primary,
                onTap: () => onChanged(_HomeMode.checkIn),
              ),
              _SwitchItem(
                label: '数据',
                icon: Icons.show_chart_rounded,
                selected: mode == _HomeMode.data,
                color: _success,
                onTap: () => onChanged(_HomeMode.data),
              ),
              _SwitchItem(
                label: '项目',
                icon: Icons.grid_view_rounded,
                selected: mode == _HomeMode.projects,
                color: _rose,
                onTap: () => onChanged(_HomeMode.projects),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SwitchItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: SizedBox(
            height: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: selected ? color : _muted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? color : _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onCheckUpdate;

  const _EmptyHome({required this.onCreate, required this.onCheckUpdate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'EveryTick',
                style: TextStyle(
                  color: _ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _IconButtonLight(
              icon: Icons.system_update_alt_rounded,
              label: '检查更新',
              onTap: onCheckUpdate,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          tint: _skySurface,
          borderColor: const Color(0xFFC7E0FF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionBadge(label: 'START HERE', color: _primary),
              const SizedBox(height: 14),
              const Text(
                '万物皆可打卡',
                style: TextStyle(
                  color: _ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '先创建一个项目。吃一顿火锅、跑一次步、读完一本书，都可以成为自己的数据轨迹。',
                style: TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              _PrimaryButton(
                label: '创建第一个项目',
                icon: Icons.add_rounded,
                onTap: onCreate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyLine extends StatelessWidget {
  final String text;

  const _EmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _line),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: _Panel(
        tint: _skySurface,
        borderColor: const Color(0xFFC7E0FF),
        child: Container(
          height: 220,
          alignment: Alignment.center,
          child: const Text(
            '加载中...',
            style: TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

String _eventMark(EventTemplate event) {
  final icon = event.icon.trim();
  if (icon.isNotEmpty && icon.characters.length <= 2) {
    return icon;
  }

  final name = event.name.trim();
  if (name.isNotEmpty) {
    return name.characters.first;
  }

  return '?';
}

String _formatRelativeTime(int timestamp) {
  final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));

  if (_isSameDay(time, now)) {
    return DateFormat('HH:mm').format(time);
  }
  if (_isSameDay(time, yesterday)) {
    return '昨天 ${DateFormat('HH:mm').format(time)}';
  }
  if (time.year == now.year) {
    return DateFormat('M月d日 HH:mm').format(time);
  }
  return DateFormat('yyyy年M月d日').format(time);
}

String _weekdayShort(DateTime day) {
  if (_isSameDay(day, DateTime.now())) {
    return '今';
  }
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return labels[day.weekday - 1];
}

String _dayKey(DateTime day) => '${day.year}-${day.month}-${day.day}';

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

