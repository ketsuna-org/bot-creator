import 'dart:async';

import 'package:bot_creator/utils/bot.dart';
import 'package:flutter/material.dart';

class BotStatsPage extends StatefulWidget {
  const BotStatsPage({super.key});

  @override
  State<BotStatsPage> createState() => _BotStatsPageState();
}

class _BotStatsPageState extends State<BotStatsPage> {
  static const int _maxPoints = 40;

  final List<double> _ramHistory = <double>[];
  final List<double> _ramEstimatedHistory = <double>[];
  final List<double> _cpuHistory = <double>[];
  final List<double> _storageHistory = <double>[];

  StreamSubscription<int?>? _rssSub;
  StreamSubscription<int?>? _rssEstimatedSub;
  StreamSubscription<double?>? _cpuSub;
  StreamSubscription<int?>? _storageSub;

  int? _rssBytes;
  int? _rssEstimatedBytes;
  double? _cpuPercent;
  int? _storageBytes;

  @override
  void initState() {
    super.initState();
    captureBotBaselineRss(force: false);
    _rssBytes = getBotProcessRssBytes();
    _rssEstimatedBytes = getBotEstimatedRssBytes();
    _cpuPercent = getBotProcessCpuPercent();
    _storageBytes = getBotProcessStorageBytes();

    unawaited(refreshBotStatsNow());

    _pushMetric(_ramHistory, _rssBytes?.toDouble());
    _pushMetric(_ramEstimatedHistory, _rssEstimatedBytes?.toDouble());
    _pushMetric(_cpuHistory, _cpuPercent);
    _pushMetric(_storageHistory, _storageBytes?.toDouble());

    _rssSub = getBotProcessRssStream().listen((value) {
      if (!mounted) return;
      setState(() {
        _rssBytes = value;
        _pushMetric(_ramHistory, value?.toDouble());
      });
    });

    _rssEstimatedSub = getBotEstimatedRssStream().listen((value) {
      if (!mounted) return;
      setState(() {
        _rssEstimatedBytes = value;
        _pushMetric(_ramEstimatedHistory, value?.toDouble());
      });
    });

    _cpuSub = getBotProcessCpuStream().listen((value) {
      if (!mounted) return;
      setState(() {
        _cpuPercent = value;
        _pushMetric(_cpuHistory, value);
      });
    });

    _storageSub = getBotProcessStorageStream().listen((value) {
      if (!mounted) return;
      setState(() {
        _storageBytes = value;
        _pushMetric(_storageHistory, value?.toDouble());
      });
    });
  }

  @override
  void dispose() {
    _rssSub?.cancel();
    _rssEstimatedSub?.cancel();
    _cpuSub?.cancel();
    _storageSub?.cancel();
    super.dispose();
  }

  void _pushMetric(List<double> target, double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return;
    }
    target.add(value);
    if (target.length > _maxPoints) {
      target.removeAt(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bot Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MetricCard(
            title: 'RAM process bot',
            value: _formatBytes(_rssBytes),
            icon: Icons.memory,
            history: _ramHistory,
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'RAM bot only (estimée)',
            value: _formatBytes(_rssEstimatedBytes),
            icon: Icons.auto_graph,
            history: _ramEstimatedHistory,
            subtitle: _formatBaselineText(),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'CPU process bot',
            value: _formatCpu(_cpuPercent),
            icon: Icons.speed,
            history: _cpuHistory,
          ),
          const SizedBox(height: 12),
          _MetricCard(
            title: 'Stockage bot (app data)',
            value: _formatBytes(_storageBytes),
            icon: Icons.storage,
            history: _storageHistory,
          ),
          const SizedBox(height: 20),
          Text(
            'Notes: CPU dispo sur Android/Linux. Stockage = fichiers de données du bot dans l’app.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes < 0) {
      return 'N/A';
    }

    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  String _formatCpu(double? cpu) {
    if (cpu == null || cpu.isNaN || cpu.isInfinite) {
      return 'N/A';
    }
    return '${cpu.toStringAsFixed(1)} %';
  }

  String? _formatBaselineText() {
    final baseline = getBotBaselineRssBytes();
    if (baseline == null) {
      return null;
    }
    final capturedAt = getBotBaselineCapturedAt();
    final time =
        capturedAt == null
            ? ''
            : ' • ${capturedAt.hour.toString().padLeft(2, '0')}:${capturedAt.minute.toString().padLeft(2, '0')}:${capturedAt.second.toString().padLeft(2, '0')}';
    return 'Baseline: ${_formatBytes(baseline)}$time';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.history,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final List<double> history;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(height: 40, child: _Sparkline(values: history)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Container(
        alignment: Alignment.centerLeft,
        child: Text('Collecte…', style: Theme.of(context).textTheme.labelSmall),
      );
    }

    return CustomPaint(
      painter: _SparklinePainter(
        values: values,
        color: Theme.of(context).colorScheme.primary,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final norm = (values[i] - minV) / range;
      final y = size.height - (norm * (size.height - 2)) - 1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final area =
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();

    final fillPaint =
        Paint()
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;
    canvas.drawPath(area, fillPaint);

    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
