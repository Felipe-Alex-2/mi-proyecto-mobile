import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/biometric_profile.dart';
import '../../services/virtual_fitting_service.dart';
import 'virtual_fitting_room_screen.dart';

class BiometricOnboardingScreen extends StatefulWidget {
  final bool redirectToFittingRoom;

  const BiometricOnboardingScreen({
    super.key,
    this.redirectToFittingRoom = true,
  });

  @override
  State<BiometricOnboardingScreen> createState() => _BiometricOnboardingScreenState();
}

class _BiometricOnboardingScreenState extends State<BiometricOnboardingScreen> {
  String _gender = 'HOMBRE'; // 'HOMBRE' | 'MUJER'

  final _formKey = GlobalKey<FormState>();
  final _heightCtrl = TextEditingController(text: '172');
  final _weightCtrl = TextEditingController(text: '70');
  final _chestCtrl = TextEditingController(text: '95');
  final _waistCtrl = TextEditingController(text: '82');
  final _hipCtrl = TextEditingController(text: '98');

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingData();
    });
  }

  void _loadExistingData() async {
    final service = context.read<VirtualFittingService>();
    final profile = service.profile ?? await service.loadProfile();
    if (profile != null && mounted) {
      setState(() {
        _gender = profile.gender.toUpperCase();
        _heightCtrl.text = profile.heightCm.toStringAsFixed(0);
        _weightCtrl.text = profile.weightKg.toStringAsFixed(0);
        _chestCtrl.text = profile.chestCm.toStringAsFixed(0);
        _waistCtrl.text = profile.waistCm.toStringAsFixed(0);
        _hipCtrl.text = profile.hipCm.toStringAsFixed(0);
      });
    }
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _hipCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final profile = BiometricProfile(
        gender: _gender,
        heightCm: double.parse(_heightCtrl.text.trim()),
        weightKg: double.parse(_weightCtrl.text.trim()),
        chestCm: double.parse(_chestCtrl.text.trim()),
        waistCm: double.parse(_waistCtrl.text.trim()),
        hipCm: double.parse(_hipCtrl.text.trim()),
      );

      await context.read<VirtualFittingService>().saveProfile(profile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Perfil Biométrico guardado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );

      if (widget.redirectToFittingRoom) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VirtualFittingRoomScreen()),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWoman = _gender == 'MUJER';

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text(
          'Perfil Biométrico IA',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.brown, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: AppTheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.brown, AppTheme.terracotta],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brown.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.accessibility_new_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Paso 1: Medidas Corporales',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nuestro motor de IA utiliza tus proporciones biométricas para calcular tu talla exacta y simular el fit en el probador virtual.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Selección de Género
              const Text(
                'Selecciona tu Género *',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.brown),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildGenderOption(
                      label: 'Hombre',
                      icon: Icons.man_rounded,
                      value: 'HOMBRE',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGenderOption(
                      label: 'Mujer',
                      icon: Icons.woman_rounded,
                      value: 'MUJER',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Inputs Numéricos Biométricos
              const Text(
                'Ingresa tus Medidas Físicas (cm / kg) *',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.brown),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _buildMeasureField(
                      controller: _heightCtrl,
                      label: 'Altura',
                      unit: 'cm',
                      icon: Icons.height_rounded,
                      minVal: 100,
                      maxVal: 230,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildMeasureField(
                      controller: _weightCtrl,
                      label: 'Peso',
                      unit: 'kg',
                      icon: Icons.monitor_weight_outlined,
                      minVal: 30,
                      maxVal: 200,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              _buildMeasureField(
                controller: _chestCtrl,
                label: isWoman ? 'Contorno de Busto' : 'Contorno de Pecho',
                unit: 'cm',
                icon: Icons.straighten_rounded,
                minVal: 50,
                maxVal: 170,
                helper: isWoman
                    ? 'Mide la parte más prominente del busto'
                    : 'Mide alrededor de la parte más ancha del torso',
              ),
              const SizedBox(height: 14),

              _buildMeasureField(
                controller: _waistCtrl,
                label: 'Contorno de Cintura',
                unit: 'cm',
                icon: Icons.rotate_right_rounded,
                minVal: 40,
                maxVal: 160,
                helper: 'Mide la parte más estrecha del abdomen (sobre el ombligo)',
              ),
              const SizedBox(height: 14),

              _buildMeasureField(
                controller: _hipCtrl,
                label: 'Contorno de Cadera',
                unit: 'cm',
                icon: Icons.circle_outlined,
                minVal: 50,
                maxVal: 170,
                helper: 'Mide la parte más ancha de las caderas y glúteos',
              ),
              const SizedBox(height: 30),

              // Botón Guardar
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.terracotta,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            widget.redirectToFittingRoom ? 'Guardar y Abrir Probador' : 'Guardar Medidas',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.terracotta.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.terracotta : AppTheme.creamLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.terracotta : AppTheme.brownMedium,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? AppTheme.terracotta : AppTheme.brown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasureField({
    required TextEditingController controller,
    required String label,
    required String unit,
    required IconData icon,
    required double minVal,
    required double maxVal,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: unit,
            helperText: helper,
            prefixIcon: Icon(icon, color: AppTheme.terracotta, size: 20),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.creamLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.creamLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.terracotta, width: 2),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Requerido';
            final numVal = double.tryParse(val.trim());
            if (numVal == null) return 'Ingresa un número válido';
            if (numVal < minVal || numVal > maxVal) {
              return 'Rango sugerido: $minVal - $maxVal $unit';
            }
            return null;
          },
        ),
      ],
    );
  }
}
