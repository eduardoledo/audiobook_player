import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '753004873365-8eokvstei63dgc8gofc52bqh1gc7chfa.apps.googleusercontent.com',
    scopes: [
      drive.DriveApi.driveReadonlyScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null && _driveApi != null;

  GoogleDriveService() {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
    });
  }

  Future<void> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser != null) {
        await _initDriveApi(_currentUser!);
      }
    } catch (error) {
      debugPrint('Error signing in: $error');
      rethrow;
    }
  }
  
  Future<void> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser != null) {
        await _initDriveApi(_currentUser!);
      }
    } catch (error) {
      debugPrint('Error signing in silently: $error');
    }
  }

  Future<void> signOut() async {
    _driveApi = null;
    await _googleSignIn.disconnect();
  }

  Future<void> _initDriveApi(GoogleSignInAccount account) async {
    final headers = await account.authHeaders;
    final client = GoogleAuthClient(headers);
    _driveApi = drive.DriveApi(client);
  }

  /// Lists files and folders in a specific folder (or root if null)
  Future<List<drive.File>> listFiles({String? folderId}) async {
    if (_driveApi == null) throw Exception("Not signed in");

    final query = folderId != null 
        ? "'$folderId' in parents and trashed = false"
        : "'root' in parents and trashed = false";

    final fileList = await _driveApi!.files.list(
      q: query,
      $fields: "files(id, name, mimeType, size)",
      orderBy: "folder, name",
    );

    return fileList.files ?? [];
  }

  /// Downloads a file to a specified local path, with progress callback
  Future<File> downloadFile(
    drive.File driveFile, 
    String localDirPath, 
    {Function(double)? onProgress}
  ) async {
    if (_driveApi == null) throw Exception("Not signed in");
    if (driveFile.id == null || driveFile.name == null) {
      throw Exception("Invalid file");
    }

    final localPath = p.join(localDirPath, driveFile.name);
    final file = File(localPath);
    
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    final media = await _driveApi!.files.get(
      driveFile.id!, 
      downloadOptions: drive.DownloadOptions.metadata
    ) as drive.File;
    
    final totalSize = int.tryParse(media.size ?? '') ?? 0;
    
    final downloadMedia = await _driveApi!.files.get(
      driveFile.id!, 
      downloadOptions: drive.DownloadOptions.fullMedia
    ) as drive.Media;

    final sink = file.openWrite();
    int downloaded = 0;
    
    await for (final chunk in downloadMedia.stream) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (totalSize > 0 && onProgress != null) {
        onProgress(downloaded / totalSize);
      }
    }
    await sink.close();
    
    return file;
  }
}
