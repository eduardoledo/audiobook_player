import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import '../service_locator.dart';
import '../services/google_drive_service.dart';

class GoogleDriveScreen extends StatefulWidget {
  const GoogleDriveScreen({super.key});

  @override
  State<GoogleDriveScreen> createState() => _GoogleDriveScreenState();
}

class _GoogleDriveScreenState extends State<GoogleDriveScreen> {
  final GoogleDriveService _driveService = getIt<GoogleDriveService>();
  
  List<drive.File> _files = [];
  bool _isLoading = false;
  String? _currentFolderId;
  final List<Map<String, String>> _folderHistory = []; // Maps ID to Name

  @override
  void initState() {
    super.initState();
    _checkSignInState();
  }

  Future<void> _checkSignInState() async {
    setState(() => _isLoading = true);
    await _driveService.signInSilently();
    if (_driveService.isSignedIn) {
      await _loadFiles();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await _driveService.signIn();
      if (_driveService.isSignedIn) {
        await _loadFiles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _driveService.signOut();
    setState(() {
      _files = [];
      _currentFolderId = null;
      _folderHistory.clear();
    });
  }

  Future<void> _loadFiles({String? folderId, String? folderName}) async {
    setState(() => _isLoading = true);
    try {
      if (folderId != null && folderName != null && folderId != _currentFolderId) {
        if (_currentFolderId != null) {
          _folderHistory.add({'id': _currentFolderId!, 'name': 'Previous'});
        } else {
          _folderHistory.add({'id': 'root', 'name': 'Root'});
        }
        _currentFolderId = folderId;
      }
      
      _files = await _driveService.listFiles(folderId: folderId);
      
      // Separate folders from files
      final folders = _files.where((f) => f.mimeType == 'application/vnd.google-apps.folder').toList();
      final audioFiles = _files.where((f) => f.mimeType != 'application/vnd.google-apps.folder' && (f.name?.endsWith('.m4b') == true || f.name?.endsWith('.mp3') == true)).toList();
      
      _files = [...folders, ...audioFiles];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading files: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _goBack() async {
    if (_folderHistory.isEmpty) return;
    final prev = _folderHistory.removeLast();
    _currentFolderId = prev['id'] == 'root' ? null : prev['id'];
    await _loadFiles(folderId: _currentFolderId);
  }

  Future<void> _downloadFile(drive.File file) async {
    // 1. Ask for storage location
    final dirs = await getExternalStorageDirectories();
    if (dirs == null || dirs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No storage available')));
      }
      return;
    }

    if (!mounted) return;
    
    final selectedDir = await showDialog<Directory>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Text('Select Storage Location', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: dirs.map((d) => ListTile(
            title: Text(d.path.contains('emulated') ? 'Internal Storage' : 'SD Card', style: const TextStyle(color: Colors.white)),
            subtitle: Text(d.path, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            onTap: () => Navigator.pop(ctx, d),
          )).toList(),
        ),
      ),
    );

    if (selectedDir == null) return;

    // 2. Download
    setState(() => _isLoading = true);
    try {
      final destPath = '${selectedDir.path}/Audiobooks';
      await _driveService.downloadFile(file, destPath, onProgress: (progress) {
         // Could update a progress bar here
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded ${file.name} to $destPath')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Google Drive', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF252525),
        foregroundColor: Colors.white,
        actions: [
          if (_driveService.isSignedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _signOut,
              tooltip: 'Sign Out',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _files.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE8B86D)));
    }

    if (!_driveService.isSignedIn) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _signIn,
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE8B86D),
            foregroundColor: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_currentFolderId != null)
          ListTile(
            leading: const Icon(Icons.arrow_back, color: Colors.white70),
            title: const Text('...', style: TextStyle(color: Colors.white)),
            onTap: _goBack,
          ),
        if (_isLoading)
          const LinearProgressIndicator(color: Color(0xFFE8B86D), backgroundColor: Colors.transparent),
        Expanded(
          child: ListView.builder(
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final file = _files[index];
              final isFolder = file.mimeType == 'application/vnd.google-apps.folder';
              
              return ListTile(
                leading: Icon(
                  isFolder ? Icons.folder : Icons.audio_file,
                  color: isFolder ? const Color(0xFFE8B86D) : Colors.white70,
                ),
                title: Text(file.name ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                trailing: isFolder 
                    ? const Icon(Icons.chevron_right, color: Colors.white54)
                    : IconButton(
                        icon: const Icon(Icons.download, color: Color(0xFFE8B86D)),
                        onPressed: () => _downloadFile(file),
                      ),
                onTap: () {
                  if (isFolder) {
                    _loadFiles(folderId: file.id, folderName: file.name);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
