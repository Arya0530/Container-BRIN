import 'package:flutter/material.dart';
import '../data.dart';
import '../widgets.dart';

class ParameterReportPage extends StatefulWidget {
  const ParameterReportPage({super.key});
  @override
  State<ParameterReportPage> createState() => _ParameterReportPageState();
}

class _ParameterReportPageState extends State<ParameterReportPage> {
  late Future<List<UiContainer>> _containersFuture;
  List<UiTelemetry> _records = [];
  UiContainer? _selected;
  String _period = 'Daily';
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;
  int _reportRequestId = 0;

  @override
  void initState() {
    super.initState();
    _containersFuture = UiApi.instance.containers();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final containers = await _containersFuture;
      if (!mounted || containers.isEmpty) return;
      setState(() => _selected = containers.first);
      await _getRecords(containers.first.id);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _getRecords(int id) async {
    final requestId = ++_reportRequestId;

    // The selected period determines the database query range.
    late final DateTime start;
    late final DateTime end;

    if (_period == 'Yearly') {
      start = DateTime(_date.year);
      end = DateTime(_date.year + 1);
    } else if (_period == 'Monthly') {
      start = DateTime(_date.year, _date.month);
      end = DateTime(_date.year, _date.month + 1);
    } else {
      start = DateTime(_date.year, _date.month, _date.day);
      end = DateTime(_date.year, _date.month, _date.day + 1);
    }

    setState(() {
      _loading = true;
      _error = null;
      _records = [];
    });

    try {
      final records = await UiApi.instance.history(id, start: start, end: end);

      if (!mounted || requestId != _reportRequestId || _selected?.id != id) {
        return;
      }

      setState(() => _records = records);
    } catch (error) {
      if (mounted && requestId == _reportRequestId) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && requestId == _reportRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  bool _inPeriod(DateTime? timestamp) {
    if (timestamp == null) return false;
    final value = timestamp.toLocal();

    if (value.year != _date.year) return false;
    if (_period == 'Yearly') return true;
    if (value.month != _date.month) return false;
    if (_period == 'Monthly') return true;
    return value.day == _date.day;
  }

  DateTime _bucketKey(DateTime timestamp) {
    final t = timestamp.toLocal();

    if (_period == 'Yearly') {
      return DateTime(t.year, t.month);
    }
    if (_period == 'Monthly') {
      return DateTime(t.year, t.month, t.day);
    }
    return DateTime(t.year, t.month, t.day, t.hour);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _monthName(int n) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[n - 1];
  }

  String _dateLabel() {
    if (_period == 'Yearly') return '${_date.year}';
    if (_period == 'Monthly') {
      return '${_monthName(_date.month)} ${_date.year}';
    }
    return '${_two(_date.day)}/${_two(_date.month)}/${_date.year}';
  }

  String _bucketLabel(DateTime key) {
    if (_period == 'Yearly') {
      return '${_monthName(key.month)} ${key.year}';
    }
    if (_period == 'Monthly') {
      return '${_two(key.day)} ${_monthName(key.month)} ${key.year}';
    }
    return '${_two(key.hour)}:00 - ${_two(key.hour)}:59';
  }

  Widget _metricText(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: brinSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 11, color: brinDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _records.where((r) => _inPeriod(r.recordedAt)).toList()
      ..sort(
        (a, b) => (b.recordedAt ?? DateTime(1970)).compareTo(
          a.recordedAt ?? DateTime(1970),
        ),
      );

    final groups = <DateTime, List<UiTelemetry>>{};
    for (final record in filtered) {
      final time = record.recordedAt;
      if (time == null) continue;
      groups.putIfAbsent(_bucketKey(time), () => []).add(record);
    }

    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return BrinPage(
      title: 'Parameter Report',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 22),
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: brinSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                for (final item in ['Daily', 'Monthly', 'Yearly'])
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _period = item);
                        final id = _selected?.id;
                        if (id != null) _getRecords(id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _period == item ? brinRed : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            color: _period == item ? Colors.white : brinRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              side: const BorderSide(color: brinBorder),
            ),
            icon: const Icon(
              Icons.calendar_today_outlined,
              color: brinRed,
              size: 17,
            ),
            label: Text(
              _dateLabel(),
              style: const TextStyle(fontSize: 12, color: brinDark),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() => _date = picked);
                final id = _selected?.id;
                if (id != null) _getRecords(id);
              }
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<UiContainer>>(
            future: _containersFuture,
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              if (items.isEmpty) return const SizedBox.shrink();

              return DropdownButtonFormField<int>(
                initialValue: _selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Container',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                items: items.map((c) {
                  return DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(
                      '${c.series} - ${c.company}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  setState(() {
                    _selected = items.firstWhere((c) => c.id == id);
                    _records = [];
                  });
                  _getRecords(id);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: brinRed)),
          if (!_loading && _error == null) ...[
            Text(
              '${filtered.length} readings in ${keys.length} '
              '${_period == 'Daily'
                  ? 'hours'
                  : _period == 'Monthly'
                  ? 'days'
                  : 'months'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: brinDark,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Showing available readings for the selected period.',
              style: TextStyle(fontSize: 10, color: brinMuted),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Center(
                  child: Text('No telemetry for the selected period.'),
                ),
              ),
            for (final key in keys) ...[
              BrinPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: brinRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _bucketLabel(key),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '${groups[key]!.length} records',
                          style: const TextStyle(
                            fontSize: 10,
                            color: brinMuted,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Text(
                      'Latest reading: '
                      '${displayTime(groups[key]!.first.recordedAt)}',
                      style: const TextStyle(fontSize: 11, color: brinMuted),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _metricText('Door', groups[key]!.first.door ?? '-'),
                        _metricText(
                          'Speed',
                          displayNumber(
                            groups[key]!.first.speed,
                            suffix: ' km/h',
                          ),
                        ),
                        _metricText(
                          'RSSI',
                          displayNumber(groups[key]!.first.rssi, places: 0),
                        ),
                        _metricText(
                          'SNR',
                          displayNumber(groups[key]!.first.snr),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}
