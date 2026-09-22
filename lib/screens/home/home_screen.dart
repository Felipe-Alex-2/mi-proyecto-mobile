import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/cart_service.dart';
import '../../services/notification_service.dart';
import '../catalog/catalog_screen.dart';
import '../cart/cart_screen.dart';
import '../reservations/reservations_screen.dart';
import '../virtual_fitting/virtual_fitting_room_screen.dart';
import '../assistant/assistant_carlitos_screen.dart';
import 'widgets/notifications_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartService>().loadCart();
      context.read<NotificationService>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartService = context.watch<CartService>();
    final cartCount = cartService.itemCount;

    final pages = [
      _HomeDashboardTab(onNavigateToTab: (index) => setState(() => _currentIndex = index)),
      const CatalogScreen(),
      const CartScreen(),
      const ReservationsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.terracotta,
        unselectedItemColor: AppTheme.brownMedium,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
              backgroundColor: AppTheme.terracotta,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              backgroundColor: AppTheme.terracotta,
              child: const Icon(Icons.shopping_bag_rounded),
            ),
            label: 'Carrito',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note_rounded),
            label: 'Reservas',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssistantCarlitosScreen()),
          );
        },
        backgroundColor: AppTheme.terracotta,
        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        label: const Text(
          'Carlitos IA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _HomeDashboardTab extends StatelessWidget {
  final ValueChanged<int> onNavigateToTab;

  const _HomeDashboardTab({required this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.checkroom_rounded, color: AppTheme.terracotta, size: 22),
            SizedBox(width: 8),
            Text(
              'FashionStore VESTA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.brown,
              ),
            ),
          ],
        ),
        actions: [
          // Globo de Notificaciones con contador en esquina superior derecha
          Consumer<NotificationService>(
            builder: (context, notifService, _) {
              final unread = notifService.unreadCount;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(
                    '$unread',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: Colors.red,
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: AppTheme.brown,
                    size: 24,
                  ),
                ),
                tooltip: 'Notificaciones ($unread nuevas)',
                onPressed: () {
                  NotificationsModal.show(
                    context,
                    notifService,
                    onNavigateToTab: onNavigateToTab,
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('Cerrar Sesión', style: TextStyle(color: AppTheme.brown)),
                  content: const Text('¿Estás seguro de que deseas salir?', style: TextStyle(color: AppTheme.brownMedium)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        authService.logout();
                      },
                      child: const Text('Cerrar Sesión'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.brown, AppTheme.terracotta],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brown.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white.withValues(alpha: 0.9), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Sesión Activa',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Hola, ${user?.fullName ?? "Cliente"}!',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explora nuestro catálogo en Dólares (\$ USD), arma tu carrito y reserva tus prendas favoritas para probártelas en tienda física.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick access cards
            _QuickAccessCard(
              icon: Icons.auto_awesome,
              iconColor: AppTheme.terracotta,
              iconBg: AppTheme.terracotta.withValues(alpha: 0.1),
              title: 'Asistente y Recomendador IA',
              subtitle: 'Carlitos te recomienda prendas según tus gustos',
              label: 'Consultar',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AssistantCarlitosScreen()),
                );
              },
            ),
            const SizedBox(height: 12),

            _QuickAccessCard(
              icon: Icons.face_retouching_natural_rounded,
              iconColor: Colors.purple,
              iconBg: Colors.purple.withValues(alpha: 0.1),
              title: 'Probador Virtual',
              subtitle: 'Prueba la ropa en ti usando IA',
              label: 'Probar',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VirtualFittingRoomScreen()),
                );
              },
            ),
            const SizedBox(height: 24),

            // Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.badge_outlined, color: AppTheme.terracotta),
                        SizedBox(width: 8),
                        Text(
                          'Tu Cuenta',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.brown),
                        ),
                      ],
                    ),
                    Divider(height: 24, color: AppTheme.terracotta.withValues(alpha: 0.12)),
                    _buildInfoRow('Nombre', user?.fullName ?? '-'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Email', user?.email ?? '-'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Moneda del Sistema', 'Dólares (\$ USD)'),
                    const SizedBox(height: 12),
                    _buildInfoRow('Estado', user?.isActive == true ? 'Activo ✅' : 'Inactivo'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.brownMedium, fontSize: 13)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.brown)),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.terracotta.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.brown)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppTheme.brownMedium, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColor.withValues(alpha: 0.3)),
              ),
              child: Text(label, style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
