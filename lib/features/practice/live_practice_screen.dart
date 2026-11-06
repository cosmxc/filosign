import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../learn/category.dart';
import '../../recognizer/sign_labels.dart';
import '../../recognizer/v4_sign_recognizer.dart';
import 'live_sign_view.dart';

/// Live camera practice for one Learn category: sign anything from the
/// category; the top-3 guesses are shown live, the banner turns green when a
/// sign is matched at >= 85%.
class LivePracticeScreen extends StatefulWidget {
  final LearnCategory category;
  const LivePracticeScreen({super.key, required this.category});

  @override
  State<LivePracticeScreen> createState() => _LivePracticeScreenState();
}

class _LivePracticeScreenState extends State<LivePracticeScreen> {
  static const _teal = Color(0xFF087F73);
  late final Map<String, String> _titleByLabel = {
    for (final l in widget.category.lessons) modelLabelForLesson(l.id): l.title
  };
  bool _dominantLeft = false;
  int _resetToken = 0;
  LiveSignState? _state;
  V4SignRecognizer? _recognizer;

  /// Debug capture: ask which sign was really done, save the last few seconds
  /// of landmarks (no video) as JSON and open the share sheet.
  Future<void> _debugCapture() async {
    final rec = _recognizer;
    if (rec == null) return;
    final snapshot = rec.debugSnapshot(candidates: _titleByLabel.keys.toList());
    if ((snapshot['frames'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign first, then tap the bug button.')));
      return;
    }
    final expected = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Which sign were you doing?'),
        children: [
          for (final l in widget.category.sortedLessons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, modelLabelForLesson(l.id)),
              child: Text(l.title),
            ),
        ],
      ),
    );
    if (expected == null) return;
    snapshot['expected'] = expected;
    snapshot['guess'] = _state?.prediction.sign;
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File('${dir.path}/filosign_debug_${expected}_$stamp.json');
    await file.writeAsString(jsonEncode(snapshot));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'FiloSign debug: did "$expected", app said "${snapshot['guess']}"',
    ));
  }

  String _title(String label) =>
      label == V4SignRecognizer.noneLabel ? 'Not a sign' : (_titleByLabel[label] ?? label);

  void _again() => setState(() {
        _resetToken++;
        _state = null;
      });

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        title: Text('${widget.category.title} practice'),
        actions: [
          IconButton(
            tooltip: 'Save debug data (wrong guess)',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: _debugCapture,
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => setState(() {
              _dominantLeft = !_dominantLeft;
              _state = null;
            }),
            icon: const Icon(Icons.back_hand_outlined),
            label: Text(_dominantLeft ? 'Left hand' : 'Right hand'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          LiveSignView(
            candidates: _titleByLabel.keys.toList(),
            letters: widget.category.id == lettersCategoryId,
            dominantLeft: _dominantLeft,
            resetToken: _resetToken,
            onUpdate: (st) => setState(() => _state = st),
            onRecognizer: (r) => _recognizer = r,
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _HintCard(
              text: 'Sign any ${widget.category.title.toLowerCase()} sign'
                  ' · hands: ${s?.handCount ?? 0}',
              tip: (s != null && s.handCount > 0 && !s.bodyVisible &&
                      widget.category.id != lettersCategoryId)
                  ? 'Step back: your shoulders and face must be in view for this sign.'
                  : widget.category.id == 'months'
                      ? 'Tip: stand back so both elbows show, and turn slightly so your signing hand is visible.'
                      : null,
            ),
          ),
          if (s != null && s.top3.isNotEmpty)
            Positioned(top: 84, left: 12, child: Top3Panel(state: s, titleOf: _title)),
          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: GestureDetector(
              onTap: (s?.locked ?? false) ? _again : null,
              child: FeedbackBanner(
                sign: s?.prediction.sign == null ? null : _title(s!.prediction.sign!),
                confidence: s?.prediction.confidence ?? 0,
                locked: s?.locked ?? false,
                notRecognized: s?.notRecognized ?? false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final String text;
  final String? tip;
  const _HintCard({required this.text, this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
          if (tip != null)
            Text(tip!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Live top-3 guesses (shown for every category).
class Top3Panel extends StatelessWidget {
  final LiveSignState state;
  final String Function(String label) titleOf;
  const Top3Panel({super.key, required this.state, required this.titleOf});

  @override
  Widget build(BuildContext context) {
    final p = state.present;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top 3 · ${state.head} · ${state.latencyMs}ms',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text('hands: ${p[0] ? 'dominant' : '-'} / ${p[1] ? 'other' : '-'} · body: ${state.bodyVisible ? 'yes' : 'NO'}',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          for (var i = 0; i < state.top3.length; i++)
            Text(
              '${i + 1}. ${titleOf(state.top3[i].key)}  ${(state.top3[i].value * 100).round()}%',
              style: TextStyle(
                color: i == 0 ? const Color(0xFF5EEAD4) : Colors.white,
                fontSize: 13,
                fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}

/// Amber "Detecting..." while reading, green once a sign locks at >= 85%.
class FeedbackBanner extends StatelessWidget {
  final String? sign;
  final double confidence;
  final bool locked;
  final String lockedSubtitle;
  final bool notRecognized;
  const FeedbackBanner({
    super.key,
    required this.sign,
    required this.confidence,
    required this.locked,
    this.lockedSubtitle = 'Tap to sign again',
    this.notRecognized = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (confidence * 100).round();
    final Color color;
    final String title, subtitle;
    if (notRecognized && !locked) {
      color = Colors.blueGrey.shade600;
      title = 'Not recognized';
      subtitle = 'Do the complete sign clearly, both hands in view';
    } else if (sign == null) {
      color = const Color(0xFF153B39);
      title = 'Waiting…';
      subtitle = 'Start signing';
    } else if (locked) {
      color = Colors.green.shade600;
      title = '✓  $sign';
      subtitle = 'Matched at $pct% · $lockedSubtitle';
    } else {
      color = Colors.amber.shade800;
      title = 'Detecting…';
      subtitle = '$sign · $pct%';
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
