import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';

enum TimeSpan { oneWeek, oneMonth, threeMonths, oneYear, all }

class AnalyticsScreen extends StatefulWidget {
  final String eventId;
  const AnalyticsScreen({super.key, required this.eventId});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  TimeSpan _timeSpan = TimeSpan.all;
  
  bool _isInit = true;

  @override
  Widget build(BuildContext context) {
    final data = DataScope.of(context);
    final event = data.events.firstWhere((e) => e.id == widget.eventId, orElse: () => EventTemplate(
        id: '', name: '', icon: '', color: '#000000', createdAt: 0, customFields: []));

    if (event.id.isEmpty) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: Text('加载中...')));
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
    final isMonthly = _timeSpan == TimeSpan.oneYear || _timeSpan == TimeSpan.all;
    final barData = <_ChartData>[];
    int chartMax = 1;
    int maxPerDay = 1;
    final activeDaysSet = <String>{};

    for (var r in filteredRecords) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      activeDaysSet.add('${d.year}-${d.month}-${d.day}');
    }

    if (isMonthly) {
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
    } else {
      final counts = <String, int>{};
      for (var r in filteredRecords) {
        final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        final k = '${d.year}-${d.month}-${d.day}';
        counts[k] = (counts[k] ?? 0) + 1;
      }
      for (final v in counts.values) {
        if (v > maxPerDay) maxPerDay = v;
      }
      final days = _timeSpan == TimeSpan.oneWeek ? 7 : _timeSpan == TimeSpan.oneMonth ? 30 : 90;
      for (int i = days - 1; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final val = counts['${d.year}-${d.month}-${d.day}'] ?? 0;
        barData.add(_ChartData('${d.day}', val));
        if (val > chartMax) chartMax = val;
      }
    }
    
    // 3. Heatmap Data (15 weeks)
    final heatmapData = <_HeatmapDay>[];
    final w15 = 15 * 7;
    final hmCounts = <String, int>{};
    for (var r in filteredRecords) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      hmCounts['${d.year}-${d.month}-${d.day}'] = (hmCounts['${d.year}-${d.month}-${d.day}'] ?? 0) + 1;
    }
    for (int i = w15 - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final val = hmCounts['${d.year}-${d.month}-${d.day}'] ?? 0;
      heatmapData.add(_HeatmapDay(date: d, count: val, level: val == 0 ? 0 : val < 3 ? 1 : val < 5 ? 2 : val < 8 ? 3 : 4));
    }

    // 4. Time Distribs (Weekday / TimeOfDay)
    final wData = List.filled(7, 0);
    final tData = List.filled(4, 0);
    for (var r in filteredRecords) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      // Weekday (0=Sun..6=Sat)
      wData[d.weekday % 7]++;
      // Time block
      if (d.hour < 6) tData[0]++;
      else if (d.hour < 12) tData[1]++;
      else if (d.hour < 18) tData[2]++;
      else tData[3]++;
    }
    final wMax = wData.reduce((a,b)=>a>b?a:b).clamp(1, 9999);
    final tMax = tData.reduce((a,b)=>a>b?a:b).clamp(1, 9999);

    // 5. Field Aggregations & Frequencies
    final aggs = <String, _FieldAgg>{};
    for (var f in event.customFields) {
      if ([FieldType.number, FieldType.duration, FieldType.cost].contains(f.type)) {
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
        aggs[f.id] = _FieldAgg(numSum: sum, numAvg: count>0?sum/count:0, numMax: count>0?maxVal:0, numMin: count>0?minVal:0, count: count, topFreqs: []);
      } else if (f.type == FieldType.category || f.type == FieldType.text || f.type == FieldType.singleSelect) {
        final cMap = <String, int>{};
        int count = 0;
        for (var r in filteredRecords) {
          final v = r.fieldValues[f.id];
          if (v is String && v.trim().isNotEmpty) {
            cMap[v] = (cMap[v] ?? 0) + 1;
            count++;
          }
        }
        final freqs = cMap.entries.map((e) => _Freq(e.key, e.value)).toList()..sort((a,b) => b.count.compareTo(a.count));
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
        final freqs = cMap.entries.map((e) => _Freq(e.key, e.value)).toList()..sort((a,b) => b.count.compareTo(a.count));
        aggs[f.id] = _FieldAgg(count: count, topFreqs: freqs.take(8).toList());
      } else if (f.type == FieldType.toggle) {
        int trueCount = 0;
        int falseCount = 0;
        for (var r in filteredRecords) {
          final v = r.fieldValues[f.id];
          if (v == true) trueCount++;
          else falseCount++;
        }
        aggs[f.id] = _FieldAgg(
          count: trueCount + falseCount,
          topFreqs: [
            _Freq('是', trueCount),
            _Freq('否', falseCount),
          ],
          numSum: trueCount.toDouble(),
          numAvg: (trueCount + falseCount) > 0 ? trueCount / (trueCount + falseCount) : 0,
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
        for (var s in tagSums.values) totalSum += s;
        final freqs = tagSums.entries.map((e) => _Freq('${e.key} (${e.value.round()}${f.unit})', tagCounts[e.key] ?? 0)).toList()
          ..sort((a, b) => b.count.compareTo(a.count));
        aggs[f.id] = _FieldAgg(
          count: tagCounts.values.fold(0, (a, b) => a + b),
          topFreqs: freqs.take(10).toList(),
          numSum: totalSum,
          numAvg: freqs.isNotEmpty ? totalSum / filteredRecords.where((r) => r.fieldValues[f.id] is Map && (r.fieldValues[f.id] as Map).isNotEmpty).length.clamp(1, 999999) : 0,
        );
      }
    }

    // 6. Cross Analysis Pivot Table
    _CrossPivot? pivot;
    final catF = event.customFields.where((e) => e.type == FieldType.category || e.type == FieldType.text || e.type == FieldType.singleSelect).firstOrNull;
    final numF = event.customFields.where((e) => [FieldType.number, FieldType.duration, FieldType.cost].contains(e.type)).firstOrNull;
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
        final s = e.value.reduce((a,b)=>a+b);
        return _PivotRow(e.key, s, s / e.value.length);
      }).toList()..sort((a,b) => b.sum.compareTo(a.sum));
      if (rows.isNotEmpty) {
        pivot = _CrossPivot(catF.name, numF.name, numF.type, rows.take(10).toList());
      }
    }

    final color = hexToColor(event.color);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () => _confirmDelete(event.id),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.dark,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (event.icon.isNotEmpty && event.icon.characters.length == 1)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(event.icon, style: const TextStyle(fontSize: 32)),
                        ),
                      Expanded(
                        child: Text(event.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _TimeSpanSelector(val: _timeSpan, onSelect: (v) => setState(() => _timeSpan = v), color: color),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _TopStat(label: '打卡次数', val: '${filteredRecords.length}', unit: '次', color: color)),
                      Expanded(child: _TopStat(label: '活跃天数', val: '${activeDaysSet.length}', unit: '天', color: color)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Bar chart
                if (filteredRecords.isNotEmpty)
                  _Card(
                    color: color,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bar_chart, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text('频率趋势', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 180,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: barData.map((d) {
                              final pct = chartMax == 0 ? 0.0 : d.val / chartMax;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (d.val > 0)
                                        Text('${d.val}', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      Container(
                                        height: pct * 120,
                                        width: 12,
                                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(d.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Heatmap
                if (filteredRecords.isNotEmpty)
                  _Card(
                    color: color,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_month, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text('打卡热力图', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _HeatmapGrid(data: heatmapData, color: color),
                      ],
                    ),
                  ),

                // Weekday / Time
                if (filteredRecords.isNotEmpty)
                  Row(
                    children: [
                      Expanded(child: _WeekdayDist(data: wData, max: wMax, color: color)),
                      const SizedBox(width: 14),
                      Expanded(child: _TimeDist(data: tData, max: tMax, color: color)),
                    ],
                  ),
                
                const SizedBox(height: 14),

                // Field Aggs
                ...event.customFields.map((f) {
                  final agg = aggs[f.id];
                  if (agg == null || agg.count == 0) return const SizedBox.shrink();
                  if (f.type == FieldType.notes) return const SizedBox.shrink();
                  
                  return _Card(
                    color: color,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: Icon(
                                f.type == FieldType.category ? Icons.place : 
                                f.type == FieldType.cost ? Icons.attach_money : 
                                f.type == FieldType.duration ? Icons.schedule :
                                f.type == FieldType.singleSelect ? Icons.radio_button_checked :
                                f.type == FieldType.multiSelect ? Icons.checklist :
                                f.type == FieldType.toggle ? Icons.toggle_on :
                                f.type == FieldType.taggedValues ? Icons.sell : Icons.tag,
                                color: color, size: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('${f.name} 分析', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (f.type == FieldType.category || f.type == FieldType.text || f.type == FieldType.singleSelect || f.type == FieldType.multiSelect || f.type == FieldType.taggedValues)
                          ...agg.topFreqs.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                SizedBox(width: 24, child: Text('${e.key + 1}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: e.key < 3 ? color : AppColors.textLight))),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.value.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      const SizedBox(height: 4),
                                      Container(
                                        height: 6, width: double.infinity,
                                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(3)),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: e.value.count / agg.topFreqs.first.count,
                                          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('${e.value.count} 次', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                              ],
                            ),
                          )).toList()
                        else if (f.type == FieldType.toggle) ...[
                          // Toggle ratio display
                          Builder(builder: (_) {
                            final trueCount = agg.topFreqs.isNotEmpty ? agg.topFreqs[0].count : 0;
                            final falseCount = agg.topFreqs.length > 1 ? agg.topFreqs[1].count : 0;
                            final total = trueCount + falseCount;
                            final pct = total > 0 ? (trueCount / total * 100).round() : 0;
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Text('$pct%', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: color)),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('是: $trueCount 次', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                        const SizedBox(height: 2),
                                        Text('否: $falseCount 次', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 8, width: double.infinity,
                                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(4)),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: total > 0 ? trueCount / total : 0,
                                    child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ]
                        else ...[
                          Row(
                            children: [
                              Expanded(child: _AggBlock('累计总计', _fmt(agg.numSum, f.type, f.unit))),
                              const SizedBox(width: 8),
                              Expanded(child: _AggBlock('平均每次', _fmt(agg.numAvg, f.type, f.unit))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(height: 1, color: AppColors.bg),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _MinMaxBlock('单次最高', _fmt(agg.numMax, f.type, f.unit)),
                              _MinMaxBlock('单次最低', _fmt(agg.numMin, f.type, f.unit), right: true),
                            ],
                          ),
                        ]
                      ],
                    ),
                  );
                }).toList(),

                // Cross Pivot
                if (pivot != null)
                  _Card(
                    color: color,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, color: color, size: 18),
                            const SizedBox(width: 8),
                            const Text('多维透视分析', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('按「${pivot.catName}」统计「${pivot.numName}」', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('分类', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted))),
                                    Expanded(flex: 2, child: Text('总计', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted))),
                                    Expanded(flex: 2, child: Text('均次', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted))),
                                  ],
                                ),
                              ),
                              Container(height: 1, color: AppColors.cardBorder),
                              ...pivot.rows.asMap().entries.map((e) {
                                final r = e.value;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: e.key > 0 ? const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cardBorder))) : null,
                                  child: Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                      Expanded(flex: 2, child: Text(_fmt(r.sum, pivot!.numType, ''), textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color))),
                                      Expanded(flex: 2, child: Text(_fmt(r.avg, pivot!.numType, ''), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Records list
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 16, 4, 10),
                  child: Text('最新打卡', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ),
                ...filteredRecords.take(15).map((r) {
                  final d = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
                  final timeStr = DateFormat('MM-dd HH:mm').format(d);
                  
                  final summaries = <String>[];
                  for (var f in event.customFields) {
                    final v = r.fieldValues[f.id];
                    if (v == null || f.type == FieldType.notes) continue;
                    if (f.type == FieldType.toggle) {
                      summaries.add(v == true ? '✅ ${f.name}' : '❌ ${f.name}');
                    } else if (f.type == FieldType.multiSelect && v is List) {
                      if (v.isNotEmpty) summaries.add(v.join(', '));
                    } else if (f.type == FieldType.taggedValues && v is Map) {
                      final parts = v.entries.map((e) => '${e.key}:${e.value}${f.unit}').toList();
                      if (parts.isNotEmpty) summaries.add(parts.join(' · '));
                    } else if (f.type == FieldType.singleSelect || f.type == FieldType.category) {
                      if (v is String && v.isNotEmpty) summaries.add(v);
                    } else if (v is num) {
                      summaries.add(_fmt(v, f.type, f.unit));
                    } else if (v is String && v.isNotEmpty) {
                      summaries.add(v);
                    }
                  }
                  final noteField = event.customFields.where((f) => f.type == FieldType.notes).firstOrNull;
                  final noteStr = noteField != null ? (r.fieldValues[noteField.id] as String? ?? '') : '';

                  return Container(
                     margin: const EdgeInsets.only(bottom: 12),
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.cardBorder)),
                     child: Row(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
                           child: Text(timeStr.split(' ')[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(timeStr.split(' ')[1], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                               if (summaries.isNotEmpty) ...[
                                 const SizedBox(height: 4),
                                 Text(summaries.join(' · '), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                               ],
                               if (noteStr.isNotEmpty) ...[
                                 const SizedBox(height: 6),
                                 Text(noteStr, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                               ],
                             ],
                           ),
                         ),
                         GestureDetector(
                           onTap: () => DataScope.of(context).deleteRecord(r.id).then((_) => setState((){})),
                           child: const Padding(
                             padding: EdgeInsets.only(left: 8),
                             child: Icon(Icons.delete, size: 16, color: AppColors.textLight),
                           ),
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
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除项目'),
        content: const Text('确定要删除该项目及其所有打卡记录吗？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              DataScope.of(context).deleteEvent(id);
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  String _fmt(num v, FieldType t, String u) {
    if (v == 0) return '0';
    if (t == FieldType.duration) {
      if (v < 60) return '${v.round()}分钟';
      return '${v~/60}小时${(v%60).round() > 0 ? "${(v%60).round()}分" : ""}';
    }
    if (t == FieldType.cost) return '¥${v.toStringAsFixed(1)}';
    String s = v.truncate() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return u.isNotEmpty ? '$s$u' : s;
  }
}

// ── Models ──
class _ChartData { final String label; final int val; _ChartData(this.label, this.val); }
class _HeatmapDay { final DateTime date; final int count; final int level; _HeatmapDay({required this.date, required this.count, required this.level}); }
class _Freq { final String label; final int count; _Freq(this.label, this.count); }
class _FieldAgg { final num numSum, numAvg, numMax, numMin; final int count; final List<_Freq> topFreqs; _FieldAgg({this.numSum=0, this.numAvg=0, this.numMax=0, this.numMin=0, required this.count, required this.topFreqs}); }
class _PivotRow { final String label; final num sum, avg; _PivotRow(this.label, this.sum, this.avg); }
class _CrossPivot { final String catName, numName; final FieldType numType; final List<_PivotRow> rows; _CrossPivot(this.catName, this.numName, this.numType, this.rows); }

// ── Components ──

class _TimeSpanSelector extends StatelessWidget {
  final TimeSpan val;
  final ValueChanged<TimeSpan> onSelect;
  final Color color;
  const _TimeSpanSelector({required this.val, required this.onSelect, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.darkSoft, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Btn('1周', TimeSpan.oneWeek),
            _Btn('1月', TimeSpan.oneMonth),
            _Btn('3月', TimeSpan.threeMonths),
            _Btn('1年', TimeSpan.oneYear),
            _Btn('全部', TimeSpan.all),
          ],
        ),
      ),
    );
  }

  Widget _Btn(String label, TimeSpan t) {
    final sel = val == t;
    return GestureDetector(
      onTap: () => onSelect(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: sel ? color : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class _TopStat extends StatelessWidget {
  final String label, val, unit;
  final Color color;
  const _TopStat({required this.label, required this.val, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(val, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Color color;
  final Widget child;
  const _Card({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.cardBorder), boxShadow: AppShadows.sm),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 4, color: color),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
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
    return SizedBox(
      height: 120,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: List.generate(data.length ~/ 7, (wIdx) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                children: List.generate(7, (dIdx) {
                  final day = data[wIdx * 7 + (6 - dIdx)]; // Stack vertically 0-6
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: day.level == 0 ? AppColors.bg : color.withOpacity(day.level * 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _WeekdayDist extends StatelessWidget {
  final List<int> data; final int max; final Color color;
  const _WeekdayDist({required this.data, required this.max, required this.color});
  @override
  Widget build(BuildContext context) {
    const days = ['日','一','二','三','四','五','六'];
    return _Card(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [ Icon(Icons.show_chart, size: 14), SizedBox(width: 6), Text('星期分布', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 16),
          ...List.generate(7, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(days[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 4, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(2)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: data[i]/max, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)))))),
              ],
            ),
          )),
        ],
      )
    );
  }
}

class _TimeDist extends StatelessWidget {
  final List<int> data; final int max; final Color color;
  const _TimeDist({required this.data, required this.max, required this.color});
  @override
  Widget build(BuildContext context) {
    const labels = ['凌晨','上午','下午','晚上'];
    final icons = [Icons.nights_stay, Icons.brightness_5, Icons.wb_sunny, Icons.bedtime];
    return _Card(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [ Icon(Icons.access_time_filled, size: 14), SizedBox(width: 6), Text('时段分布', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 16),
          ...List.generate(4, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(icons[i], size: 12, color: AppColors.textLight),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(labels[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textPrimary)), Text('${data[i]}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted))]),
                    const SizedBox(height: 4),
                    Container(height: 4, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(2)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: data[i]/max, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))))),
                  ],
                )),
              ],
            ),
          )),
        ],
      )
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
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _MinMaxBlock extends StatelessWidget {
  final String label, val;
  final bool right;
  const _MinMaxBlock(this.label, this.val, {this.right=false});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
