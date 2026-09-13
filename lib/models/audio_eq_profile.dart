class AudioEqPreset {
  final String name;
  final String description;
  // Gains from -10.0 to +10.0 dB for five abstract bands: [Low, Mid-Low, Mid, Mid-High, High]
  final List<double> gains;

  const AudioEqPreset({
    required this.name,
    required this.description,
    required this.gains,
  });

  static const List<AudioEqPreset> presets = [
    AudioEqPreset(
      name: 'Flat',
      description: 'Original sound without any equalization.',
      gains: [0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    AudioEqPreset(
      name: 'Vocal Clarity',
      description: 'Enhances speech intelligibility by boosting vocals and cutting rumble.',
      gains: [-3.0, -1.0, 3.0, 5.0, 2.0],
    ),
    AudioEqPreset(
      name: 'De-Rumble',
      description: 'Cuts low-frequency hums, mic pops, and deep background noises.',
      gains: [-8.0, -4.0, 0.0, 1.0, 0.0],
    ),
    AudioEqPreset(
      name: 'Treble Boost',
      description: 'Makes muffled or low-quality narrators sound brighter and clearer.',
      gains: [-2.0, -1.0, 1.0, 4.0, 6.0],
    ),
    AudioEqPreset(
      name: 'Warm Presence',
      description: 'Adds warmth and depth to thin or harsh-sounding voices.',
      gains: [2.0, 4.0, 1.0, -1.0, -2.0],
    ),
    AudioEqPreset(
      name: 'Metallic Tube Fix',
      description: 'Attenuates metallic echoes and hollow room resonance in the mids.',
      gains: [2.0, 1.0, -7.0, -5.0, 3.0],
    ),
  ];
}

/// 5-Band Graphic Equalizer Profile (Ticket 07).
class AudioEqProfile {
  final String presetName;
  final double band60Hz;
  final double band230Hz;
  final double band910Hz;
  final double band3600Hz;
  final double band14000Hz;

  const AudioEqProfile({
    required this.presetName,
    this.band60Hz = 0.0,
    this.band230Hz = 0.0,
    this.band910Hz = 0.0,
    this.band3600Hz = 0.0,
    this.band14000Hz = 0.0,
  });

  factory AudioEqProfile.voiceClarity() {
    return const AudioEqProfile(
      presetName: 'Voice Clarity',
      band60Hz: -3.0,
      band230Hz: -1.0,
      band910Hz: 3.0,
      band3600Hz: 5.0,
      band14000Hz: 2.0,
    );
  }
}
