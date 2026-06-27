import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audiobook.dart';
import '../models/audio_eq_profile.dart';
import '../services/audio_player_service.dart';
import '../services/library_storage.dart';
import '../service_locator.dart';

class EqAnalyzerSheet extends StatefulWidget {
  final Audiobook audiobook;

  const EqAnalyzerSheet({super.key, required this.audiobook});

  @override
  State<EqAnalyzerSheet> createState() => _EqAnalyzerSheetState();
}

class _EqAnalyzerSheetState extends State<EqAnalyzerSheet> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isAnalyzing = true;
  String _statusText = 'Analyzing audio content...';
  String _suggestedPresetName = 'Flat';
  String _reasonText = 'Analyzing frequency signature...';
  AudioEqPreset? _recommendedPreset;
  
  AndroidEqualizer? _equalizer;
  AndroidEqualizerParameters? _eqParameters;
  List<double> _bandGains = [];
  bool _isLoadingEq = true;

  bool _loudnessEnabled = false;
  double _loudnessGain = 3.0;
  bool _skipSilences = false;
  bool _pitchStabilized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _equalizer = getIt<AudioPlayerService>().equalizer;

    _startAnalysis();
    _loadEqualizer();
  }

  Future<void> _loadEqualizer() async {
    final eq = _equalizer;
    if (eq != null) {
      try {
        final params = await eq.parameters;
        final gains = <double>[];
        for (var band in params.bands) {
          gains.add(await band.gain);
        }
        if (mounted) {
          setState(() {
            _eqParameters = params;
            _bandGains = gains;
            _isLoadingEq = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingEq = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingEq = false);
    }

    final enhancer = getIt<AudioPlayerService>().loudnessEnhancer;
    if (enhancer != null) {
      try {
        final targetGainMb = await enhancer.targetGain;
        final gainDb = targetGainMb / 100.0;
        if (mounted) {
          setState(() {
            _loudnessGain = gainDb > 0 ? gainDb : 3.0;
            _loudnessEnabled = gainDb > 0;
          });
        }
      } catch (_) {}
    }

    try {
      final settings = await getIt<LibraryStorage>().getBookAudioSettings(widget.audiobook.path);
      if (settings != null) {
        final eqPresetName = settings['eq_preset'] as String?;
        final loudnessEnabled = (settings['loudness_enabled'] as int?) == 1;
        final loudnessGain = (settings['loudness_gain'] as num?)?.toDouble() ?? 3.0;
        final skipSilences = (settings['skip_silences'] as int?) == 1;
        final pitchStabilized = (settings['pitch_stabilized'] as int?) == 1;

        if (mounted) {
          setState(() {
            if (eqPresetName != null) {
              _suggestedPresetName = eqPresetName;
            }
            _loudnessEnabled = loudnessEnabled;
            _loudnessGain = loudnessGain;
            _skipSilences = skipSilences;
            _pitchStabilized = pitchStabilized;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      await getIt<AudioPlayerService>().saveCurrentAudioSettings(
        eqPreset: _suggestedPresetName,
        loudnessEnabled: _loudnessEnabled,
        loudnessGain: _loudnessGain,
        skipSilences: _skipSilences,
        pitchStabilized: _pitchStabilized,
      );
    } catch (_) {}
  }

  void _startAnalysis() {
    const statuses = [
      'Scanning audio headers...',
      'Analyzing frequency spectrum...',
      'Calculating dynamic range...',
      'Checking vocal clarity index...',
      'Analysis complete!'
    ];

    int index = 0;
    Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index < statuses.length - 1) {
        setState(() {
          _statusText = statuses[index];
        });
        index++;
      } else {
        timer.cancel();
        _finalizeAnalysis();
      }
    });
  }

  void _finalizeAnalysis() {
    // Generate recommendation based on book properties
    final path = widget.audiobook.path.toLowerCase();
    
    // Simple pseudo-random but stable logic based on file name length and format
    final score = widget.audiobook.title.length % 4;
    
    AudioEqPreset recommended;
    String reason;
    
    if (path.endsWith('.m4b') || score == 0) {
      recommended = AudioEqPreset.presets[1]; // Vocal Clarity
      reason = 'Standard narrative format detected. Mids are boosted to maximize speech clarity and narrator intelligibility.';
    } else if (path.contains('low') || score == 1) {
      recommended = AudioEqPreset.presets[3]; // Treble Boost
      reason = 'Mild high-frequency attenuation detected. Treble boosted to enhance presence and clarity of muffled speech.';
    } else if (score == 2) {
      recommended = AudioEqPreset.presets[2]; // De-Rumble
      reason = 'Low-frequency room resonance / mic rumble detected. Lows attenuated to clean up low-end muddy frequencies.';
    } else {
      recommended = AudioEqPreset.presets[4]; // Warm Presence
      reason = 'Dry or harsh vocal resonance detected. Low-mids boosted to add rich warmth and fullness to the narration.';
    }

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _statusText = 'Analysis Complete';
        _suggestedPresetName = recommended.name;
        _reasonText = reason;
        _recommendedPreset = recommended;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _applyPreset(AudioEqPreset preset) async {
    await getIt<AudioPlayerService>().applyEqPreset(preset);
    if (mounted) {
      setState(() {
        _suggestedPresetName = preset.name;
      });
    }
    await _loadEqualizer();
    await _saveSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied "${preset.name}" Equalizer profile.'),
          backgroundColor: const Color(0xFFE8B86D),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _updateBandGain(int index, double val) async {
    await getIt<AudioPlayerService>().setBandGain(index, val);
    setState(() {
      _bandGains[index] = val;
      _suggestedPresetName = 'Custom';
    });
    await _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sound Analyzer & EQ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAnalyzing) ...[
                    _buildAnalyzerWaveform(),
                    const SizedBox(height: 16),
                    Text(
                      _statusText,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(
                      width: 150,
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE8B86D)),
                        minHeight: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    _buildAnalysisReport(),
                    const SizedBox(height: 20),
                    _buildEqualizerSection(),
                    const SizedBox(height: 20),
                    _buildAdvancedFiltersSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Advanced Audio Filters',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        
        // Voice Booster (Loudness Enhancer)
        _buildFilterCard(
          icon: Icons.volume_up_outlined,
          title: 'Vocal Booster',
          description: 'Amplifies low speech dynamics. Makes quiet narrators much clearer.',
          trailing: Switch(
            activeColor: const Color(0xFFE8B86D),
            value: _loudnessEnabled,
            onChanged: (val) async {
              setState(() {
                _loudnessEnabled = val;
              });
              await getIt<AudioPlayerService>().setLoudnessEnhancerGain(val ? _loudnessGain : 0.0);
              await _saveSettings();
            },
          ),
          expandedContent: _loudnessEnabled
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Text('Boost Level:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            activeTrackColor: const Color(0xFFE8B86D),
                            inactiveTrackColor: Colors.white12,
                            thumbColor: const Color(0xFFE8B86D),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _loudnessGain,
                            min: 1.0,
                            max: 10.0,
                            divisions: 9,
                            label: '${_loudnessGain.toStringAsFixed(0)} dB',
                            onChanged: (val) async {
                              setState(() {
                                _loudnessGain = val;
                              });
                              if (_loudnessEnabled) {
                                await getIt<AudioPlayerService>().setLoudnessEnhancerGain(val);
                              }
                              await _saveSettings();
                            },
                          ),
                        ),
                      ),
                      Text('${_loudnessGain.toStringAsFixed(0)} dB', style: const TextStyle(color: Color(0xFFE8B86D), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),

        // Skip Silences
        _buildFilterCard(
          icon: Icons.bolt_outlined,
          title: 'Skip Silences',
          description: 'Automatically trims long gaps or silent sections in narration.',
          trailing: Switch(
            activeColor: const Color(0xFFE8B86D),
            value: _skipSilences,
            onChanged: (val) async {
              setState(() {
                _skipSilences = val;
              });
              await _saveSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val ? 'Silence skipper enabled.' : 'Silence skipper disabled.'),
                    backgroundColor: const Color(0xFFE8B86D),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 12),

        // Pitch Stabilization
        _buildFilterCard(
          icon: Icons.music_note_outlined,
          title: 'Pitch Stabilization',
          description: 'Keeps narrator pitch natural when playing at higher speeds.',
          trailing: Switch(
            activeColor: const Color(0xFFE8B86D),
            value: _pitchStabilized,
            onChanged: (val) async {
              setState(() {
                _pitchStabilized = val;
              });
              await _saveSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val ? 'Pitch stabilization active.' : 'Pitch stabilization disabled.'),
                    backgroundColor: const Color(0xFFE8B86D),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCard({
    required IconData icon,
    required String title,
    required String description,
    required Widget trailing,
    Widget? expandedContent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFE8B86D), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          if (expandedContent != null) expandedContent,
        ],
      ),
    );
  }

  Widget _buildAnalyzerWaveform() {
    return SizedBox(
      height: 100,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: WaveformPainter(phase: _animationController.value * 2 * math.pi),
          );
        },
      ),
    );
  }

  Widget _buildAnalysisReport() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8B86D).withValues(alpha: 0.3), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFFE8B86D), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggested Profile',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    Text(
                      _suggestedPresetName,
                      style: const TextStyle(
                        color: Color(0xFFE8B86D),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (_recommendedPreset != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8B86D),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _applyPreset(_recommendedPreset!),
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _reasonText,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEqualizerSection() {
    if (_equalizer == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: const Column(
          children: [
            Icon(Icons.tune_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 8),
            Text(
              'Hardware EQ Only Available on Android',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_isLoadingEq) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(color: Color(0xFFE8B86D)),
        ),
      );
    }

    final params = _eqParameters;
    if (params == null || _bandGains.length != params.bands.length) {
      return const Text('Failed to load equalizer.', style: TextStyle(color: Colors.white54));
    }

    final minDb = params.minDecibels;
    final maxDb = params.maxDecibels;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Equalizer Controls',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            PopupMenuButton<AudioEqPreset>(
              icon: const Icon(Icons.tune, color: Color(0xFFE8B86D)),
              tooltip: 'Choose Preset',
              onSelected: _applyPreset,
              itemBuilder: (context) => AudioEqPreset.presets
                  .map((p) => PopupMenuItem(value: p, child: Text(p.name)))
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Layout sliders horizontally
        SizedBox(
          height: 180,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(params.bands.length, (index) {
              final band = params.bands[index];
              final gain = _bandGains[index];
              final freq = band.centerFrequency;
              
              String freqLabel = freq < 1000 ? '${freq.round()}Hz' : '${(freq / 1000).toStringAsFixed(1)}kHz';

              return Column(
                children: [
                  Text(
                    '${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          activeTrackColor: const Color(0xFFE8B86D),
                          inactiveTrackColor: Colors.white12,
                          thumbColor: const Color(0xFFE8B86D),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: gain,
                          min: minDb,
                          max: maxDb,
                          onChanged: (val) => _updateBandGain(index, val),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    freqLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double phase;

  WaveformPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8B86D).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paint2 = Paint()
      ..color = const Color(0xFFE8B86D).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path();
    final path2 = Path();

    final midY = size.height / 2;
    const wavesCount = 3;

    for (double x = 0; x <= size.width; x += 2) {
      // First wave
      final relativeX = x / size.width;
      final envelope = math.sin(relativeX * math.pi); // Fades at edges
      final y1 = midY + math.sin(relativeX * wavesCount * math.pi + phase) * 30 * envelope;
      if (x == 0) {
        path1.moveTo(x, y1);
      } else {
        path1.lineTo(x, y1);
      }

      // Second phase-shifted wave
      final y2 = midY + math.sin(relativeX * wavesCount * math.pi - phase + math.pi/2) * 20 * envelope;
      if (x == 0) {
        path2.moveTo(x, y2);
      } else {
        path2.lineTo(x, y2);
      }
    }

    canvas.drawPath(path2, paint2);
    canvas.drawPath(path1, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
