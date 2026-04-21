import 'package:flutter/material.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/widgets/auth_ui.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: AuthScaffoldBody(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportHeight = MediaQuery.of(context).size.height;
              final logoWidth = viewportHeight < 700 ? 220.0 : 250.0;
              final topGap = viewportHeight < 700 ? 48.0 : 72.0;
              final preButtonGap = viewportHeight < 700 ? 44.0 : 68.0;
              final postButtonGap = viewportHeight < 700 ? 24.0 : 34.0;

              return FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: topGap),
                      Center(
                        child: Image.asset(
                          'assets/branding/logo.png',
                          width: logoWidth,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 128,
                          height: 104,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Colors.white.withValues(alpha: 0.08),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                          ),
                          child: Image.asset(
                            'assets/branding/logo.png',
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Share your moments with the world',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 15,
                          letterSpacing: 0.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: preButtonGap),
                      AuthPrimaryButton(
                        label: 'Get Started',
                        onPressed: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const LoginScreen(),
                            transitionsBuilder: (_, animation, __, child) => FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: postButtonGap),
                      Text(
                        'By continuing, you agree to our Terms and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
