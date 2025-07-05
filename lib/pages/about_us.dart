// lib/pages/about_us_page.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:swipply/constants/images.dart'; // put a nice Lottie in images.dart (e.g. teamWork)
import 'package:swipply/constants/themes.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            /* ── header ───────────────────────────────────────────── */
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: black_gray),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.all(8),
                      child:
                          const Icon(Icons.arrow_back, color: white, size: 26),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'À propos de nous',
                    style: TextStyle(
                      color: white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),

            /* ── hero section ─────────────────────────────────────── */
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FFAA), Color(0xFF00C28C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        /* Lottie or Illustration */
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 20, right: 20, top: 20),
                          child: Lottie.asset(
                            teamwork, // <- add this Lottie asset
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          child: Text(
                            'Nous sommes une équipe passionnée, déterminée '
                            'à réinventer la recherche d’emploi grâce à la technologie. '
                            'Chaque fonctionnalité de notre application est conçue pour '
                            'simplifier votre parcours professionnel et faire ressortir '
                            'vos talents.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: black,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  /* ── mission / vision cards ───────────────────────── */
                  _infoCard(
                    icon: Icons.flag_outlined,
                    title: 'Notre mission',
                    content:
                        'Créer un pont direct entre les talents et les opportunités : '
                        'aider chacun à trouver le poste qui le fait vibrer, tout en aidant '
                        'les entreprises à repérer rapidement le bon profil.',
                  ),
                  const SizedBox(height: 20),
                  _infoCard(
                    icon: Icons.visibility_outlined,
                    title: 'Notre vision',
                    content:
                        'Un marché de l’emploi transparent, équitable et accessible, où les '
                        'décisions sont guidées par la compétence et la passion plutôt que par la chance.',
                  ),
                  const SizedBox(height: 20),
                  _infoCard(
                    icon: Icons.favorite_border,
                    title: 'Nos valeurs',
                    content:
                        '• Simplicité — des outils qui se comprennent en un clin d’œil.\n'
                        '• Inclusion — une plateforme pensée pour tous les profils.\n'
                        '• Innovation — l’IA au service de l’humain, jamais l’inverse.\n'
                        '• Confiance — protection des données et transparence totale.',
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      '© 2025 — Tous droits réservés',
                      style: TextStyle(
                          color: white_gray.withOpacity(.6), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* small helper widget for the text cards */
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: blackgraysettings,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: white, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: const TextStyle(
                      color: white_gray, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
