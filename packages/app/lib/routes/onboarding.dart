import 'package:flutter/material.dart';
import 'package:bot_creator/utils/onboarding_manager.dart';
import 'package:bot_creator/utils/analytics.dart';
import 'package:bot_creator/utils/i18n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Root onboarding flow - presents 5 steps to guide new users through first bot creation
class OnboardingPage extends StatefulWidget {
  /// Called when onboarding is completed or skipped
  final VoidCallback onComplete;

  const OnboardingPage({super.key, required this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late OnboardingManager _manager;
  late PageController _pageController;
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initializeManager();
    AppAnalytics.logEvent(name: 'onboarding_started');
  }

  Future<void> _initializeManager() async {
    final prefs = await SharedPreferences.getInstance();
    _manager = OnboardingManager(prefs);
    setState(() {
      _currentStep = _manager.currentStep;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _pageController.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _manager.setCurrentStep(step);
    setState(() => _currentStep = step);
  }

  void _nextStep() {
    if (_currentStep < 5) {
      _goToStep(_currentStep + 1);
    }
  }

  void _skipOnboarding() async {
    await _manager.skipOnboarding();
    AppAnalytics.logEvent(
      name: 'onboarding_skipped',
      parameters: {'step': _currentStep.toString()},
    );
    if (mounted) {
      widget.onComplete();
    }
  }

  void _completeOnboarding() async {
    await _manager.completeOnboarding();
    AppAnalytics.logEvent(
      name: 'onboarding_completed',
      parameters: {'final_step': _currentStep.toString()},
    );
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics:
            const NeverScrollableScrollPhysics(), // Disable swipe, use buttons only
        children: [
          _WelcomeStep(onNext: _nextStep, onSkip: _skipOnboarding),
          _CreateBotStep(onNext: _nextStep, onSkip: _skipOnboarding),
          _AddCommandStep(onNext: _nextStep, onSkip: _skipOnboarding),
          _StartBotStep(onNext: _nextStep, onSkip: _skipOnboarding),
          _SuccessStep(onDone: _completeOnboarding),
        ],
      ),
      extendBody: true,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 1: Welcome
// ═════════════════════════════════════════════════════════════════════════════

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _WelcomeStep({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Large icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      size: 60,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Bienvenue dans Bot Creator',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Créez votre premier bot Discord en 3 étapes simples. '
                    'Nous vous guidons à travers chaque étape.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 48),

                  // Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: const Text(
                        'Commencer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onSkip,
                      child: const Text('Passer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 2: Create Bot
// ═════════════════════════════════════════════════════════════════════════════

class _CreateBotStep extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CreateBotStep({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(AppStrings.t('onboarding_create_title')),
        actions: [
          TextButton(
            onPressed: onSkip,
            child: Text(AppStrings.t('onboarding_welcome_skip')),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.key_rounded,
                    size: 50,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  AppStrings.t('onboarding_create_desc'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t('onboarding_create_steps'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    AppStrings.t('onboarding_create_tip'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_browser),
                    label: Text(AppStrings.t('onboarding_create_tutorial')),
                    onPressed: () {
                      // TODO: Open tutorial link
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
              ),
              child: Text(
                AppStrings.t('onboarding_create_button'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 3: Add Command
// ═════════════════════════════════════════════════════════════════════════════

class _AddCommandStep extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _AddCommandStep({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(AppStrings.t('onboarding_command_title')),
        actions: [
          TextButton(
            onPressed: onSkip,
            child: Text(AppStrings.t('onboarding_welcome_skip')),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.terminal_rounded,
                    size: 50,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  AppStrings.t('onboarding_command_desc'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t('onboarding_command_text'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exemple:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.t('onboarding_command_example'),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
              ),
              child: Text(
                AppStrings.t('onboarding_command_button'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 4: Start Bot
// ═════════════════════════════════════════════════════════════════════════════

class _StartBotStep extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _StartBotStep({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(AppStrings.t('onboarding_start_title')),
        actions: [
          TextButton(
            onPressed: onSkip,
            child: Text(AppStrings.t('onboarding_welcome_skip')),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 50,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  AppStrings.t('onboarding_start_desc'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppStrings.t('onboarding_start_text'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    AppStrings.t('onboarding_start_tip'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
              ),
              child: Text(
                AppStrings.t('onboarding_start_button'),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Step 5: Success
// ═════════════════════════════════════════════════════════════════════════════

class _SuccessStep extends StatelessWidget {
  final VoidCallback onDone;

  const _SuccessStep({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Large success icon with animation
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 70,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    AppStrings.t('onboarding_success_title'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    AppStrings.t('onboarding_success_desc'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    AppStrings.t('onboarding_success_whatsnext'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Column(
                    children: [
                      _TipRow(
                        icon: Icons.auto_fix_high,
                        title: AppStrings.t('onboarding_success_tip1'),
                      ),
                      _TipRow(
                        icon: Icons.workspaces,
                        title: AppStrings.t('onboarding_success_tip2'),
                      ),
                      _TipRow(
                        icon: Icons.backup,
                        title: AppStrings.t('onboarding_success_tip3'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onDone,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: Text(
                        AppStrings.t('onboarding_success_button'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const _TipRow({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.deepPurple, size: 24),
          const SizedBox(width: 16),
          Text(title),
        ],
      ),
    );
  }
}
