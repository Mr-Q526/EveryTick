import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// Dashboard home screen — mirrors (tabs)/index.tsx
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _checkedUpdate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedUpdate) {
      _checkedUpdate = true;
      // Silent auto-check after UI is ready
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) UpdateService.checkForUpdate(context, silent: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = DataScope.of(context);

    if (data.loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('加载中...', style: TextStyle(color: AppColors.textMuted, fontSize: 16))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Dark header ──
          Container(
            decoration: const BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('打卡',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('每一次，都值得被记住',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                // Check update button
                GestureDetector(
                  onTap: () => UpdateService.checkForUpdate(context, silent: false),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppColors.darkSoft, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.system_update_alt, color: Colors.white.withOpacity(0.5), size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                // Stats badges
                if (data.events.isNotEmpty) ...[
                  _StatBadge('${data.events.length}', '项目', const Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  _StatBadge('${data.records.length}', '打卡', const Color(0xFF34D399)),
                ],
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: data.events.isEmpty
                ? _EmptyState(onTap: () => Navigator.pushNamed(context, '/event/new'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: data.events.asMap().entries.map((entry) {
                        final evt = entry.value;
                        final count = data.recordCountFor(evt.id);
                        final color = hexToColor(evt.color);
                        return _EventCard(
                          event: evt,
                          count: count,
                          color: color,
                          onTap: () {
                            if (evt.customFields.isNotEmpty) {
                              Navigator.pushNamed(context, '/record', arguments: evt.id);
                            } else {
                              data.addRecord(evt.id, {});
                            }
                          },
                          onAnalytics: () =>
                              Navigator.pushNamed(context, '/analytics', arguments: evt.id),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
      // ── FAB ──
      floatingActionButton: data.events.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 8,
              onPressed: () => Navigator.pushNamed(context, '/event/new'),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            )
          : null,
    );
  }
}

// ── Sub widgets ──

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBadge(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: AppColors.darkSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(40)),
              child: const Icon(Icons.bolt, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 20),
            const Text('还没有打卡项目',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            const Text('点击下方按钮创建你的第一个打卡项目',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                decoration: BoxDecoration(
                  color: AppColors.dark,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.lg,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('新建项目', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventTemplate event;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onAnalytics;

  const _EventCard({
    required this.event,
    required this.count,
    required this.color,
    required this.onTap,
    required this.onAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 16 * 2 - 12) / 2; // 2 columns with spacing

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppShadows.md,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color bar
            Container(height: 4, color: color),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                            event.icon.isNotEmpty && event.icon.characters.length == 1
                                ? event.icon
                                : event.name.characters.first,
                            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 14),
                      // Name
                      Text(event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 16)),
                      const SizedBox(height: 4),
                      // Count
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('$count', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
                          const SizedBox(width: 4),
                          const Text('次',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ],
                      ),
                    ],
                  ),
                  // Analytics button
                  Positioned(
                    top: 0, right: 0,
                    child: GestureDetector(
                      onTap: onAnalytics,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.bar_chart, color: AppColors.textMuted, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
