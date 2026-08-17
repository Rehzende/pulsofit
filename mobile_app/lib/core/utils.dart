import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> launchWhatsApp(BuildContext context, String? phone, {String? message}) async {
  if (phone == null || phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Telefone não cadastrado.')),
    );
    return;
  }

  final cleanNumber = phone.replaceAll(RegExp(r'[^\d]'), '');
  final uri = Uri.parse(
    'https://wa.me/$cleanNumber${message != null ? "?text=${Uri.encodeComponent(message)}" : ""}',
  );

  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir WhatsApp: $e')),
      );
    }
  }
}
