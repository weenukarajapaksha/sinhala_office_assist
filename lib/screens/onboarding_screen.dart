import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

const _pages = [
  _OnboardingPage(
    icon: Icons.mic_rounded,
    color: AppTheme.accentTeal,
    title: 'හඬ පටිගත කරන්න',
    description:
        'රැස්වීම් හෝ සටහන් එක් තට්ටුවකින් පටිගත කරන්න. පසුබිමින් පවා පටිගත කිරීම දිගටම කරගෙන යයි.',
  ),
  _OnboardingPage(
    icon: Icons.description_outlined,
    color: AppTheme.primaryBlue,
    title: 'පෙළට හරවන්න',
    description:
        'ඔබගේ පටිගත කිරීම් සහ ලේඛන ස්කෑන් කර සිංහල පෙළට ස්වයංක්‍රීයව හරවා ගන්න.',
  ),
  _OnboardingPage(
    icon: Icons.picture_as_pdf_outlined,
    color: AppTheme.accentTeal,
    title: 'වාර්තා සකසන්න',
    description:
        'පටිගත කිරීම් සහ ලේඛන එකට එකතු කර සාරාංශගත PDF වාර්තාවක් ක්ෂණිකව සකසා ගන්න.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      widget.onFinished();
      return;
    }
    _pageController.nextPage(
      duration: AppTheme.motionDuration,
      curve: AppTheme.motionCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AnimatedOpacity(
                  duration: AppTheme.motionDuration,
                  opacity: isLast ? 0 : 1,
                  child: TextButton(
                    onPressed: isLast ? null : widget.onFinished,
                    child: const Text('මඟහරින්න'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: page.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(page.icon, color: page.color, size: 64),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: AppTheme.motionDuration,
                  curve: AppTheme.motionCurve,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? AppTheme.accentTeal
                        : AppTheme.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? 'ආරම්භ කරන්න' : 'ඊළඟට'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
