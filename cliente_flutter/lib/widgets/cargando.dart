import 'package:flutter/material.dart';

class Cargando extends StatelessWidget {
  final String? mensaje;
  const Cargando({super.key, this.mensaje});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          if (mensaje != null) ...[const SizedBox(height: 12), Text(mensaje!)],
        ]),
      );
}
