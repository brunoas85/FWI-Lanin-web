import 'package:flutter/material.dart';

/// Pantalla completa para ver una imagen de red con pellizco para
/// acercar/alejar y desplazamiento (`InteractiveViewer`). Reemplaza, para
/// el mapa de estaciones (C12), la descarga directa del original: en vez
/// de mandar el archivo al navegador, se muestra dentro de la app.
class VisorImagenPantallaCompleta extends StatelessWidget {
  const VisorImagenPantallaCompleta({
    super.key,
    required this.url,
    this.titulo,
    this.imagen,
  });

  final String url;
  final String? titulo;

  /// Inyectable para tests — evita que `flutter test` dispare una llamada
  /// de red real. En la app se omite y se usa `NetworkImage(url)`.
  final ImageProvider? imagen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: titulo == null ? null : Text(titulo!),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image(
            image: imagen ?? NetworkImage(url),
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (context, error, stackTrace) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, color: Colors.white, size: 48),
                SizedBox(height: 12),
                Text(
                  'No se pudo cargar el mapa.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
