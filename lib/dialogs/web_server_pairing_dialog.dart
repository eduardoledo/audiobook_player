import 'package:flutter/material.dart';

class WebServerPairingDialog extends StatelessWidget {
  final String pin;
  final String serverAddress;
  final VoidCallback onStopServer;

  const WebServerPairingDialog({
    super.key,
    required this.pin,
    required this.serverAddress,
    required this.onStopServer,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cell_tower, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('Servidor Web Activo'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Accede desde el navegador de tu computadora a:'),
          const SizedBox(height: 8),
          SelectableText(
            serverAddress,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text('Código PIN de 4 dígitos:'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.deepPurple.shade200),
            ),
            child: Text(
              pin,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            onStopServer();
            Navigator.of(context).pop();
          },
          child: const Text('Detener Servidor', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
