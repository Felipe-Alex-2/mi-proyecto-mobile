import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modelos/usuario.dart';
import 'package:mobile/servicios/push_service.dart';

Usuario account({
  String id = 'u',
  String role = 'CUSTOMER',
  String tenant = 'company-a',
}) => Usuario.fromJson({
  'id': id,
  'role': role,
  'tenant_id': role == 'CUSTOMER' ? null : tenant,
  'selected_tenant_id': tenant,
  'email': 'u@example.com',
  'full_name': 'Cliente',
  'created_at': '2026-11-08',
  'updated_at': '2026-11-08',
});
void main() {
  test(
    'push destinations require both the logged-in owner and active company',
    () {
      final user = account();
      expect(
        pushBelongsTo({'user_id': 'u', 'tenant_id': 'company-a'}, user),
        isTrue,
      );
      expect(
        pushBelongsTo({'user_id': 'other', 'tenant_id': 'company-a'}, user),
        isFalse,
      );
      expect(
        pushBelongsTo({'user_id': 'u', 'tenant_id': 'company-b'}, user),
        isFalse,
      );
      expect(
        pushBelongsTo({'user_id': 'u', 'tenant_id': 'company-a'}, null),
        isFalse,
      );
      expect(pushBelongsTo({'notification_id': 'untrusted'}, user), isFalse);
    },
  );
  test(
    'staff pushes use their tenant instead of a customer-selected company',
    () {
      final user = account(role: 'ADMIN');
      expect(
        pushBelongsTo({'user_id': 'u', 'tenant_id': 'company-a'}, user),
        isTrue,
      );
      expect(
        pushBelongsTo({'user_id': 'u', 'tenant_id': 'company-b'}, user),
        isFalse,
      );
    },
  );
}
