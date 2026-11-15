import 'package:flutter/material.dart';

import '../services/api_client.dart';

class ErrorReintentar extends StatelessWidget {
  final Object error;
  final VoidCallback alReintentar;
  const ErrorReintentar({super.key, required this.error, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    final mensaje = error is ApiException ? (error as ApiException).mensaje : 'Ocurrió un error inesperado';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off, size: 56, color: Colors.red.shade400),
          const SizedBox(height: 12),
          Text(mensaje, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: alReintentar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
        ]),
      ),
    );
  }
}
