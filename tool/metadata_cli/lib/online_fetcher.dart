import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'models.dart';

Map<String, String?> extractSeries(String title) {
  final match = RegExp(
    r'\((.*?)(?:,\s*Book\s*(\d+)|(?:,\s*)?#(\d+))\)',
    caseSensitive: false,
  ).firstMatch(title);
  if (match != null) {
    final sName = match.group(1)?.trim();
    final sPos = match.group(2) ?? match.group(3);
    return {'seriesName': sName, 'seriesPosition': sPos};
  }
  return {'seriesName': null, 'seriesPosition': null};
}

/// Fetches enrichment from iTunes → Google Books → OpenLibrary.
Future<OnlineEnrichment> fetchOnlineMetadata({
  required String title,
  required String author,
  void Function(String status)? onStatus,
}) async {
  String? itunesCoverUrl;
  String? itunesDesc;
  String? itunesYear;
  String? itunesSeries;
  String? itunesSeriesPos;

  try {
    onStatus?.call('Searching iTunes...');
    final query = Uri.encodeComponent('$title $author');
    final url = Uri.parse(
      'https://itunes.apple.com/search?term=$query&media=audiobook&limit=1',
    );
    final response =
        await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        final result = data['results'][0];
        final rawDesc = result['description']?.toString() ?? '';
        itunesDesc = rawDesc.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');
        final release = result['releaseDate']?.toString();
        if (release != null && release.length >= 4) {
          itunesYear = release.substring(0, 4);
        }
        itunesCoverUrl = result['artworkUrl100']
            ?.toString()
            .replaceAll('100x100bb.jpg', '600x600bb.jpg');
        final collectionName = result['collectionName']?.toString() ?? '';
        final extracted = extractSeries(collectionName);
        itunesSeries = extracted['seriesName'];
        itunesSeriesPos = extracted['seriesPosition'];
      }
    }
  } catch (_) {}

  String? googleDesc;
  String? googleYear;
  String? googleSeries;
  String? googleSeriesPos;
  List<String> googleSubjects = [];
  try {
    onStatus?.call('Searching Google Books...');
    final query = Uri.encodeComponent('$title $author');
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=$query&maxResults=1',
    );
    final response =
        await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['items'] != null && data['items'].isNotEmpty) {
        final vol = data['items'][0]['volumeInfo'];
        googleDesc = vol['description']?.toString();
        final pd = vol['publishedDate']?.toString();
        googleYear = pd != null && pd.length >= 4 ? pd.substring(0, 4) : null;
        final volTitle = vol['title']?.toString() ?? '';
        final extracted = extractSeries(volTitle);
        googleSeries = extracted['seriesName'];
        googleSeriesPos = extracted['seriesPosition'];
        if (vol['categories'] != null) {
          googleSubjects = (vol['categories'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        }
      }
    }
  } catch (_) {}

  String? olYear;
  String? olSeries;
  String? olSeriesPos;
  List<String> olSubjects = [];
  String? olCoverI;
  try {
    onStatus?.call('Searching OpenLibrary...');
    final query = Uri.encodeComponent('$title $author');
    final url =
        Uri.parse('https://openlibrary.org/search.json?q=$query&limit=1');
    final response =
        await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['docs'] != null && data['docs'].isNotEmpty) {
        final doc = data['docs'][0];
        olYear = doc['first_publish_year']?.toString();
        olSubjects = (doc['subject'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        olSeries =
            (doc['series_name'] as List<dynamic>?)?.firstOrNull?.toString();
        olSeriesPos =
            (doc['series_position'] as List<dynamic>?)?.firstOrNull?.toString();
        olCoverI = doc['cover_i']?.toString();
      }
    }
  } catch (_) {}

  final bestDesc = itunesDesc ?? googleDesc;
  final bestYear = itunesYear ?? googleYear ?? olYear;
  final bestSubjects = olSubjects.isNotEmpty ? olSubjects : googleSubjects;
  final bestSeries = olSeries ?? itunesSeries ?? googleSeries;
  final bestSeriesPos = olSeriesPos ?? itunesSeriesPos ?? googleSeriesPos;

  String? bestCoverUrl = itunesCoverUrl;
  if (bestCoverUrl == null && olCoverI != null) {
    bestCoverUrl = 'https://covers.openlibrary.org/b/id/$olCoverI-L.jpg';
  }

  return OnlineEnrichment(
    description: bestDesc,
    publishYear: bestYear,
    seriesName: bestSeries,
    seriesPosition: bestSeriesPos,
    subjects: bestSubjects,
    coverUrl: bestCoverUrl,
  );
}

Future<bool> downloadCoverIfMissing({
  required String bookPath,
  required String? coverUrl,
  void Function(String status)? onStatus,
}) async {
  if (coverUrl == null || coverUrl.isEmpty) return false;
  final coverPath = p.join(bookPath, 'cover.jpg');
  if (await File(coverPath).exists()) return false;

  try {
    onStatus?.call('Downloading cover...');
    final coverResp =
        await http.get(Uri.parse(coverUrl)).timeout(const Duration(seconds: 15));
    if (coverResp.statusCode == 200) {
      await File(coverPath).writeAsBytes(coverResp.bodyBytes);
      return true;
    }
  } catch (_) {}
  return false;
}
