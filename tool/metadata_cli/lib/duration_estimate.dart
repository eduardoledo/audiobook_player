import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';

import 'package:audio_meta/audio_meta.dart';
import 'package:path/path.dart' as p;

import 'path_metadata.dart';

const _chunkBytes = 1024 * 1024; // 1 MiB
const _defaultConcurrency = 6;

/// Fast duration estimate: only reads header (+ MP4 atom seeks for M4B), in parallel.
Future<String> estimateDurationFormatted(
  List<String> audioFiles, {
  int concurrency = _defaultConcurrency,
}) async {
  final seconds = await estimateDurationSecondsList(
    audioFiles,
    concurrency: concurrency,
  );
  final total = seconds.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return '00:00:00.000';
  return formatDuration(total);
}

/// Per-file duration estimates (seconds), same order as [audioFiles].
Future<List<double>> estimateDurationSecondsList(
  List<String> audioFiles, {
  int concurrency = _defaultConcurrency,
}) async {
  if (audioFiles.isEmpty) return const [];

  final seconds = List<double>.filled(audioFiles.length, 0);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= audioFiles.length) return;
      seconds[i] = await _durationSeconds(audioFiles[i]);
    }
  }

  final workers = List.generate(
    min(concurrency, audioFiles.length),
    (_) => worker(),
  );
  await Future.wait(workers);
  return seconds;
}

Future<double> _durationSeconds(String path) async {
  try {
    final file = File(path);
    final fileSize = await file.length();
    if (fileSize <= 0) return 0;

    final ext = p.extension(path).toLowerCase();

    // M4B/M4A: walk atoms with seeks. Never feed AudioMeta a head+tail splice —
    // large moov atoms (often several MiB at EOF) made that hang.
    if (ext == '.m4b' || ext == '.m4a' || ext == '.mp4' || ext == '.aac') {
      final mp4 = await parseMp4DurationSeconds(file, fileSize);
      if (mp4 != null && mp4 > 0) return mp4;
      return 0;
    }

    final bytes = await _readMetadataBytes(file, fileSize);

    if (ext == '.mp3') {
      final mp3 = _parseMp3Duration(bytes, fileSize);
      if (mp3 != null) return mp3.inMilliseconds / 1000.0;
    }

    final meta = AudioMeta(bytes);
    var duration = meta.duration;
    // AudioMeta may use buffer length for CBR; correct with real file size.
    if (bytes.length < fileSize && meta.bitRate > 0) {
      duration = Duration(
        milliseconds: (fileSize * 8 * 1000) ~/ meta.bitRate,
      );
    }
    return duration.inMilliseconds / 1000.0;
  } catch (_) {
    return 0;
  }
}

/// Reads MP4/M4B duration from the `mvhd` atom via lightweight seeks.
///
/// Skips `mdat` without loading it. Works when `moov` is large and at EOF
/// (common for audiobook `.m4b` files).
///
/// Uses synchronous RAF I/O so header walks cannot trip
/// "async operation is currently pending" on some filesystems.
Future<double?> parseMp4DurationSeconds(File file, int fileSize) async {
  return Future(() => _parseMp4DurationSecondsSync(file, fileSize));
}

double? _parseMp4DurationSecondsSync(File file, int fileSize) {
  final raf = file.openSync(mode: FileMode.read);
  try {
    Uint8List readAt(int start, int length) {
      if (length <= 0 || start < 0 || start >= fileSize) {
        return Uint8List(0);
      }
      final n = min(length, fileSize - start);
      raf.setPositionSync(start);
      return raf.readSync(n);
    }

    ({int size, String type, int header})? readHeader(int pos) {
      if (pos + 8 > fileSize) return null;
      final hdr = readAt(pos, 8);
      if (hdr.length < 8) return null;
      var size = ByteData.sublistView(hdr).getUint32(0);
      final type = String.fromCharCodes(hdr.sublist(4, 8));
      var header = 8;
      if (size == 1) {
        if (pos + 16 > fileSize) return null;
        final wide = readAt(pos + 8, 8);
        if (wide.length < 8) return null;
        size = ByteData.sublistView(wide).getUint64(0);
        header = 16;
      } else if (size == 0) {
        size = fileSize - pos;
      }
      if (size < header) return null;
      return (size: size, type: type, header: header);
    }

    double? parseMvhd(int atomPos, int atomSize, int header) {
      final bodyLen = min(atomSize - header, 32);
      if (bodyLen < 20) return null;
      final body = readAt(atomPos + header, bodyLen);
      if (body.length < 20) return null;
      final version = body[0];
      final bd = ByteData.sublistView(body);
      late final int timescale;
      late final int duration;
      if (version == 1) {
        if (body.length < 32) return null;
        timescale = bd.getUint32(20);
        duration = bd.getUint64(24);
      } else {
        timescale = bd.getUint32(12);
        duration = bd.getUint32(16);
      }
      if (timescale <= 0 || duration <= 0) return null;
      return duration / timescale;
    }

    var pos = 0;
    var guards = 0;
    while (pos + 8 <= fileSize && guards++ < 64) {
      final atom = readHeader(pos);
      if (atom == null || atom.size <= 0) break;

      if (atom.type == 'moov') {
        var child = pos + atom.header;
        final moovEnd = pos + atom.size;
        var childGuards = 0;
        while (child + 8 <= moovEnd && childGuards++ < 64) {
          final c = readHeader(child);
          if (c == null || c.size <= 0) break;
          if (c.type == 'mvhd') {
            return parseMvhd(child, c.size, c.header);
          }
          final nextChild = child + c.size;
          if (nextChild <= child) break;
          child = nextChild;
        }
        break;
      }

      final next = pos + atom.size;
      if (next <= pos) break;
      pos = next;
    }
    return null;
  } finally {
    raf.closeSync();
  }
}

