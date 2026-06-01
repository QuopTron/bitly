import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bitly/services/premium/premium_service.dart';
import 'package:bitly/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitly/providers/settings/settings_provider.dart';

final _log = AppLogger('SetupScreen');

class SetupScreen extends ConsumerStatefulWidget {
  final int initialStep;
  const SetupScreen({super.key, this.initialStep = 0});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late final PageController _pageController;
  int _currentStep = 0;
  bool _freeTrialActivated = false;
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

  static const int _totalPages = 5;

  @override
  void initState() {
    super.initState();
    _codigoController.addListener(_onCodigoChanged);
    _pageController = PageController(initialPage: widget.initialStep);
    _currentStep = widget.initialStep;

    SharedPreferences.getInstance().then((prefs) {
      final step = prefs.getInt('setup_initial_step');
      if (step != null) {
        prefs.remove('setup_initial_step');
        if (mounted) {
          _pageController.jumpToPage(step);
          setState(() => _currentStep = step);
        }
      }
    });

    _checkSavedState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedState() async {
    try {
      final success = await PremiumService.tryAutoRestore();
      if (!success || !mounted) return;

      final code = await PremiumService.getSavedPremiumCode();
      final username = await PremiumService.getSavedUsername();
      final until = await PremiumService.getPremiumUntil();

      if (!mounted) return;

      setState(() {
        if (code != null && code.isNotEmpty) {
          _codigoController.text = code;
        }
        if (until > 0) {
          _freeTrialActivated = true;
        }
        if (username != null && username.isNotEmpty) {
          _usernameController.text = username;
        }
      });

      _log.i('Auto-restored saved state: user=$username, premium=${code != null}');
    } catch (e) {
      _log.w('Failed to auto-restore state: $e');
    }
  }

  @override
  void didUpdateWidget(covariant SetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStep != oldWidget.initialStep) {
      final newStep = widget.initialStep.clamp(0, _totalPages - 1);
      _pageController.jumpToPage(newStep);
      setState(() => _currentStep = newStep);
    }
  }

  void _onCodigoChanged() {
    // Auto-save premium code
    final codigo = _codigoController.text;
    if (codigo.isNotEmpty && PremiumService.validarCodigo(codigo)) {
      PremiumService.activateCode(codigo).then((success) {
        if (success && mounted) {
          setState(() => _freeTrialActivated = true);
        }
      });
    }
  }

  void _nextPage() {
    if (_currentStep < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    } else {
      _completeSetup();
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _completeSetup() {
    ref.read(settingsProvider.notifier).setFirstLaunchComplete();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLastPage = _currentStep == _totalPages - 1;
    final scale = MediaQuery.sizeOf(context).shortestSide / 390;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final actionButtonHeight = (56 * scale) + ((textScale - 1) * 6);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Setup'),
        backgroundColor: colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentStep = page),
              children: [
                _buildWelcomeStep(),
                _buildPremiumStep(),
                _buildPermissionsStep(),
                _buildUsernameStep(),
                _buildCompleteStep(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentStep > 0 ? _prevPage : null,
                  child: const Text('Back'),
                ),
                FilledButton(
                  onPressed: _nextPage,
                  style: FilledButton.styleFrom(
                    minimumSize: Size(120, actionButtonHeight),
                  ),
                  child: Text(isLastPage ? 'Done' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 80,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStep() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Premium',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codigoController,
              decoration: InputDecoration(
                hintText: 'Enter premium code',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key, color: colorScheme.primary),
              ),
              onChanged: (value) {
                // Premium code validation
              },
            ),
            const SizedBox(height: 24),
            if (!_freeTrialActivated)
              FilledButton.icon(
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  try {
                    await PremiumService.startFreeTrial();
                    setState(() => _freeTrialActivated = true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Free trial activated (12h)')),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isLoading = false);
                    }
                  }
                },
                icon: const Icon(Icons.schedule),
                label: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Start Free Trial'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsStep() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Permissions',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            Icon(
              Icons.folder_open,
              size: 80,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'App will request storage permissions to download music',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Username',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                hintText: 'Enter your username',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setUsername(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            'Complete',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}