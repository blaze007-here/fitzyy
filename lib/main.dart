import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'models/food_scan.dart';
import 'models/user_data.dart';
import 'services/food_analyzer.dart';
import 'services/camera_service.dart';
import 'services/supabase_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.supabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        // Mobile OAuth returns tokens directly to the registered app scheme.
        // This avoids losing a browser-side PKCE verifier when Android
        // recreates the activity during the handoff back from Google.
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }
  runApp(const CalorieScanApp());
}

class CalorieScanApp extends StatelessWidget {
  const CalorieScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fitzyy',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.supabaseConfigured) {
      return const AppShell(demoMode: true);
    }

    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (session == null) return const LoginScreen();
        return AppShell(
          demoMode: false,
          repository: SupabaseRepository(client),
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AppConfig.oauthRedirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: GlassCard(
                padding: const EdgeInsets.all(26),
                color: AppColors.surface.withAlpha(220),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: AppColors.background,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Eat with more clarity.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Sign in to save your scans, habits, foods, and personal goals across devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 26),
                    AppButton(
                      label: _busy
                          ? 'Opening Google...'
                          : 'Continue with Google',
                      icon: Icons.login_rounded,
                      onPressed: _busy ? null : _signInWithGoogle,
                      expanded: true,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Your account data is protected by Supabase Row Level Security.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({required this.demoMode, this.repository, super.key});

  final bool demoMode;
  final SupabaseRepository? repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  FoodScan? _latest;
  List<FoodScan> _history = [];
  UserProfile? _profile;
  UserPreferences? _preferences;
  UserSetting? _setting;
  List<CustomFood> _customFoods = [];
  List<UserHabit> _habits = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      _history = [sampleScans[1], sampleScans[2]];
      _loading = false;
    } else {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final data = await widget.repository!.loadUserData();
      if (!mounted) return;
      setState(() {
        _profile = data.profile;
        _preferences = data.preferences;
        _setting = data.setting;
        _history = data.scans;
        _customFoods = data.customFoods;
        _habits = data.habits;
        _latest = _history.isEmpty ? null : _history.first;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  void _openScanner() async {
    final result = await Navigator.of(context).push<FoodScan>(
      MaterialPageRoute(
        builder: (_) =>
            ScannerScreen(demoMode: widget.demoMode, customFoods: _customFoods),
      ),
    );
    if (!mounted || result == null) return;
    final saved = widget.demoMode
        ? result
        : await widget.repository!.saveScan(result);
    if (!mounted) return;
    setState(() {
      _latest = saved;
      _history.insert(0, saved);
    });
  }

  Future<void> _openPreferences() async {
    final result = await Navigator.of(context).push<PreferencesResult>(
      MaterialPageRoute(
        builder: (_) => PreferencesScreen(
          profile: _profile,
          preferences: _preferences,
          setting: _setting,
          customFoods: _customFoods,
          habits: _habits,
          repository: widget.repository,
          demoMode: widget.demoMode,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _profile = result.profile ?? _profile;
      _preferences = result.preferences ?? _preferences;
      _setting = result.setting ?? _setting;
      _customFoods = result.customFoods ?? _customFoods;
      _habits = result.habits ?? _habits;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: GlowBackground(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.lime),
          ),
        ),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        body: GlowBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: GlassCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.warning,
                      size: 42,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Could not load your account',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppButton(
                      label: 'Try again',
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _loadUserData();
                      },
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => widget.repository!.signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final pages = [
      DashboardScreen(
        latest: _latest,
        history: _history,
        preferences: _preferences,
        profile: _profile,
        onScan: _openScanner,
        onPreferences: _openPreferences,
        demoMode: widget.demoMode,
      ),
      HistoryScreen(history: _history),
      ProfileScreen(
        profile: _profile,
        preferences: _preferences,
        setting: _setting,
        onPreferences: _openPreferences,
        onSignOut: widget.demoMode ? null : widget.repository!.signOut,
      ),
    ];
    return Scaffold(
      body: GlowBackground(child: SafeArea(child: pages[_tab])),
      extendBody: true,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.latest,
    required this.history,
    required this.preferences,
    required this.profile,
    required this.onScan,
    required this.onPreferences,
    required this.demoMode,
    super.key,
  });

  final FoodScan? latest;
  final List<FoodScan> history;
  final UserPreferences? preferences;
  final UserProfile? profile;
  final VoidCallback onScan;
  final VoidCallback onPreferences;
  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 360 ? 14.0 : 20.0;
    final now = DateTime.now();
    final dayScans = demoMode
        ? history
        : history.where((scan) {
            final date = scan.scannedAt?.toLocal();
            return date != null &&
                date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
          }).toList();
    final consumed = dayScans.fold<int>(
      0,
      (sum, scan) => sum + scan.nutrition.calories,
    );
    final protein = dayScans.fold<double>(
      0,
      (sum, scan) => sum + scan.nutrition.protein,
    );
    final carbs = dayScans.fold<double>(
      0,
      (sum, scan) => sum + scan.nutrition.carbs,
    );
    final fat = dayScans.fold<double>(
      0,
      (sum, scan) => sum + scan.nutrition.fat,
    );
    final goal = preferences?.dailyCalorieGoal ?? (demoMode ? 2100 : 0);
    final dateLabel = _dateLabel(now);
    final displayName = profile?.displayName.trim();
    final greeting = displayName == null || displayName.isEmpty
        ? 'Welcome back'
        : 'Good morning, $displayName';
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        120,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    greeting,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GlassCard(
              padding: const EdgeInsets.all(11),
              borderRadius: 16,
              onTap: onPreferences,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.ink,
                size: 21,
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        GlassCard(
          padding: const EdgeInsets.all(22),
          color: AppColors.surface.withAlpha(210),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Today\'s fuel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      goal == 0
                          ? '$consumed kcal logged'
                          : '$consumed / $goal kcal',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: goal == 0 ? 0 : (consumed / goal).clamp(0, 1),
                  minHeight: 9,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(AppColors.lime),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _MiniStat(
                    label: 'Protein',
                    value: '${formatNumber(protein)} g',
                    color: AppColors.purple,
                  ),
                  _MiniStat(
                    label: 'Carbs',
                    value: '${formatNumber(carbs)} g',
                    color: AppColors.orange,
                  ),
                  _MiniStat(
                    label: 'Fats',
                    value: '${formatNumber(fat)} g',
                    color: AppColors.aqua,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        GlassCard(
          padding: EdgeInsets.zero,
          color: AppColors.lime,
          onTap: onScan,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.background.withAlpha(220),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.center_focus_weak_rounded,
                    color: AppColors.lime,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan your food',
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Point, hover, and get the full picture',
                        style: TextStyle(
                          color: Color(0xB20A0D14),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.background,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        const SectionTitle(title: 'Latest insight', action: 'View all'),
        const SizedBox(height: 12),
        _InsightCard(scan: latest),
        const SizedBox(height: 28),
        const SectionTitle(title: 'Recent scans'),
        const SizedBox(height: 12),
        ...history
            .take(3)
            .map(
              (scan) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryRow(scan: scan),
              ),
            ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    ),
  );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.scan});
  final FoodScan? scan;

  @override
  Widget build(BuildContext context) {
    if (scan == null) {
      return const GlassCard(
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.lime, size: 30),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your personal insights will appear here after you save your first scan.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final selected = scan!;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(selected.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected.subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _RatingBadge(rating: selected.rating),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            selected.insight,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});
  final int rating;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.lime.withAlpha(24),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '$rating',
      style: const TextStyle(
        color: AppColors.lime,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.scan});
  final FoodScan scan;
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    borderRadius: 18,
    child: Row(
      children: [
        Text(scan.emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scan.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${scan.nutrition.calories} kcal · ${scan.serving}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ],
    ),
  );
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    required this.demoMode,
    required this.customFoods,
    super.key,
  });

  final bool demoMode;
  final List<CustomFood> customFoods;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  bool _analyzing = false;
  int _choice = 0;
  bool _cameraInitializing = true;
  bool _flashOn = false;
  final CameraService _cameraService = CameraService(
    resolutionPreset: ResolutionPreset.medium,
  );

  List<FoodScan> get availableScans =>
      widget.demoMode ? sampleScans : const <FoodScan>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _cameraService.initialize();
    if (!mounted) return;
    setState(() => _cameraInitializing = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed && !_analyzing) {
      setState(() => _cameraInitializing = true);
      _restartCamera();
    }
  }

  Future<void> _restartCamera() async {
    await _cameraService.dispose();
    await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final nextMode = _flashOn ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(nextMode);
      if (mounted) setState(() => _flashOn = !_flashOn);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available on this camera.')),
      );
    }
  }

  Future<void> _scan() async {
    if (!widget.demoMode && !_cameraService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The camera is not ready yet.')),
      );
      return;
    }
    if (widget.demoMode && availableScans.isEmpty) return;
    setState(() => _analyzing = true);
    try {
      final photo = await _cameraService.takePicture();
      final scan = widget.demoMode
          ? await MockFoodAnalyzer(
              result: availableScans[_choice],
            ).analyze(image: photo)
          : await VisionFoodAnalyzer(
              Supabase.instance.client,
            ).analyze(image: photo);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(scan: scan)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Food analysis failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            final horizontal = constraints.maxWidth < 360 ? 14.0 : 20.0;
            final availableWidth = math.max(
              0.0,
              constraints.maxWidth - (horizontal * 2),
            );
            final frameSize = math.min(
              availableWidth,
              math.min(360.0, constraints.maxHeight * (compact ? .34 : .42)),
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0.0, constraints.maxHeight - 34),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const Expanded(
                          child: Text(
                            'AI FOOD SCANNER',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleFlash,
                          icon: Icon(
                            _flashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_auto_rounded,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 12 : 24),
                    _CameraFrame(size: frameSize, service: _cameraService),
                    SizedBox(height: compact ? 16 : 24),
                    const Text(
                      'Hover over your meal',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Keep the whole plate inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 18),
                    if (!widget.demoMode)
                      const GlassCard(
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Point the camera at any meal. Fitzyy will send the photo to your configured vision model and return an estimated nutrition breakdown.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GlassCard(
                        padding: const EdgeInsets.all(10),
                        borderRadius: 18,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _choice,
                            isExpanded: true,
                            dropdownColor: AppColors.surfaceRaised,
                            items: List.generate(
                              availableScans.length,
                              (i) => DropdownMenuItem(
                                value: i,
                                child: Text(
                                  widget.demoMode
                                      ? 'Demo food: ${availableScans[i].name}'
                                      : availableScans[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            onChanged: (value) =>
                                setState(() => _choice = value ?? 0),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    AppButton(
                      label: _analyzing
                          ? 'Analyzing plate...'
                          : widget.demoMode
                          ? 'Analyze sample'
                          : 'Scan & analyze with AI',
                      icon: Icons.camera_alt_rounded,
                      onPressed:
                          _analyzing ||
                              (widget.demoMode
                                  ? availableScans.isEmpty
                                  : !_cameraService.isInitialized)
                          ? null
                          : _scan,
                      expanded: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _cameraInitializing
                          ? 'Requesting camera permission...'
                          : _cameraService.isInitialized
                          ? widget.demoMode
                                ? 'Demo mode uses a local nutrition model.'
                                : 'Camera ready. The vision model will identify the meal in the photo.'
                          : widget.demoMode
                          ? 'Camera unavailable. You can still preview a local nutrition result.'
                          : 'Camera unavailable. Grant camera permission and try again.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({required this.size, required this.service});

  final double size;
  final CameraService service;

  @override
  Widget build(BuildContext context) {
    final controller = service.controller;
    final ready = controller?.value.isInitialized ?? false;
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              CameraPreview(controller!)
            else
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF111722)),
                child: Center(
                  child: Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.muted,
                    size: 42,
                  ),
                ),
              ),
            CustomPaint(painter: CameraBackdropPainter()),
            if (!ready && service.error != null)
              const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Camera preview unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CameraBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lime.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .42),
      width: size.width * .72,
      height: size.width * .72,
    );
    canvas.drawArc(rect, -1.57, .9, false, paint);
    canvas.drawArc(rect, 0, .9, false, paint);
    canvas.drawArc(rect, 1.57, .9, false, paint);
    canvas.drawArc(rect, 3.14, .9, false, paint);
    final dot = Paint()..color = AppColors.lime.withAlpha(80);
    canvas.drawCircle(rect.center, 5, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({required this.scan, super.key});
  final FoodScan scan;
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  double _portion = 1;

  @override
  Widget build(BuildContext context) {
    final n = widget.scan.nutrition.scaled(_portion);
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 20.0;
    return Scaffold(
      body: GlowBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              14,
              horizontalPadding,
              34,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'SCAN RESULT',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 12),
              GlassCard(
                color: AppColors.surface.withAlpha(230),
                child: Column(
                  children: [
                    Text(
                      widget.scan.emoji,
                      style: const TextStyle(fontSize: 58),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.scan.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.scan.subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppColors.lime,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${(widget.scan.confidence * 100).round()}% AI confidence',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.lime,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            '${n.calories}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.lime,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'CALORIES',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            widget.scan.rating.toString(),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.purple,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'FOOD RATING',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nutrition breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _NutrientBar(
                      label: 'Protein',
                      value: '${formatNumber(n.protein)} g',
                      progress: n.protein / 45,
                      color: AppColors.purple,
                    ),
                    _NutrientBar(
                      label: 'Carbohydrates',
                      value: '${formatNumber(n.carbs)} g',
                      progress: n.carbs / 60,
                      color: AppColors.orange,
                    ),
                    _NutrientBar(
                      label: 'Fat',
                      value: '${formatNumber(n.fat)} g',
                      progress: n.fat / 30,
                      color: AppColors.aqua,
                    ),
                    _NutrientBar(
                      label: 'Fiber',
                      value: '${formatNumber(n.fiber)} g',
                      progress: n.fiber / 15,
                      color: AppColors.lime,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Sodium',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '${formatNumber(n.sodium)} mg',
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adjust portion',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Slider(
                      value: _portion,
                      min: .5,
                      max: 2,
                      divisions: 6,
                      label: '${(_portion * 100).round()}%',
                      onChanged: (value) => setState(() => _portion = value),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.scan.serving,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${(_portion * 100).round()}% serving',
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.lime,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: 'Save to today',
                icon: Icons.check_rounded,
                expanded: true,
                onPressed: () =>
                    Navigator.pop(context, widget.scan.copyWith(nutrition: n)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientBar extends StatelessWidget {
  const _NutrientBar({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });
  final String label;
  final String value;
  final double progress;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    ),
  );
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({required this.history, super.key});
  final List<FoodScan> history;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
    children: [
      const Text(
        'Your history',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 7),
      const Text(
        'A simple record of your recent meals.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 26),
      ...history.map(
        (scan) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _HistoryRow(scan: scan),
        ),
      ),
    ],
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    required this.profile,
    required this.preferences,
    required this.setting,
    required this.onPreferences,
    required this.onSignOut,
    super.key,
  });

  final UserProfile? profile;
  final UserPreferences? preferences;
  final UserSetting? setting;
  final VoidCallback onPreferences;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName.trim();
    final displayName = name == null || name.isEmpty ? 'Your account' : name;
    final initial = displayName == 'Your account'
        ? '?'
        : displayName[0].toUpperCase();
    final goal = preferences?.dailyCalorieGoal;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        const Text(
          'Your profile',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        const Text(
          'Make Fitzyy fit the way you live.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 26),
        GlassCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.lime,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.background,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  profile?.goalLabel ?? 'Personal goals',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              const Divider(color: AppColors.line),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined, color: AppColors.lime),
                title: const Text('Daily calorie goal'),
                trailing: Text(
                  goal == null ? 'Not set' : '$goal kcal',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AppColors.purple,
                ),
                title: const Text('Privacy-first mode'),
                trailing: Icon(
                  setting?.privacyMode == false
                      ? Icons.toggle_off_rounded
                      : Icons.toggle_on_rounded,
                  color: setting?.privacyMode == false
                      ? AppColors.muted
                      : AppColors.lime,
                  size: 32,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Edit goals, foods & habits',
          icon: Icons.tune_rounded,
          onPressed: onPreferences,
          expanded: true,
        ),
        if (onSignOut != null) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            secondary: true,
            onPressed: onSignOut,
          ),
        ],
      ],
    );
  }
}

class PreferencesResult {
  const PreferencesResult({
    this.profile,
    this.preferences,
    this.setting,
    this.customFoods,
    this.habits,
  });

  final UserProfile? profile;
  final UserPreferences? preferences;
  final UserSetting? setting;
  final List<CustomFood>? customFoods;
  final List<UserHabit>? habits;
}

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({
    required this.profile,
    required this.preferences,
    required this.setting,
    required this.customFoods,
    required this.habits,
    required this.repository,
    required this.demoMode,
    super.key,
  });

  final UserProfile? profile;
  final UserPreferences? preferences;
  final UserSetting? setting;
  final List<CustomFood> customFoods;
  final List<UserHabit> habits;
  final SupabaseRepository? repository;
  final bool demoMode;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _calorieController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late List<CustomFood> _foods;
  late List<UserHabit> _habits;
  late bool _privacyMode;
  bool _saving = false;

  UserPreferences get _basePreferences =>
      widget.preferences ?? const UserPreferences(userId: 'local');
  UserProfile get _baseProfile =>
      widget.profile ?? const UserProfile(id: 'local');

  @override
  void initState() {
    super.initState();
    final preferences = _basePreferences;
    _nameController = TextEditingController(text: _baseProfile.displayName);
    _calorieController = TextEditingController(
      text: preferences.dailyCalorieGoal.toString(),
    );
    _proteinController = TextEditingController(
      text: preferences.proteinGoal.toString(),
    );
    _carbsController = TextEditingController(
      text: preferences.carbsGoal.toString(),
    );
    _fatController = TextEditingController(
      text: preferences.fatGoal.toString(),
    );
    _foods = [...widget.customFoods];
    _habits = [...widget.habits];
    _privacyMode = widget.setting?.privacyMode ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _calorieController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calorieGoal = int.tryParse(_calorieController.text.trim());
    final proteinGoal = double.tryParse(_proteinController.text.trim());
    final carbsGoal = double.tryParse(_carbsController.text.trim());
    final fatGoal = double.tryParse(_fatController.text.trim());
    if (calorieGoal == null ||
        calorieGoal <= 0 ||
        proteinGoal == null ||
        carbsGoal == null ||
        fatGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid positive nutrition goals.')),
      );
      return;
    }
    final profile = _baseProfile.copyWith(
      displayName: _nameController.text.trim(),
    );
    final preferences = _basePreferences.copyWith(
      dailyCalorieGoal: calorieGoal,
      proteinGoal: proteinGoal,
      carbsGoal: carbsGoal,
      fatGoal: fatGoal,
    );
    final setting = UserSetting(
      userId: _baseProfile.id,
      privacyMode: _privacyMode,
      notificationsEnabled: widget.setting?.notificationsEnabled ?? true,
    );
    setState(() => _saving = true);
    try {
      if (!widget.demoMode) {
        await widget.repository!.updateProfile(profile);
        await widget.repository!.updatePreferences(preferences);
        await widget.repository!.updateSetting(setting);
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        PreferencesResult(
          profile: profile,
          preferences: preferences,
          setting: setting,
          customFoods: _foods,
          habits: _habits,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save preferences: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editFood(CustomFood food) async {
    await _showFoodDialog(existing: food);
  }

  Future<void> _showFoodDialog({CustomFood? existing}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddFoodDialog(initial: existing),
    );
    if (!mounted || result == null) return;
    final nutrition = NutritionSnapshot(
      calories: result['calories'] as int,
      protein: result['protein'] as double,
      carbs: result['carbs'] as double,
      fat: result['fat'] as double,
      fiber: result['fiber'] as double,
      sodium: result['sodium'] as double,
    );
    try {
      final food = existing == null
          ? widget.demoMode
                ? CustomFood(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    userId: _baseProfile.id,
                    name: result['name'] as String,
                    serving: result['serving'] as String,
                    nutrition: nutrition,
                  )
                : await widget.repository!.addCustomFood(
                    name: result['name'] as String,
                    serving: result['serving'] as String,
                    nutrition: nutrition,
                  )
          : widget.demoMode
          ? existing.copyWith(
              name: result['name'] as String,
              serving: result['serving'] as String,
              nutrition: nutrition,
            )
          : await widget.repository!.updateCustomFood(
              existing.copyWith(
                name: result['name'] as String,
                serving: result['serving'] as String,
                nutrition: nutrition,
              ),
            );
      if (!mounted) return;
      setState(() {
        if (existing == null) {
          _foods.add(food);
        } else {
          final index = _foods.indexWhere((item) => item.id == existing.id);
          if (index >= 0) _foods[index] = food;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save food: $error')));
      }
    }
  }

  Future<void> _addFood() => _showFoodDialog();

  Future<void> _deleteFood(CustomFood food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text('Delete ${food.name}?'),
        content: const Text(
          'This removes the food from your personal library. Existing scan history stays unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      if (!widget.demoMode) await widget.repository!.deleteCustomFood(food);
      if (!mounted) return;
      setState(() => _foods.removeWhere((item) => item.id == food.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete food: $error')),
        );
      }
    }
  }

  Future<void> _addHabit() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddHabitDialog(),
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    final habit = widget.demoMode
        ? UserHabit(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            userId: _baseProfile.id,
            name: name.trim(),
          )
        : await widget.repository!.addHabit(name: name.trim());
    setState(() => _habits.add(habit));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalize Fitzyy'),
        backgroundColor: Colors.transparent,
      ),
      body: GlowBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your basics',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Nutrition targets',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _GoalField(
                    controller: _calorieController,
                    label: 'Daily calories',
                    suffix: 'kcal',
                  ),
                  _GoalField(
                    controller: _proteinController,
                    label: 'Protein',
                    suffix: 'g',
                  ),
                  _GoalField(
                    controller: _carbsController,
                    label: 'Carbohydrates',
                    suffix: 'g',
                  ),
                  _GoalField(
                    controller: _fatController,
                    label: 'Fat',
                    suffix: 'g',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Privacy-first mode'),
                    subtitle: const Text(
                      'Keep scan images out of storage by default',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    value: _privacyMode,
                    activeThumbColor: AppColors.lime,
                    onChanged: (value) => setState(() => _privacyMode = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My foods',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: _addFood,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: AppColors.lime,
                        ),
                      ),
                    ],
                  ),
                  if (_foods.isEmpty)
                    const Text(
                      'Add foods you eat often to reuse their nutrition.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    )
                  else
                    ..._foods.map(
                      (food) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.restaurant_menu_rounded,
                          color: AppColors.orange,
                        ),
                        title: Text(food.name),
                        subtitle: Text(
                          '${food.nutrition.calories} kcal · ${food.serving}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => _editFood(food),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit ${food.name}',
                              onPressed: () => _editFood(food),
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.lime,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete ${food.name}',
                              onPressed: () => _deleteFood(food),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My habits',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: _addHabit,
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: AppColors.lime,
                        ),
                      ),
                    ],
                  ),
                  if (_habits.isEmpty)
                    const Text(
                      'Add habits like water, vegetables, or mindful eating.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    )
                  else
                    ..._habits.map(
                      (habit) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppColors.aqua,
                        ),
                        title: Text(habit.name),
                        subtitle: Text(
                          'Target: ${habit.target} ${habit.unit}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: _saving ? 'Saving...' : 'Save preferences',
              icon: Icons.save_outlined,
              expanded: true,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.controller,
    required this.label,
    required this.suffix,
  });
  final TextEditingController controller;
  final String label;
  final String suffix;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    ),
  );
}

class _AddFoodDialog extends StatefulWidget {
  const _AddFoodDialog({this.initial});

  final CustomFood? initial;

  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<_AddFoodDialog> {
  final _name = TextEditingController();
  final _serving = TextEditingController(text: '1 serving');
  final _calories = TextEditingController();
  final _protein = TextEditingController(text: '0');
  final _carbs = TextEditingController(text: '0');
  final _fat = TextEditingController(text: '0');
  final _fiber = TextEditingController(text: '0');
  final _sodium = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    final food = widget.initial;
    if (food == null) return;
    _name.text = food.name;
    _serving.text = food.serving;
    _calories.text = food.nutrition.calories.toString();
    _protein.text = food.nutrition.protein.toString();
    _carbs.text = food.nutrition.carbs.toString();
    _fat.text = food.nutrition.fat.toString();
    _fiber.text = food.nutrition.fiber.toString();
    _sodium.text = food.nutrition.sodium.toString();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _serving,
      _calories,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sodium,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final calories = int.tryParse(_calories.text);
    final values = [
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sodium,
    ].map((controller) => double.tryParse(controller.text)).toList();
    if (_name.text.trim().isEmpty ||
        calories == null ||
        values.any((value) => value == null)) {
      return;
    }
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'serving': _serving.text.trim(),
      'calories': calories,
      'protein': values[0]!,
      'carbs': values[1]!,
      'fat': values[2]!,
      'fiber': values[3]!,
      'sodium': values[4]!,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surfaceRaised,
    title: Text(widget.initial == null ? 'Add a food' : 'Edit food'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dialogField(_name, 'Food name'),
          _dialogField(_serving, 'Serving'),
          _dialogField(_calories, 'Calories', number: true),
          _dialogField(_protein, 'Protein (g)', number: true),
          _dialogField(_carbs, 'Carbs (g)', number: true),
          _dialogField(_fat, 'Fat (g)', number: true),
          _dialogField(_fiber, 'Fiber (g)', number: true),
          _dialogField(_sodium, 'Sodium (mg)', number: true),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.initial == null ? 'Add' : 'Save'),
      ),
    ],
  );

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _AddHabitDialog extends StatefulWidget {
  const _AddHabitDialog();
  @override
  State<_AddHabitDialog> createState() => _AddHabitDialogState();
}

class _AddHabitDialogState extends State<_AddHabitDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surfaceRaised,
    title: const Text('Add a habit'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Habit name',
        hintText: 'e.g. Drink water',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Add'),
      ),
    ],
  );
}
