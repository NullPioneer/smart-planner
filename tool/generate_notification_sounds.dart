import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 44100;

void main() {
  final output = Directory('assets/notification_sounds/raw')
    ..createSync(recursive: true);

  _writeWav(
    File('${output.path}/gentle_chime.wav'),
    durationSeconds: .58,
    sampleAt: (time) {
      final first = _ping(time, start: 0, frequency: 880, decay: 7.2);
      final second = _ping(time, start: .14, frequency: 1174.66, decay: 8.4);
      return .66 * first + .72 * second;
    },
    peak: .88,
  );

  _writeWav(
    File('${output.path}/bright_bell.wav'),
    durationSeconds: .42,
    sampleAt: (time) {
      final fundamental = _ping(
        time,
        start: 0,
        frequency: 1318.51,
        decay: 10.5,
      );
      final shimmer = _ping(time, start: 0, frequency: 2637.02, decay: 15);
      final strike = _ping(time, start: 0, frequency: 3520, decay: 21);
      return .76 * fundamental + .32 * shimmer + .20 * strike;
    },
    peak: .94,
  );
}

double _ping(
  double time, {
  required double start,
  required double frequency,
  required double decay,
}) {
  final elapsed = time - start;
  if (elapsed < 0) return 0;
  final attack = (elapsed / .006).clamp(0.0, 1.0);
  return math.sin(2 * math.pi * frequency * elapsed) *
      attack *
      math.exp(-decay * elapsed);
}

void _writeWav(
  File file, {
  required double durationSeconds,
  required double Function(double time) sampleAt,
  required double peak,
}) {
  final sampleCount = (durationSeconds * _sampleRate).round();
  final samples = List<double>.generate(
    sampleCount,
    (index) => sampleAt(index / _sampleRate),
    growable: false,
  );
  final maximum = samples.fold<double>(0, (value, sample) {
    final magnitude = sample.abs();
    return magnitude > value ? magnitude : value;
  });
  final scale = maximum == 0 ? 0.0 : peak / maximum;
  const bytesPerSample = 2;
  final dataLength = sampleCount * bytesPerSample;
  final bytes = ByteData(44 + dataLength);

  void ascii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, _sampleRate, Endian.little);
  bytes.setUint32(28, _sampleRate * bytesPerSample, Endian.little);
  bytes.setUint16(32, bytesPerSample, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);

  for (var index = 0; index < samples.length; index++) {
    final value = (samples[index] * scale * 32767).round().clamp(-32768, 32767);
    bytes.setInt16(44 + index * bytesPerSample, value, Endian.little);
  }

  file.writeAsBytesSync(bytes.buffer.asUint8List(), flush: true);
}