/// Header only (MP3 / small files). M4B uses [parseMp4DurationSeconds] instead.
Future<Uint8List> _readMetadataBytes(File file, int fileSize) async {
  final raf = await file.open(mode: FileMode.read);
  try {
    Future<Uint8List> readRange(int start, int length) async {
      await raf.setPosition(start);
      return Uint8List.fromList(await raf.read(length));
    }

    var headLen = min(_chunkBytes, fileSize);
    var head = await readRange(0, headLen);

    // Grow past a large ID3v2 tag if needed.
    if (head.length >= 10 &&
        head[0] == 0x49 &&
        head[1] == 0x44 &&
        head[2] == 0x33) {
      final id3Size = ((head[6] & 0x7F) << 21) |
          ((head[7] & 0x7F) << 14) |
          ((head[8] & 0x7F) << 7) |
          (head[9] & 0x7F);
      final needed = min(10 + id3Size + 128 * 1024, fileSize);
      if (needed > head.length) {
        final builder = BytesBuilder(copy: false)..add(head);
        var pos = head.length;
        while (pos < needed) {
          final n = min(_chunkBytes, needed - pos);
          builder.add(await readRange(pos, n));
          pos += n;
        }
        head = builder.takeBytes();
      }
    }

    return head;
  } finally {
    await raf.close();
  }
}

Duration? _parseMp3Duration(Uint8List bytes, int fileSize) {
  try {
    var i = 0;
    if (bytes.length >= 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      final size = ((bytes[6] & 0x7F) << 21) |
          ((bytes[7] & 0x7F) << 14) |
          ((bytes[8] & 0x7F) << 7) |
          (bytes[9] & 0x7F);
      i = 10 + size;
    }

    var mpegOffset = -1;
    for (; i < bytes.length - 4; i++) {
      if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
        mpegOffset = i;
        break;
      }
    }
    if (mpegOffset == -1) return null;

    final b1 = bytes[mpegOffset + 1];
    final b2 = bytes[mpegOffset + 2];
    final b3 = bytes[mpegOffset + 3];

    final version = (b1 >> 3) & 0x03;
    final layer = (b1 >> 1) & 0x03;
    final bitrateIdx = (b2 >> 4) & 0x0F;
    final sampleRateIdx = (b2 >> 2) & 0x03;
    final mode = (b3 >> 6) & 0x03;

    if (version == 1 ||
        layer != 1 ||
        bitrateIdx == 0x0F ||
        sampleRateIdx == 0x03) {
      return null;
    }

    int sampleRate = 0;
    if (version == 3) {
      sampleRate = [44100, 48000, 32000, 0][sampleRateIdx];
    } else if (version == 2) {
      sampleRate = [22050, 24000, 16000, 0][sampleRateIdx];
    } else if (version == 0) {
      sampleRate = [11025, 12000, 8000, 0][sampleRateIdx];
    }
    if (sampleRate == 0) return null;

    int bitrate = 0;
    if (version == 3) {
      bitrate = [
        0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0,
      ][bitrateIdx];
    } else {
      bitrate = [
        0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0,
      ][bitrateIdx];
    }
    if (bitrate == 0) return null;

    final isMono = mode == 3;
    final sideInfoSize =
        version == 3 ? (isMono ? 17 : 32) : (isMono ? 9 : 17);
    final xingOffset = mpegOffset + 4 + sideInfoSize;

    if (xingOffset + 12 <= bytes.length) {
      final isXing = bytes[xingOffset] == 0x58 &&
          bytes[xingOffset + 1] == 0x69 &&
          bytes[xingOffset + 2] == 0x6E &&
          bytes[xingOffset + 3] == 0x67;
      final isInfo = bytes[xingOffset] == 0x49 &&
          bytes[xingOffset + 1] == 0x6E &&
          bytes[xingOffset + 2] == 0x66 &&
          bytes[xingOffset + 3] == 0x6F;
      if (isXing || isInfo) {
        final flags = (bytes[xingOffset + 4] << 24) |
            (bytes[xingOffset + 5] << 16) |
            (bytes[xingOffset + 6] << 8) |
            (bytes[xingOffset + 7]);
        if ((flags & 0x01) != 0) {
          final frames = (bytes[xingOffset + 8] << 24) |
              (bytes[xingOffset + 9] << 16) |
              (bytes[xingOffset + 10] << 8) |
              (bytes[xingOffset + 11]);
          final samplesPerFrame = version == 3 ? 1152 : 576;
          return Duration(
            milliseconds: (frames * samplesPerFrame * 1000) ~/ sampleRate,
          );
        }
      }
    }

    final audioSize = fileSize - mpegOffset;
    return Duration(milliseconds: (audioSize * 8 * 1000) ~/ (bitrate * 1000));
  } catch (_) {
    return null;
  }
}
