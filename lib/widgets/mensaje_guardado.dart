import 'package:flutter/material.dart';

import '../configuracion/tema.dart';

void showSaveFeedback(
  BuildContext context, {
  required bool pending,
  required String confirmed,
  required String queued,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: pending ? const Color(0xFF8A5A15) : TemaApp.sageInk,
      action: action,
      content: Row(
        children: [
          Icon(
            pending ? Icons.cloud_upload_outlined : Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(pending ? queued : confirmed)),
        ],
      ),
    ),
  );
}
