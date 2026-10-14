import 'package:flutter/material.dart';

import '../models/user.dart';
import 'product_photo.dart';

class ProfileAvatar extends StatelessWidget {
  final User? user;
  final String? avatarId;
  final String? photo;
  final double size;
  const ProfileAvatar({
    super.key,
    this.user,
    this.avatarId,
    this.photo,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final image = avatarId != null ? photo : user?.profilePhoto;
    final id = avatarId ?? user?.avatarId ?? 'terracotta';
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: image != null
            ? ProductPhoto(url: image)
            : Image.asset(
                'assets/avatars/${['terracotta', 'sage', 'sand'].contains(id) ? id : 'terracotta'}.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
              ),
      ),
    );
  }
}
