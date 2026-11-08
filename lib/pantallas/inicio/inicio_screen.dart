import '../../servicios/reserva_service.dart';
import '../../servicios/push_service.dart';
import '../perfil/wallet_screen.dart';
import '../reportes/reportes_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../configuracion/tema.dart';
import '../../widgets/avatar_perfil.dart';
import '../perfil/perfil_screen.dart';
import '../../servicios/catalogo_service.dart';
import '../../widgets/prenda_card.dart';
import '../../servicios/autenticacion_service.dart';
import '../../servicios/carrito_service.dart';
import '../../servicios/notificacion_service.dart';
import '../catalogo/catalogo_screen.dart';
import '../carrito/carrito_screen.dart';
import '../reservas/reservas_screen.dart';
import '../vestidor_virtual/vestidor_virtual_screen.dart';
import '../asistente/asistente_carlitos_screen.dart';
import 'widgets/notificaciones_modal.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _visitedTabs = <int>{0};
  late final NotificacionService _notifications;
  PushService? _push;
  int _pushRevision = -1;
  void _pushChanged() {
    if (!mounted) return;
    final service = _push;
    if (service == null) return;
    if (_pushRevision != service.revision) {
      _pushRevision = service.revision;
      _notifications.loadNotifications(silent: true);
    }
    final data = service.takeOpen();
    if (data == null) return;
    if (data['reservation_id'] != null) {
      _navigateToTab(3);
      context.read<ReservaService>().loadReservations();
    } else if (data['kind'] == 'WALLET_TOPUP') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WalletScreen()),
      );
    } else {
      NotificacionesModal.show(
        context,
        _notifications,
        onNavigateToTab: _navigateToTab,
      );
    }
  }

  void _navigateToTab(int index) => setState(() {
    _visitedTabs.add(index);
    _currentIndex = index;
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notifications.startPolling();
      _notifications.loadNotifications(silent: true);
    } else {
      _notifications.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _push?.removeListener(_pushChanged);
    _notifications.clearSession();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _notifications = context.read<NotificacionService>();
    _push = context.read<PushService?>();
    _push?.addListener(_pushChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CarritoService>().loadCart();
      if (context.read<CatalogoService>().status == CatalogStatus.idle) {
        context.read<CatalogoService>().loadProducts();
      }
      _notifications.loadNotifications();
      _notifications.startPolling();
      _pushChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartService = context.watch<CarritoService>();
    final cartCount = cartService.itemCount;

    final pages = [
      _PanelInicioTab(onNavigateToTab: _navigateToTab),
      const CatalogoScreen(),
      const CarritoScreen(),
      const ReservasScreen(),
      const ReportesScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var index = 0; index < pages.length; index++)
            _visitedTabs.contains(index)
                ? pages[index]
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _navigateToTab,
        type: BottomNavigationBarType.fixed,
        backgroundColor: TemaApp.surface,
        selectedItemColor: TemaApp.terracotta,
        unselectedItemColor: TemaApp.brownMedium,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.checkroom_outlined),
            activeIcon: Icon(Icons.checkroom_rounded),
            label: 'Catálogo',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              backgroundColor: TemaApp.terracotta,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              backgroundColor: TemaApp.terracotta,
              child: const Icon(Icons.shopping_bag_rounded),
            ),
            label: 'Carrito',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note_rounded),
            label: 'Reservas',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.assessment_outlined),
            activeIcon: Icon(Icons.assessment),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}

class _PanelInicioTab extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;
  const _PanelInicioTab({required this.onNavigateToTab});

  void _openFitting(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const VestidorVirtualScreen()),
  );

  void _showAccount(BuildContext context) {
    final auth = context.read<AutenticacionService>();
    final user = auth.currentUser;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tu cuenta',
                style: TemaApp.editorial.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 20),
              Text(
                user?.fullName ?? 'Cliente',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                user?.email ?? '',
                style: const TextStyle(color: TemaApp.brownMedium),
              ),
              const SizedBox(height: 12),
              Text(
                user?.isActive == true
                    ? 'Cuenta activa · Precios en USD'
                    : 'Cuenta inactiva · Precios en USD',
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil y foto'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PerfilScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Cerrar sesión'),
                      content: const Text('¿Estás seguro de que deseas salir?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Salir'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                    auth.logout();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AutenticacionService>().currentUser;
    final catalog = context.watch<CatalogoService>();
    final products = catalog.products.take(4).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'VESTA',
          style: TemaApp.editorial.copyWith(fontSize: 26, letterSpacing: 4),
        ),
        actions: [
          Consumer<NotificacionService>(
            builder: (context, notifications, _) => IconButton(
              tooltip: 'Notificaciones',
              icon: Badge(
                isLabelVisible: notifications.unreadCount > 0,
                label: Text('${notifications.unreadCount}'),
                backgroundColor: TemaApp.terracotta,
                child: const Icon(Icons.notifications_none_rounded),
              ),
              onPressed: () => NotificacionesModal.show(
                context,
                notifications,
                onNavigateToTab: onNavigateToTab,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tu cuenta',
            onPressed: () => _showAccount(context),
            icon: AvatarPerfil(user: user, size: 34),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: catalog.loadProducts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Hola, ${user?.fullName.split(' ').first ?? "Cliente"}',
              style: const TextStyle(fontSize: 14, color: TemaApp.brownMedium),
            ),
            const SizedBox(height: 8),
            Text(
              '${user?.companyName ?? "VESTA"} · ${user?.branchName ?? "Tu tienda"}',
              style: const TextStyle(color: TemaApp.terracotta, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text('Encuentra tu\npróximo look', style: TemaApp.editorial),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/virtual-fitting-hero.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      excludeFromSemantics: true,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, 0.4, 1],
                          colors: [
                            Colors.transparent,
                            Color(0x332C211D),
                            Color(0xE62C211D),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu estilo, en ti.',
                            style: TemaApp.editorial.copyWith(
                              color: Colors.white,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Descubre cómo te queda antes de reservar.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: () => _openFitting(context),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(child: Text('Abrir vestidor')),
                                SizedBox(width: 12),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Para ti',
                  style: TemaApp.editorial.copyWith(fontSize: 26),
                ),
                TextButton(
                  onPressed: () => onNavigateToTab(1),
                  child: const Text('Ver catálogo'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (catalog.status == CatalogStatus.loading && products.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (products.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
                    mainAxisExtent:
                        290 +
                        (MediaQuery.textScalerOf(context).scale(14) - 14) * 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, index) =>
                      PrendaCard(product: products[index]),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: TemaApp.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      catalog.status == CatalogStatus.error
                          ? 'No pudimos cargar las prendas.'
                          : 'Pronto encontrarás nuevas prendas aquí.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: catalog.loadProducts,
                      child: const Text('Actualizar catálogo'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Material(
              color: TemaApp.sage,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AsistenteCarlitosScreen(),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: TemaApp.sageInk,
                        size: 28,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carlitos IA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Descubre prendas para ti',
                              style: TextStyle(
                                fontSize: 13,
                                color: TemaApp.sageInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: TemaApp.sageInk,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
