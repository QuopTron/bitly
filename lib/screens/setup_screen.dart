import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitly/services/premium/premium_service.dart';
import 'package:bitly/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  int? _selectedPlan;
  bool _freeTrialSelected = false;
  bool _freeTrialActivated = false;
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();

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
      final newStep = widget.initialStep.clamp(0, 4);
      _pageController.jumpToPage(newStep);
      setState(() => _currentStep = newStep);
    }
  }

  void _onCodigoChanged() {
    // Premium code validation removed
  }

  void _selectPlan(int plan) {
    if (_selectedPlan == plan) return;
    final shouldActivateTrial = plan == 1 && !_freeTrialActivated;
    setState(() {
      _selectedPlan = plan;
      _freeTrialSelected = plan == 1;
    });
    if (shouldActivateTrial) {
      _activateFreeTrialSelection();
    }
  }

  Future<void> _activateFreeTrialSelection() async {
    setState(() => _isLoading = true);
    try {
      await PremiumService.startFreeTrial();
      _freeTrialActivated = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prueba gratis de 1 día iniciada')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
      ),
      body: PageView(
        controller: _pageController,
        children: [
          _buildWelcomeStep(),
          _buildPremiumStep(),
          _buildPermissionsStep(),
          _buildUsernameStep(),
          _buildCompleteStep(),
        ],
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Welcome', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildPremiumStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Premium', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildPermissionsStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Permissions', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Username', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildCompleteStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Complete', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}
