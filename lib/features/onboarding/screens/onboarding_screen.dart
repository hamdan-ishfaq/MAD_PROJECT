import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripgenie/core/constants/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isReplay;
  const OnboardingScreen({super.key, this.isReplay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.auto_awesome,
      title: 'AI Trip Planner',
      subtitle: 'Generate personalized itineraries powered by Groq AI.\nJust enter your destination, budget, and vibe!',
      gradient: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    ),
    _OnboardingPage(
      icon: Icons.group_rounded,
      title: 'Find Travel Buddies',
      subtitle: 'Post your trip and match with travelers heading\nthe same way. Chat, plan, and explore together!',
      gradient: [Color(0xFF0FA3B1), Color(0xFF14B8A6)],
    ),
    _OnboardingPage(
      icon: Icons.map_rounded,
      title: 'Live Insight Maps',
      subtitle: 'Discover nearby places with real crowd data.\nFilter by category and find hidden gems!',
      gradient: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
    _OnboardingPage(
      icon: Icons.chat_bubble_rounded,
      title: 'Rich Chat & Media',
      subtitle: 'Share photos, videos, reviews and warnings\nin trip chat rooms. Stay connected on the go!',
      gradient: [Color(0xFF124B8D), Color(0xFF0FA3B1)],
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      if (widget.isReplay) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: page.gradient)),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(page.icon, size: 80, color: Colors.white),
                      ),
                      const SizedBox(height: 48),
                      Text(page.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 16),
                      Text(page.subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85), height: 1.6)),
                    ],
                  ),
                ),
              );
            },
          ),
          // Skip button
          if (widget.isReplay || _currentPage < _pages.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: TextButton(
                onPressed: _finish,
                child: Text(widget.isReplay ? 'Close' : 'Skip', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          // Bottom controls
          Positioned(
            bottom: 48, left: 0, right: 0,
            child: Column(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentPage ? 32 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i == _currentPage ? Colors.white : Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                )),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(_currentPage == _pages.length - 1 ? 'Get Started' : 'Next', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  const _OnboardingPage({required this.icon, required this.title, required this.subtitle, required this.gradient});
}
