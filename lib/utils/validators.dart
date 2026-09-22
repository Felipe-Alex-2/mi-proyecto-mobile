class AppValidators {
  /// Valida que el texto no esté vacío ni contenga solo espacios en blanco
  static String? validateRequired(
    String? value,
    String fieldName, {
    int minLength = 1,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Por favor ingresa $fieldName (campo obligatorio)';
    }
    if (value.trim().length < minLength) {
      return '$fieldName debe tener al menos $minLength caracteres';
    }
    return null;
  }

  /// Valida formato de correo electrónico
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu correo electrónico (ej. usuario@correo.com)';
    }
    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Ingresa un formato de correo válido (ej. usuario@correo.com)';
    }
    return null;
  }

  /// Valida la política de contraseña segura:
  /// - Mínimo 8 caracteres
  /// - Al menos 1 mayúscula
  /// - Al menos 1 minúscula
  /// - Al menos 1 número
  /// - Al menos 1 símbolo especial
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña (mínimo 8 caracteres)';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'La contraseña debe incluir al menos una letra mayúscula (A-Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'La contraseña debe incluir al menos una letra minúscula (a-z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'La contraseña debe incluir al menos un número (0-9)';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=\[\]~`\\/]').hasMatch(value)) {
      return 'Debe incluir al menos un símbolo especial (!@#\$%^&*...)';
    }
    return null;
  }
}
