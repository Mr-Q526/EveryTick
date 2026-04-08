import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';

enum TimeSpan { oneWeek, oneMonth, threeMonths, oneYear, all }

const _bg = Color(0xFFF7FBFF);
const _bgTop = Color(0xFFFAFDFF);
const _bgMid = Color(0xFFEFF7FF);
const _bgBottom = Color(0xFFF2FFF8);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFF7F7FA);
const _ink = Color(0xFF1C1C1E);
const _muted = Color(0xFF6E6E73);
const _line = Color(0xFFD1D1D6);
const _primary = Color(0xFF007AFF);
const _success = Color(0xFF34C759);
const _danger = Color(0xFFFF3B30);
const _radius = 8.0;

List<BoxShadow> _softShadow([Color color = _primary]) => [
  BoxShadow(
    color: color.withValues(alpha: 0.07),
    blurRadius: 18,
    offset: const Offset(0, 8),
  ),
];

class AnalyticsScreen extends StatefulWidget {
  final String eventId;
  const AnalyticsScreen({super.key, required this.eventId});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  TimeSpan _timeSpan = TimeSpan.all;

  // Chart view visibility management
  static const _prefsKeyPrefix = 'analytics_hidden_charts_';
  Set<String> _hiddenCharts = {};
  bool _editMode = false;
  String get _prefsKey => '$_prefsKeyPrefix${widget.eventId}';

  @override
  void initState() {
    super.initState();
    _loadHiddenCharts();
  }

