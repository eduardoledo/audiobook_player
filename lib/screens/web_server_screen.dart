import 'dart:async';
import 'package:flutter/material.dart';
import '../service_locator.dart';
import '../services/web_server_service.dart';
import '../dialogs/web_server_pairing_dialog.dart';

class WebServerScreen extends StatefulWidget {
  const WebServerScreen({super.key});

  @override
  State<WebServerScreen> createState() => _WebServerScreenState();
}

class _WebServerScreenState extends State<WebServerScreen> {
  final _webServerService = getIt<WebServerService>();
  bool _isStarting = false;

  Future<void> _toggleServer(bool value) async {
    setState(() {
      _isStarting = true;
    });

    if (value) {
      final pin = _webServerService.generatePin();
      final started = await _webServerService.start();
      if (mounted) {
        setState(() {
          _isStarting = false;
        });

        if (started) {
          unawaited(_showPairingDialog(pin));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo iniciar el servidor web')),
          );
        }
      }
    } else {
      await _webServerService.stop();
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _showPairingDialog(String pin) async {
    final ip = await _webServerService.getLocalIpAddress();
    if (!mounted) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => WebServerPairingDialog(
          pin: pin,
          serverAddress: 'http://$ip:${_webServerService.port}',
          onStopServer: () async {
            await _webServerService.stop();
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _webServerService.isRunning;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Servidor Web Local'),
        backgroundColor: const Color(0xFF252525),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            color: const Color(0xFF252525),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: Color(0xFFE8B86D), size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Servidor Web',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      _isStarting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFFE8B86D),
                                strokeWidth: 2,
                              ),
                            )
                          : Switch(
                              value: isRunning,
                              activeThumbColor: const Color(0xFFE8B86D),
                              onChanged: _toggleServer,
                            ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRunning
                        ? 'El servidor web está actualmente ACTIVO. Puedes transferir audiolibros o controlar la reproducción remotamente.'
                        : 'Activa el servidor web para conectar navegadores de tu red local.',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          if (isRunning) ...[
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFF252525),
              child: ListTile(
                leading: const Icon(Icons.qr_code, color: Color(0xFFE8B86D)),
                title: const Text(
                  'Ver código PIN e Información de Conexión',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'PIN actual: ${_webServerService.activePin ?? '---'}',
                  style: const TextStyle(color: Colors.white54),
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () {
                  if (_webServerService.activePin != null) {
                    _showPairingDialog(_webServerService.activePin!);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
