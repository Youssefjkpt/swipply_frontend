import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsButton extends StatelessWidget {
  final String whatsappUrl =
      "https://wa.me/33758819649?text=Bonjour%20Swipply%20Team";

  const ContactUsButton({super.key});

  Future<void> _launchWhatsApp() async {
    final Uri uri = Uri.parse(
        "whatsapp://send?phone=33758819649&text=Bonjour%20Swipply%20Team");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // fallback to web link
      final fallbackUri =
          Uri.parse("https://wa.me/33758819649?text=Bonjour%20Swipply%20Team");
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("❌ Cannot launch WhatsApp via app or web.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launchWhatsApp,
    );
  }
}