  Future<void> _loadHiddenCharts() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList(_prefsKey) ?? [];
    setState(() => _hiddenCharts = hidden.toSet());
  }

  Future<void> _hideChart(String chartId) async {
    setState(() => _hiddenCharts.add(chartId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _hiddenCharts.toList());
  }

  Future<void> _restoreAllCharts() async {
    setState(() {
      _hiddenCharts.clear();
      _editMode = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  @override
  Widget build(BuildContext context) {
    final data = DataScope.of(context);
    final event = data.events.firstWhere(
      (e) => e.id == widget.eventId,
      orElse: () => EventTemplate(
        id: '',
        name: '',
        icon: '',
        color: '#000000',
        createdAt: 0,
        customFields: [],
      ),
    );

    if (event.id.isEmpty) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: Text('加载中...')),
      );
    }

    final allRecords = data.recordsFor(event.id);
    final now = DateTime.now();

    // 1. Filtered Records
    final filteredRecords = allRecords.where((r) {
      if (_timeSpan == TimeSpan.all) return true;
      final limitDays = {
        TimeSpan.oneWeek: 7,
        TimeSpan.oneMonth: 30,
        TimeSpan.threeMonths: 90,
        TimeSpan.oneYear: 365,
      }[_timeSpan]!;
      final rDate = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      return now.difference(rDate).inDays <= limitDays;
    }).toList();

    // 2. Frequency Stats (Bar Chart Data)
    // Strategy: 1week=daily(7), 1month=weekly(~5), 3month=weekly(~13), 1year/all=monthly(12)
    final barData = <_ChartData>[];
    int chartMax = 1;
    final activeDaysSet = <String>{};
    String freqUnit = '天';

    for (var r in filteredRecords) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      activeDaysSet.add('${d.year}-${d.month}-${d.day}');
    }

    if (_timeSpan == TimeSpan.oneYear || _timeSpan == TimeSpan.all) {
      // Monthly bars (12)
      freqUnit = '月';
      final counts = <String, int>{};
      for (var r in filteredRecords) {
        final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        final k = '${d.year}-${d.month}';
        counts[k] = (counts[k] ?? 0) + 1;
      }
      for (int i = 11; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final val = counts['${d.year}-${d.month}'] ?? 0;
        barData.add(_ChartData('${d.month}月', val));
        if (val > chartMax) chartMax = val;
      }
    } else if (_timeSpan == TimeSpan.oneWeek) {
      // Daily bars (7)
      freqUnit = '天';
      final counts = <String, int>{};
      for (var r in filteredRecords) {
        final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        final k = '${d.year}-${d.month}-${d.day}';
        counts[k] = (counts[k] ?? 0) + 1;
      }
      const days = ['日', '一', '二', '三', '四', '五', '六'];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final val = counts['${d.year}-${d.month}-${d.day}'] ?? 0;
        barData.add(
          _ChartData('${d.month}/${d.day}\n${days[d.weekday % 7]}', val),
        );
        if (val > chartMax) chartMax = val;
      }
    } else {
      // Weekly aggregation for 1-month / 3-month
      freqUnit = '周';
      final totalDays = _timeSpan == TimeSpan.oneMonth ? 30 : 90;
      final counts = <String, int>{};
      for (var r in filteredRecords) {
        final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        final k = '${d.year}-${d.month}-${d.day}';
        counts[k] = (counts[k] ?? 0) + 1;
      }
      // Group days into weeks
      final startDate = now.subtract(Duration(days: totalDays - 1));
      int i = 0;
      while (i < totalDays) {
        final weekEnd = (i + 6 < totalDays) ? i + 6 : totalDays - 1;
        int weekSum = 0;
        DateTime? wStart;
        for (int j = i; j <= weekEnd; j++) {
          final d = startDate.add(Duration(days: j));
          if (j == i) wStart = d;
          weekSum += counts['${d.year}-${d.month}-${d.day}'] ?? 0;
        }
        final label = '${wStart!.month}/${wStart.day}';
        barData.add(_ChartData(label, weekSum));
        if (weekSum > chartMax) chartMax = weekSum;
        i = weekEnd + 1;
      }
    }

    // 3. Heatmap Data — GitHub-style: aligned to calendar weeks
    // Start from Sunday of ~20 weeks ago, end at today
    final todayDate = DateTime(now.year, now.month, now.day);
    final weeksBack = 20;
    // Go back weeksBack*7 days, then find the previous Sunday
    final rawStart = todayDate.subtract(Duration(days: weeksBack * 7));
    final startSunday = rawStart.subtract(Duration(days: rawStart.weekday % 7));
    final hmCounts = <String, int>{};
    for (var r in allRecords) {
      // use all records, not filtered
      final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      hmCounts['${d.year}-${d.month}-${d.day}'] =
          (hmCounts['${d.year}-${d.month}-${d.day}'] ?? 0) + 1;
    }
    final heatmapData = <_HeatmapDay>[];
    // Generate from startSunday up to today
    var cursor = startSunday;
    while (!cursor.isAfter(todayDate)) {
      final val = hmCounts['${cursor.year}-${cursor.month}-${cursor.day}'] ?? 0;
      heatmapData.add(
        _HeatmapDay(
          date: cursor,
          count: val,
          level: val == 0
              ? 0
              : val < 3
              ? 1
              : val < 5
              ? 2
              : val < 8
              ? 3
              : 4,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }

    // 4. Time Distribs (Weekday / TimeOfDay)
    final wData = List.filled(7, 0);
    final tData = List.filled(4, 0);
    for (var r in filteredRecords) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      // Weekday (0=Sun..6=Sat)
      wData[d.weekday % 7]++;
      // Time block
      if (d.hour < 6) {
        tData[0]++;
      } else if (d.hour < 12) {
        tData[1]++;
      } else if (d.hour < 18) {
        tData[2]++;
      } else {
        tData[3]++;
      }
    }
    final wMax = wData.reduce((a, b) => a > b ? a : b).clamp(1, 9999);
    final tMax = tData.reduce((a, b) => a > b ? a : b).clamp(1, 9999);

    // 5. Field Aggregations & Frequencies
    final aggs = <String, _FieldAgg>{};
    for (var f in event.customFields) {
      if ([
        FieldType.number,
        FieldType.duration,
        FieldType.cost,
      ].contains(f.type)) {
        num sum = 0;
        num maxVal = -double.infinity;
        num minVal = double.infinity;
        int count = 0;
        for (var r in filteredRecords) {
          final v = r.fieldValues[f.id];
          if (v is num) {
            sum += v;
            count++;
            if (v > maxVal) maxVal = v;
            if (v < minVal) minVal = v;
          }
        }
        aggs[f.id] = _FieldAgg(
          numSum: sum,
          numAvg: count > 0 ? sum / count : 0,
          numMax: count > 0 ? maxVal : 0,
          numMin: count > 0 ? minVal : 0,
          count: count,
          topFreqs: [],
        );
      } else if (f.type == FieldType.category ||
          f.type == FieldType.text ||
          f.type == FieldType.singleSelect) {
        final cMap = <String, int>{};
        int count = 0;
        for (var r in filteredRecords) {
          final v = r.fieldValues[f.id];
          if (v is String && v.trim().isNotEmpty) {
            cMap[v] = (cMap[v] ?? 0) + 1;
            count++;
          }
        }
        final freqs = cMap.entries.map((e) => _Freq(e.key, e.value)).toList()
          ..sort((a, b) => b.count.compareTo(a.count));
        aggs[f.id] = _FieldAgg(count: count, topFreqs: freqs.take(5).toList());
      } else if (f.type == FieldType.multiSelect) {
        final cMap = <String, int>{};
        int count = 0;
        for (var r in filteredRecords) {
          final v = r.fieldValues[f.id];
          if (v is List) {
            for (var item in v) {
              if (item is String && item.trim().isNotEmpty) {
                cMap[item] = (cMap[item] ?? 0) + 1;
                count++;
              }
            }
          }
        }
        final freqs = cMap.entries.map((e) => _Freq(e.key, e.value)).toList()
          ..sort((a, b) => b.count.compareTo(a.count));
        aggs[f.id] = _FieldAgg(count: count, topFreqs: freqs.take(8).toList());
      } else if (f.type == FieldType.toggle) {
        int trueCount = 0;
        int falseCount = 0;
        for (var r in filteredRecords) {
          final v = r.fieldValues[f.id];
          if (v == true) {
            trueCount++;
          } else {
            falseCount++;
          }
        }
        aggs[f.id] = _FieldAgg(
          count: trueCount + falseCount,
          topFreqs: [_Freq('是', trueCount), _Freq('否', falseCount)],
          numSum: trueCount.toDouble(),
          numAvg: (trueCount + falseCount) > 0
              ? trueCount / (trueCount + falseCount)
              : 0,
        );
      } else if (f.type == FieldType.taggedValues) {
        // Each tag: count occurrences + sum values
        final tagSums = <String, num>{};
        final tagCounts = <String, int>{};
        for (var r in filteredRecords) {
          final v = r.fieldValues[f.id];
          if (v is Map) {
            for (var entry in v.entries) {
              final tag = entry.key.toString();
              final val = entry.value is num ? entry.value as num : 0;
              tagSums[tag] = (tagSums[tag] ?? 0) + val;
              tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
            }
          }
        }
        num totalSum = 0;
        for (var s in tagSums.values) {
          totalSum += s;
        }
        final freqs =
            tagSums.entries
                .map(
                  (e) => _Freq(
                    '${e.key} (${e.value.round()}${f.unit})',
                    tagCounts[e.key] ?? 0,
                  ),
                )
                .toList()
              ..sort((a, b) => b.count.compareTo(a.count));
        aggs[f.id] = _FieldAgg(
          count: tagCounts.values.fold(0, (a, b) => a + b),
          topFreqs: freqs.take(10).toList(),
          numSum: totalSum,
          numAvg: freqs.isNotEmpty
              ? totalSum /
                    filteredRecords
                        .where(
                          (r) =>
                              r.fieldValues[f.id] is Map &&
                              (r.fieldValues[f.id] as Map).isNotEmpty,
                        )
                        .length
                        .clamp(1, 999999)
              : 0,
        );
      }
    }

    // 6. Cross Analysis Pivot Table
    _CrossPivot? pivot;
    final catF = event.customFields
        .where(
          (e) =>
              e.type == FieldType.category ||
              e.type == FieldType.text ||
              e.type == FieldType.singleSelect,
        )
        .firstOrNull;
    final numF = event.customFields
        .where(
          (e) => [
            FieldType.number,
            FieldType.duration,
            FieldType.cost,
          ].contains(e.type),
        )
        .firstOrNull;
    if (catF != null && numF != null && filteredRecords.isNotEmpty) {
      final groups = <String, List<num>>{};
      for (var r in filteredRecords) {
        final c = r.fieldValues[catF.id];
        final n = r.fieldValues[numF.id];
        if (c is String && c.trim().isNotEmpty && n is num) {
          groups.putIfAbsent(c, () => []).add(n);
        }
      }
      final rows = groups.entries.map((e) {
        final s = e.value.reduce((a, b) => a + b);
        return _PivotRow(e.key, s, s / e.value.length);
      }).toList()..sort((a, b) => b.sum.compareTo(a.sum));
      if (rows.isNotEmpty) {
        pivot = _CrossPivot(
          catF.name,
          numF.name,
          numF.type,
          rows.take(10).toList(),
        );
      }
    }

    final color = hexToColor(event.color);
    final avgPerActiveDay = activeDaysSet.isEmpty
        ? '0'
        : (filteredRecords.length / activeDaysSet.length).toStringAsFixed(1);
    final pivotData = pivot;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        centerTitle: false,
        foregroundColor: _ink,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text(
          '完整分析',
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _editMode ? Icons.check_circle : Icons.tune_rounded,
              color: _editMode ? _success : _muted,
            ),
            tooltip: _editMode ? '完成编辑' : '管理视图',
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _muted),
            tooltip: '编辑项目',
            onPressed: () async {
              final changed = await Navigator.pushNamed(
                context,
                '/event/edit',
                arguments: event,
              );
              if (changed == true && mounted) setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _danger),
            tooltip: '删除项目',
            onPressed: () => _confirmDelete(event.id),
          ),
        ],
      ),
      body: _AppBackground(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(_radius),
                    border: Border.all(color: _line.withValues(alpha: 0.75)),
                    boxShadow: _softShadow(color),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(_radius),
                              ),
                              alignment: Alignment.center,
                              child:
                                  event.icon.isNotEmpty &&
                                      event.icon.characters.length == 1
                                  ? Text(
                                      event.icon,
                                      style: const TextStyle(fontSize: 26),
                                    )
                                  : Icon(
                                      Icons.analytics_rounded,
                                      color: color,
                                      size: 26,
                                    ),
                            ),
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
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _editMode
                                        ? '轻点右上角隐藏不需要的图表'
                                        : '趋势、分布和自定义字段洞察',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _TimeSpanSelector(
                          val: _timeSpan,
                          onSelect: (v) => setState(() => _timeSpan = v),
                          color: color,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _TopStat(
                                label: '打卡次数',
                                val: '${filteredRecords.length}',
                                unit: '次',
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TopStat(
                                label: '活跃天数',
                                val: '${activeDaysSet.length}',
                                unit: '天',
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TopStat(
                                label: '活跃日均',
                                val: avgPerActiveDay,
                                unit: '次',
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Frequency chart
                  if (filteredRecords.isNotEmpty &&
                      !_hiddenCharts.contains('frequency'))
                    _DismissibleCard(
                      chartId: 'frequency',
                      editMode: _editMode,
                      onDismiss: () => _hideChart('frequency'),
                      child: _Card(
                        color: color,
                        child: _FrequencyChart(
                          barData: barData,
                          chartMax: chartMax,
                          color: color,
                          freqUnit: freqUnit,
                        ),
                      ),
                    ),

                  // Heatmap
                  if (filteredRecords.isNotEmpty &&
                      !_hiddenCharts.contains('heatmap'))
                    _DismissibleCard(
                      chartId: 'heatmap',
                      editMode: _editMode,
                      onDismiss: () => _hideChart('heatmap'),
                      child: _Card(
                        color: color,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                  color: _ink,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '打卡热力图',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _HeatmapGrid(data: heatmapData, color: color),
                          ],
                        ),
                      ),
                    ),

                  // Weekday / Time
                  if (filteredRecords.isNotEmpty &&
                      !_hiddenCharts.contains('distribution'))
                    _DismissibleCard(
                      chartId: 'distribution',
                      editMode: _editMode,
                      onDismiss: () => _hideChart('distribution'),
                      child: Row(
                        children: [
                          Expanded(
                            child: _WeekdayDist(
                              data: wData,
                              max: wMax,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _TimeDist(
                              data: tData,
                              max: tMax,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (filteredRecords.isEmpty)
                    _Card(
                      color: color,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(_radius),
                            ),
                            child: Icon(Icons.insights_rounded, color: color),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '这个时间范围还没有记录',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '切换时间范围，或先完成几次打卡。',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Field Aggs
                  if (!_hiddenCharts.contains('fields'))
                    _DismissibleCard(
                      chartId: 'fields',
                      editMode: _editMode,
                      onDismiss: () => _hideChart('fields'),
                      child: Column(
                        children: event.customFields.map((f) {
                          final agg = aggs[f.id];
                          if (agg == null || agg.count == 0) {
                            return const SizedBox.shrink();
                          }
                          if (f.type == FieldType.notes) {
                            return const SizedBox.shrink();
                          }

                          return _Card(
                            color: color,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          _radius,
                                        ),
                                      ),
                                      child: Icon(
                                        f.type == FieldType.category
                                            ? Icons.place
                                            : f.type == FieldType.cost
                                            ? Icons.attach_money
                                            : f.type == FieldType.duration
                                            ? Icons.schedule
                                            : f.type == FieldType.singleSelect
                                            ? Icons.radio_button_checked
                                            : f.type == FieldType.multiSelect
                                            ? Icons.checklist
                                            : f.type == FieldType.toggle
                                            ? Icons.toggle_on
                                            : f.type == FieldType.taggedValues
                                            ? Icons.sell
                                            : Icons.tag,
                                        color: color,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${f.name} 分析',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (f.type == FieldType.category ||
                                    f.type == FieldType.text ||
                                    f.type == FieldType.singleSelect ||
                                    f.type == FieldType.multiSelect ||
                                    f.type == FieldType.taggedValues)
                                  ...agg.topFreqs.asMap().entries.map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            child: Text(
                                              '${e.key + 1}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: e.key < 3
                                                    ? color
                                                    : _line,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  e.value.label,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: _ink,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  height: 6,
                                                  width: double.infinity,
                                                  decoration: BoxDecoration(
                                                    color: _surfaceAlt,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                  ),
                                                  child: FractionallySizedBox(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    widthFactor:
                                                        e.value.count /
                                                        agg
                                                            .topFreqs
                                                            .first
                                                            .count,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: color,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              3,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '${e.value.count} 次',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: _muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (f.type == FieldType.toggle) ...[
                                  // Toggle ratio display
                                  Builder(
                                    builder: (_) {
                                      final trueCount = agg.topFreqs.isNotEmpty
                                          ? agg.topFreqs[0].count
                                          : 0;
                                      final falseCount = agg.topFreqs.length > 1
                                          ? agg.topFreqs[1].count
                                          : 0;
                                      final total = trueCount + falseCount;
                                      final pct = total > 0
                                          ? (trueCount / total * 100).round()
                                          : 0;
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '$pct%',
                                                style: TextStyle(
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.w900,
                                                  color: color,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '是: $trueCount 次',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _ink,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '否: $falseCount 次',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _muted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            height: 8,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: _surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: total > 0
                                                  ? trueCount / total
                                                  : 0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: color,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _AggBlock(
                                          '累计总计',
                                          _fmt(agg.numSum, f.type, f.unit),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _AggBlock(
                                          '平均每次',
                                          _fmt(agg.numAvg, f.type, f.unit),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(height: 1, color: _surfaceAlt),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _MinMaxBlock(
                                        '单次最高',
                                        _fmt(agg.numMax, f.type, f.unit),
                                      ),
                                      _MinMaxBlock(
                                        '单次最低',
                                        _fmt(agg.numMin, f.type, f.unit),
                                        right: true,
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Cross Pivot
                  if (pivotData != null && !_hiddenCharts.contains('pivot'))
                    _DismissibleCard(
                      chartId: 'pivot',
                      editMode: _editMode,
                      onDismiss: () => _hideChart('pivot'),
                      child: _Card(
                        color: color,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: color,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '多维透视分析',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '按「${pivotData.catName}」统计「${pivotData.numName}」',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: _surfaceAlt,
                                borderRadius: BorderRadius.circular(_radius),
                              ),
                              child: Column(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            '分类',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _muted,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '总计',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _muted,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '均次',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(height: 1, color: _line),
                                  ...pivotData.rows.asMap().entries.map((e) {
                                    final r = e.value;
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: e.key > 0
                                          ? const BoxDecoration(
                                              border: Border(
                                                top: BorderSide(color: _line),
                                              ),
                                            )
                                          : null,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              r.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _ink,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _fmt(
                                                r.sum,
                                                pivotData.numType,
                                                '',
                                              ),
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: color,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _fmt(
                                                r.avg,
                                                pivotData.numType,
                                                '',
                                              ),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _muted,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Restore hidden charts button
                  if (_hiddenCharts.isNotEmpty)
                    GestureDetector(
                      onTap: _restoreAllCharts,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(_radius),
                          border: Border.all(
                            color: _line,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.visibility,
                              size: 16,
                              color: _muted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '恢复 ${_hiddenCharts.length} 个已隐藏的图表',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Records list
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 16, 4, 10),
                    child: Text(
                      '最新打卡',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  ...filteredRecords.take(15).map((r) {
                    final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
                    final timeStr = DateFormat('MM-dd HH:mm').format(d);

                    final summaries = <String>[];
                    for (var f in event.customFields) {
                      final v = r.fieldValues[f.id];
                      if (v == null || f.type == FieldType.notes) continue;
                      if (f.type == FieldType.toggle) {
                        summaries.add('${f.name}: ${v == true ? '是' : '否'}');
                      } else if (f.type == FieldType.multiSelect && v is List) {
                        if (v.isNotEmpty) summaries.add(v.join(', '));
                      } else if (f.type == FieldType.taggedValues && v is Map) {
                        final parts = v.entries
                            .map((e) => '${e.key}:${e.value}${f.unit}')
                            .toList();
                        if (parts.isNotEmpty) summaries.add(parts.join(' · '));
                      } else if (f.type == FieldType.singleSelect ||
                          f.type == FieldType.category) {
                        if (v is String && v.isNotEmpty) summaries.add(v);
                      } else if (v is num) {
                        summaries.add(_fmt(v, f.type, f.unit));
                      } else if (v is String && v.isNotEmpty) {
                        summaries.add(v);
                      }
                    }
                    final noteField = event.customFields
                        .where((f) => f.type == FieldType.notes)
                        .firstOrNull;
                    final noteStr = noteField != null
                        ? (r.fieldValues[noteField.id] as String? ?? '')
                        : '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(_radius),
                        border: Border.all(color: _line),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              timeStr.split(' ')[0],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: _muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  timeStr.split(' ')[1],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: _muted,
                                  ),
                                ),
                                if (summaries.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    summaries.join(' · '),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                    ),
                                  ),
                                ],
                                if (noteStr.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    noteStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: _muted,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '删除记录',
                            constraints: const BoxConstraints.tightFor(
                              width: 44,
                              height: 44,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: _line,
                            ),
                            onPressed: () => DataScope.of(
                              context,
                            ).deleteRecord(r.id).then((_) => setState(() {})),
                          ),
                        ],
                      ),
                    );
                  }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除项目'),
        content: const Text('确定要删除该项目及其所有打卡记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              DataScope.of(context).deleteEvent(id);
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
            child: const Text('删除', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
  }

  String _fmt(num v, FieldType t, String u) {
    if (v == 0) return '0';
    if (t == FieldType.duration) {
      if (v < 60) return '${v.round()}分钟';
      return '${v ~/ 60}小时${(v % 60).round() > 0 ? "${(v % 60).round()}分" : ""}';
    }
    if (t == FieldType.cost) return '¥${v.toStringAsFixed(1)}';
    String s = v.truncate() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return u.isNotEmpty ? '$s$u' : s;
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

// ── Models ──
class _ChartData {
  final String label;
  final int val;
  _ChartData(this.label, this.val);
}

class _HeatmapDay {
  final DateTime date;
  final int count;
  final int level;
  _HeatmapDay({required this.date, required this.count, required this.level});
}

class _Freq {
  final String label;
  final int count;
  _Freq(this.label, this.count);
}

class _FieldAgg {
  final num numSum, numAvg, numMax, numMin;
  final int count;
  final List<_Freq> topFreqs;
  _FieldAgg({
    this.numSum = 0,
    this.numAvg = 0,
    this.numMax = 0,
    this.numMin = 0,
    required this.count,
    required this.topFreqs,
  });
}

class _PivotRow {
  final String label;
  final num sum, avg;
  _PivotRow(this.label, this.sum, this.avg);
}

class _CrossPivot {
  final String catName, numName;
  final FieldType numType;
  final List<_PivotRow> rows;
  _CrossPivot(this.catName, this.numName, this.numType, this.rows);
}

// ── Components ──

class _TimeSpanSelector extends StatelessWidget {
  final TimeSpan val;
  final ValueChanged<TimeSpan> onSelect;
  final Color color;
  const _TimeSpanSelector({
    required this.val,
    required this.onSelect,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _line.withValues(alpha: 0.65)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn('1周', TimeSpan.oneWeek),
            _btn('1月', TimeSpan.oneMonth),
            _btn('3月', TimeSpan.threeMonths),
            _btn('1年', TimeSpan.oneYear),
            _btn('全部', TimeSpan.all),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, TimeSpan t) {
    final sel = val == t;
    return Semantics(
      button: true,
      selected: sel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 36, minWidth: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: sel ? _softShadow(color) : const [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: sel ? color : _muted,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  final String label, val, unit;
  final Color color;
  const _TopStat({
    required this.label,
    required this.val,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _line.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  val,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

class _Card extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Card({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.11),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.75),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.74),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.92),
                color.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.76),
              ],
              stops: const [0, 0.5, 1],
            ),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _line.withValues(alpha: 0.72)),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 1,
                child: ColoredBox(color: Colors.white.withValues(alpha: 0.8)),
              ),
              Padding(padding: const EdgeInsets.all(18), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<_HeatmapDay> data;
  final Color color;
  const _HeatmapGrid({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final totalDays = data.length;
    final fullWeeks = totalDays ~/ 7;
    final extraDays = totalDays % 7;
    final weeksCount = fullWeeks + (extraDays > 0 ? 1 : 0);

    // Month labels at first week of each month
    final monthLabels = <int, String>{};
    int lastLabelMonth = -1;
    for (int wIdx = 0; wIdx < weeksCount; wIdx++) {
      final dayIdx = wIdx * 7;
      if (dayIdx >= totalDays) break;
      final day = data[dayIdx];
      if (day.date.month != lastLabelMonth) {
        monthLabels[wIdx] = '${day.date.month}月';
        lastLabelMonth = day.date.month;
      }
    }

    const cellSize = 13.0;
    const gap = 3.0;
    const colW = cellSize + gap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: (cellSize + gap) * 7 + 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday labels
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: 22,
                  child: Column(
                    children: List.generate(7, (row) {
                      final show = row == 1 || row == 3 || row == 5;
                      const labels = ['日', '一', '二', '三', '四', '五', '六'];
                      return SizedBox(
                        height: cellSize + gap,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            show ? labels[row] : '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: _muted,
                              height: 1,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // Grid area
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: SizedBox(
                    width: weeksCount * colW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month labels
                        SizedBox(
                          height: 18,
                          child: Stack(
                            children: monthLabels.entries
                                .map(
                                  (e) => Positioned(
                                    left: e.key * colW,
                                    child: Text(
                                      e.value,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: _muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        // Grid
                        SizedBox(
                          height: (cellSize + gap) * 7,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(weeksCount, (wIdx) {
                              return SizedBox(
                                width: colW,
                                child: Column(
                                  children: List.generate(7, (row) {
                                    final idx = wIdx * 7 + row;
                                    if (idx >= totalDays) {
                                      return SizedBox(height: cellSize + gap);
                                    }
                                    final day = data[idx];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: gap,
                                      ),
                                      child: Tooltip(
                                        message:
                                            '${day.date.month}/${day.date.day}: ${day.count}次',
                                        child: Container(
                                          width: cellSize,
                                          height: cellSize,
                                          decoration: BoxDecoration(
                                            color: day.level == 0
                                                ? _surfaceAlt
                                                : color.withValues(
                                                    alpha:
                                                        0.12 + day.level * 0.16,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('少', style: TextStyle(fontSize: 10, color: _muted)),
            const SizedBox(width: 4),
            ...List.generate(
              5,
              (lvl) => Container(
                margin: const EdgeInsets.only(right: 3),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: lvl == 0
                      ? _surfaceAlt
                      : color.withValues(alpha: 0.12 + lvl * 0.16),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Text('多', style: TextStyle(fontSize: 10, color: _muted)),
          ],
        ),
      ],
    );
  }
}

// ── Edit Mode Dismissible Card ──

class _DismissibleCard extends StatelessWidget {
  final String chartId;
  final bool editMode;
  final VoidCallback onDismiss;
  final Widget child;
  const _DismissibleCard({
    required this.chartId,
    required this.editMode,
    required this.onDismiss,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim the card slightly in edit mode
        if (editMode) Opacity(opacity: 0.7, child: child) else child,
        // X button overlay in edit mode
        if (editMode)
          Positioned(
            top: 4,
            right: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _danger,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _danger.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                tooltip: '隐藏图表',
                onPressed: onDismiss,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Redesigned Frequency Chart ──

class _FrequencyChart extends StatelessWidget {
  final List<_ChartData> barData;
  final int chartMax;
  final Color color;
  final String freqUnit;
  const _FrequencyChart({
    required this.barData,
    required this.chartMax,
    required this.color,
    required this.freqUnit,
  });

  @override
  Widget build(BuildContext context) {
    final n = barData.length;
    final total = barData.fold<int>(0, (s, d) => s + d.val);
    // All time ranges now have ≤13 bars, so always use Expanded layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bar_chart_rounded, size: 18, color: _ink),
            const SizedBox(width: 8),
            const Text(
              '频率趋势',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const Spacer(),
            Text(
              '共 $total 次',
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '最高 $chartMax 次/$freqUnit',
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 16),
        // Chart
        SizedBox(
          height: 170,
          child: n == 0
              ? const Center(
                  child: Text('暂无数据', style: TextStyle(color: _muted)),
                )
              : Column(
                  children: [
                    // Bars + values
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: barData.map((d) {
                          final pct = chartMax == 0 ? 0.0 : d.val / chartMax;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: n <= 7
                                    ? 6
                                    : n <= 13
                                    ? 3
                                    : 2,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (d.val > 0)
                                    Text(
                                      '${d.val}',
                                      style: TextStyle(
                                        fontSize: n <= 7 ? 12 : 10,
                                        color: color,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  const SizedBox(height: 3),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutCubic,
                                    height: pct * 110,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          color,
                                          color.withValues(alpha: 0.4),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        n <= 7 ? 6 : 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // X-axis labels
                    Row(
                      children: barData.map((d) {
                        return Expanded(
                          child: Text(
                            d.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: n <= 7 ? 10 : 9,
                              color: _muted,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _WeekdayDist extends StatelessWidget {
  final List<int> data;
  final int max;
  final Color color;
  const _WeekdayDist({
    required this.data,
    required this.max,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    const days = ['日', '一', '二', '三', '四', '五', '六'];
    return _Card(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, size: 14),
              SizedBox(width: 6),
              Text(
                '星期分布',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            7,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    days[i],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: data[i] / max,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeDist extends StatelessWidget {
  final List<int> data;
  final int max;
  final Color color;
  const _TimeDist({required this.data, required this.max, required this.color});
  @override
  Widget build(BuildContext context) {
    const labels = ['凌晨', '上午', '下午', '晚上'];
    final icons = [
      Icons.nights_stay,
      Icons.brightness_5,
      Icons.wb_sunny,
      Icons.bedtime,
    ];
    return _Card(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time_filled, size: 14),
              SizedBox(width: 6),
              Text(
                '时段分布',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(icons[i], size: 12, color: _line),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              labels[i],
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            Text(
                              '${data[i]}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _surfaceAlt,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: data[i] / max,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AggBlock extends StatelessWidget {
  final String label, val;
  const _AggBlock(this.label, this.val);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _MinMaxBlock extends StatelessWidget {
  final String label, val;
  final bool right;
  const _MinMaxBlock(this.label, this.val, {this.right = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(
            fontSize: 16,
            color: _muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
