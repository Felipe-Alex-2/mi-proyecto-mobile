import 'package:flutter/widgets.dart';

import '../servicios/autenticacion_service.dart';

class BloqueoSesion extends StatefulWidget {
  final AutenticacionService auth;
  final Widget child;
  const BloqueoSesion({super.key, required this.auth, required this.child});
  @override
  State<BloqueoSesion> createState() => _BloqueoSesionState();
}

class _BloqueoSesionState extends State<BloqueoSesion> with WidgetsBindingObserver {
  DateTime? _background;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _background = DateTime.now();
    if (state == AppLifecycleState.resumed && _background != null) {
      if (DateTime.now().difference(_background!) >=
          const Duration(seconds: 30)) {
        widget.auth.lock();
      }
      _background = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
