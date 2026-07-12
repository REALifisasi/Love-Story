import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:nylo_framework/nylo_framework.dart';

import '/app/controllers/home_controller.dart';
import '/resources/pages/romantic_page.dart';

class HomePage extends NyStatefulWidget<HomeController> {
  static RouteView path = ("/home", (_) => HomePage());

  HomePage({super.key}) : super(child: () => _HomePageState());
}

class _HomePageState extends NyPage<HomePage> {
  late ConfettiController _confettiController;
  bool _navigating = false;

  // ─── Palette ──────────────────────────────────────────────────────────────
  static const Color _rose = Color(0xFFE8A0B0);

  @override
  get init => () async {
        _confettiController =
            ConfettiController(duration: const Duration(seconds: 2));
      };

  @override
  LoadingStyle get loadingStyle => LoadingStyle.none();

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _onEnter() async {
    if (_navigating) return;
    setState(() => _navigating = true);
    _confettiController.play();
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      setState(() => _navigating = false);
      Navigator.of(context).push(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => RomanticPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ));
    }
  }

  Path _heartPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    final path = Path();
    path.moveTo(w / 2, h * 0.85);
    path.cubicTo(w * 0.05, h * 0.55, w * 0.0, h * 0.15, w / 2, h * 0.35);
    path.cubicTo(w, h * 0.15, w * 0.95, h * 0.55, w / 2, h * 0.85);
    path.close();
    return path;
  }

  @override
  Widget view(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ── Gradient background ──
          Container(
            width: sw,
            height: sh,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF0F4), Color(0xFFFAD4DF), Color(0xFFF5B8C8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Confetti ──
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.06,
            emissionFrequency: 0.08,
            numberOfParticles: 18,
            gravity: 0.25,
            colors: const [
              Color(0xFFE8A0B0),
              Color(0xFFF5C6D0),
              Color(0xFFFFB6C1),
              Color(0xFFFF8FAB),
              Color(0xFFFFFFFF),
            ],
            createParticlePath: _heartPath,
          ),

          // ── Heart button ──
          GestureDetector(
            onTap: _onEnter,
            child: AnimatedScale(
              scale: _navigating ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(
                Icons.favorite,
                size: 80,
                color: const Color(0xFFD4607A),
                shadows: [
                  Shadow(
                    color: const Color(0xFFE8A0B0).withOpacity(0.5),
                    blurRadius: 32,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
