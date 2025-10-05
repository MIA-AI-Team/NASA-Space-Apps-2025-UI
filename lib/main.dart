import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:animated_background/animated_background.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class PlanetPainter extends CustomPainter {
  final double angle;

  PlanetPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final sunRadius = 30.0;
    final planet1OrbitRadius = 80.0;
    final planet2OrbitRadius = 130.0;

    // Draw Sun
    canvas.drawCircle(center, sunRadius, Paint()..color = Colors.yellow);

    // Draw Planet 1
    final planet1X = center.dx + planet1OrbitRadius * cos(angle);
    final planet1Y = center.dy + planet1OrbitRadius * sin(angle);
    canvas.drawCircle(
      Offset(planet1X, planet1Y),
      10.0,
      Paint()..color = Colors.blue,
    );

    // Draw Planet 2 (with a different speed/offset)
    final planet2X =
        center.dx + planet2OrbitRadius * cos(angle * 0.7); // Slower orbit
    final planet2Y = center.dy + planet2OrbitRadius * sin(angle * 0.7);
    canvas.drawCircle(
      Offset(planet2X, planet2Y),
      15.0,
      Paint()..color = Colors.red,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint as the angle changes
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M.I.A AI - Exoplanet Classifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
          primary: Colors.indigo.shade200,
          secondary: Colors.cyan.shade300,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// Enum to manage the different states of our page
enum PageState { input, loading, result }

class ExoplanetHomePage extends StatefulWidget {
  const ExoplanetHomePage({super.key, required this.title});

  final String title;

  @override
  State<ExoplanetHomePage> createState() => _ExoplanetHomePageState();
}

class _ExoplanetHomePageState extends State<ExoplanetHomePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  // Keys to identify and scroll to different sections of the page.
  final _identifierSectionKey = GlobalKey();
  final _analysisSectionKey = GlobalKey();
  final _teamSectionKey = GlobalKey();
  final _contactSectionKey = GlobalKey();

  // State management variables
  PageState _pageState = PageState.input;
  String _predictionResult = '';
  String _predictionCertainty = '';
  // Controllers to get the text from TextFormFields
  final _orbitalPeriodController = TextEditingController();
  final _transitDurationController = TextEditingController();
  final _planetaryRadiusController = TextEditingController();
  final _stellarRadiusController = TextEditingController();

  Future<void> _getExoplanetPrediction() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _pageState = PageState.loading;
      });
      // const apiUrl = String.fromEnvironment('API_URL');
      const apiUrl =
          "https://nasa-space-apps-backend-production.up.railway.app/predict";
      final dio = Dio();

      try {
        final response = await dio.post(
          apiUrl,
          data: {
            'koi_period': double.parse(_orbitalPeriodController.text),
            'koi_duration': double.parse(_transitDurationController.text),
            'koi_prad': double.parse(_planetaryRadiusController.text),
            'koi_srad': double.parse(_stellarRadiusController.text),
          },
        );

        // With dio, a successful response (2xx) is handled here.
        // dio automatically decodes the JSON response.
        final result = response.data;
        _predictionResult = result['prediction'] ?? 'N/A';
        _predictionCertainty = '';
      } on DioException catch (e) {
        // Non-2xx status codes and other connection errors are caught here.
        if (e.response != null) {
          _predictionResult = 'ERROR';
          _predictionCertainty = 'Status: ${e.response?.statusCode}';
        } else {
          _predictionResult = 'ERROR';
          _predictionCertainty = 'Connection Failed';
        }
        print(e);
      }

      setState(() {
        _pageState = PageState.result;
      });
    }
  }

  @override
  void dispose() {
    _orbitalPeriodController.dispose();
    _transitDurationController.dispose();
    _planetaryRadiusController.dispose();
    _stellarRadiusController.dispose();
    super.dispose();
  }

  // Function to handle smooth scrolling to a given section key.
  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using a Builder here provides a new BuildContext that is inside the Scaffold's
    // body, which is essential for the Scrollable.ensureVisible to find the keys.
    return Builder(
      builder: (context) {
        return Scaffold(
          // extendBodyBehindAppBar: true,
          appBar: AppBar(
            // This AppBar seems to have been added by mistake, let's remove it.
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'M.I.A AI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: Colors.red,
                  ),
                ),
                // This builder creates a smooth fade-in and slide-down animation for the subtitle.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 3000),
                  curve: Curves.easeIn,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Padding(
                        padding: EdgeInsets.only(top: value * 4),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    'NASA Space Apps 2025',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: Colors.lightBlue.shade200,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              // Use a LayoutBuilder to make the AppBar responsive.
              LayoutBuilder(
                builder: (context, constraints) {
                  // On wider screens, show text buttons.
                  if (MediaQuery.of(context).size.width > 600) {
                    return Row(
                      children: [
                        _appBarButton('Classifier', _identifierSectionKey),
                        _appBarButton('Analysis', _analysisSectionKey),
                        _appBarButton('Team', _teamSectionKey),
                        _appBarButton('Contact', _contactSectionKey),
                        const SizedBox(width: 8),
                      ],
                    );
                  } else {
                    // On smaller screens, use a popup menu to save space.
                    return PopupMenuButton<GlobalKey>(
                      icon: const Icon(Icons.menu),
                      onSelected: _scrollToSection,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _identifierSectionKey,
                          child: Text('Classifier'),
                        ),
                        PopupMenuItem(
                          value: _analysisSectionKey,
                          child: Text('Analysis'),
                        ),
                        PopupMenuItem(
                          value: _teamSectionKey,
                          child: Text('Team'),
                        ),
                        PopupMenuItem(
                          value: _contactSectionKey,
                          child: Text('Contact'),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // Layer 2: Animated Starfield
              AnimatedBackground(
                vsync: this,
                behaviour: RandomParticleBehaviour(
                  options: const ParticleOptions(
                    baseColor: Colors.white,
                    spawnOpacity: 0.0,
                    opacityChangeRate: 0.25,
                    minOpacity: 0.1,
                    maxOpacity: 0.4,
                    particleCount: 70,
                    spawnMaxRadius: 5,
                    spawnMinRadius: 1.0,
                    spawnMaxSpeed: 15.0,
                    spawnMinSpeed: 15.0,
                  ),
                ),
                child: Container(),
              ),
              // Layer 2.5: Custom Orbiting Planets Animation
              // const OrbitingPlanetsAnimation(),
              // Layer 3: Main Scrollable Content
              SingleChildScrollView(
                child: Column(
                  children: [
                    // This container ensures the main content fills at least the viewport height.
                    Container(
                      key: _identifierSectionKey,
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height,
                      ),
                      child: Center(
                        // This switcher animates between the input, loading, and result widgets
                        child: PageTransitionSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder:
                              (child, primaryAnimation, secondaryAnimation) {
                                return FadeThroughTransition(
                                  animation: primaryAnimation,
                                  secondaryAnimation: secondaryAnimation,
                                  child: child,
                                );
                              },
                          child: _buildPageContent(),
                        ),
                      ),
                    ),
                    // Attach the key to the analysis view for scrolling.
                    Container(
                      key: _analysisSectionKey,
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height,
                      ),
                      // Center the analysis card within the full-height section.
                      child: const Center(child: _ModelAnalysisView()),
                    ),
                    // Attach the key to the team view for scrolling.
                    Container(
                      key: _teamSectionKey,
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height,
                      ),
                      child: const Center(child: _TeamSectionView()),
                    ),
                    // Attach the key to the contact view for scrolling.
                    Container(
                      key: _contactSectionKey,
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height,
                      ),
                      child: const Center(child: _ContactSectionView()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Builds the widget corresponding to the current page state
  Widget _buildPageContent() {
    switch (_pageState) {
      case PageState.loading:
        return const _LoadingView();
      case PageState.result:
        return _ResultView(
          prediction: _predictionResult,
          certainty: _predictionCertainty,
          onReset: () => setState(() => _pageState = PageState.input),
        );
      case PageState.input:
        return _InputView(
          formKey: _formKey,
          orbitalPeriodController: _orbitalPeriodController,
          transitDurationController: _transitDurationController,
          planetaryRadiusController: _planetaryRadiusController,
          stellarRadiusController: _stellarRadiusController,
          onAnalyze: _getExoplanetPrediction,
        );
    }
  }

  // Helper widget for creating styled AppBar buttons.
  Widget _appBarButton(String title, GlobalKey key) {
    return TextButton(
      onPressed: () => _scrollToSection(key),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      child: Text(title),
    );
  }
}

class OrbitingPlanetsAnimation extends StatefulWidget {
  const OrbitingPlanetsAnimation({super.key});

  @override
  State<OrbitingPlanetsAnimation> createState() =>
      _OrbitingPlanetsAnimationState();
}

class _OrbitingPlanetsAnimationState extends State<OrbitingPlanetsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          // The painter will use the controller's value to calculate the angle.
          // We multiply by 2*pi for a full 360-degree rotation.
          painter: PlanetPainter(_controller.value * 2 * pi),
          child: Container(),
        );
      },
    );
  }
}

class _ModelAnalysisView extends StatelessWidget {
  const _ModelAnalysisView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Colors.black.withOpacity(0.2),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade800, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Current Model Analysis',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatColumn(title: 'Accuracy', value: '98.2%'),
                  _StatColumn(title: 'Dataset', value: 'Kepler (Q1-Q17)'),
                  _StatColumn(title: 'Model', value: 'Random Forest'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}

class _TeamSectionView extends StatelessWidget {
  const _TeamSectionView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Meet Our Team',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 40),
          // Use a Wrap widget for responsiveness. It will arrange children
          // in a row and wrap to the next line if space is tight.
          const Wrap(
            spacing: 24.0,
            runSpacing: 24.0,
            alignment: WrapAlignment.center,
            children: [
              _TeamMemberCard(
                name: 'Hana Ramah',
                role: 'AI leader',
                githubUrl: 'https://github.com/HanaRamah',
                linkedinUrl: 'https://www.linkedin.com/in/hana-ramah',
              ),
              _TeamMemberCard(
                name: 'Seif Shaheen',
                role: 'AI member / Frontend',
                githubUrl: 'https://github.com/SeifShaheen',
                linkedinUrl: 'https://www.linkedin.com/in/seif-shaheen/',
              ),
              _TeamMemberCard(
                name: 'Jana Ghoneim',
                role: 'AI member / Backend',
                githubUrl: 'https://github.com/JanaGh7',
                linkedinUrl: 'https://linkedin.com/in/jana-ghoneim',
              ),
              _TeamMemberCard(
                name: 'Mostafa Mokhtar',
                role: 'AI member',
                githubUrl: 'https://github.com/MostafaMokhtar8545',
                linkedinUrl: 'http://linkedin.com/in/m-mokhtar',
              ),
              _TeamMemberCard(
                name: 'Esraa Khaled',
                role: 'AI member',
                githubUrl: 'https://github.com/esraakh299',
                linkedinUrl:
                    'https://www.linkedin.com/in/esraa-khaled-706b70202/',
              ),
              _TeamMemberCard(
                name: 'Mohamed Alaa',
                role: 'AI member',
                githubUrl: 'https://github.com/MohamedAlaa2005',
                linkedinUrl:
                    'https://www.linkedin.com/in/mohamed-alaa-62206229b',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.name,
    required this.role,
    this.githubUrl,
    this.linkedinUrl,
  });
  final String name;
  final String role;
  final String? githubUrl;
  final String? linkedinUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black.withOpacity(0.2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade800, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.red,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(name, style: const TextStyle(fontSize: 25)),
              const SizedBox(height: 4),
              Text(
                role,
                style: TextStyle(fontSize: 16, color: Colors.red.shade500),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (githubUrl != null)
                    IconButton(
                      icon: const Image(
                        image: AssetImage('assets/images/github_dark.png'),
                        width: 35,
                        height: 35,
                        color: Colors.white,
                      ),
                      tooltip: 'GitHub',
                      onPressed: () => launchUrl(
                        Uri.parse(githubUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  if (linkedinUrl != null)
                    IconButton(
                      // Using a generic icon. For the LinkedIn logo,
                      // you could add a package like `font_awesome_flutter`.
                      icon: const Image(
                        image: AssetImage('assets/images/linkedin.png'),
                        width: 45,
                        height: 45,
                        color: Colors.white,
                      ),
                      tooltip: 'LinkedIn',
                      onPressed: () => launchUrl(
                        Uri.parse(linkedinUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactSectionView extends StatelessWidget {
  const _ContactSectionView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        color: Colors.black.withOpacity(0.2),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade800, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Get In Touch',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 8),
              const Text(
                'We\'d love to hear from you!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const SelectableText('made.in.alexandria.ai@gmail.com'),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () async {
                  const url = 'https://github.com/MIA-AI-Team';
                  final Uri uri = Uri.parse(url);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Image(
                  image: AssetImage('assets/images/github_dark.png'),
                  width: 30,
                  height: 30,
                ),
                label: const Text('View on GitHub'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The view for user input
class _InputView extends StatelessWidget {
  const _InputView({
    required this.formKey,
    required this.orbitalPeriodController,
    required this.transitDurationController,
    required this.planetaryRadiusController,
    required this.stellarRadiusController,
    required this.onAnalyze,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController orbitalPeriodController;
  final TextEditingController transitDurationController;
  final TextEditingController planetaryRadiusController;
  final TextEditingController stellarRadiusController;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.travel_explore,
                  size: 60,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text('Exoplanet Classifier', style: textTheme.headlineMedium),
                Text(
                  'Enter transit data to classify a celestial object',
                  style: textTheme.titleMedium?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildTextFormField(
                  controller: orbitalPeriodController,
                  labelText: 'Orbital Period (days)',
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: transitDurationController,
                  labelText: 'Transit Duration (hours)',
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: planetaryRadiusController,
                  labelText: 'Planetary Radius (Earth radii)',
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: stellarRadiusController,
                  labelText: 'Stellar Radius (Solar radii)',
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: onAnalyze,
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Analyze'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    textStyle: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextFormField _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) =>
          (value == null ||
              value.isEmpty ||
              double.tryParse(value) == null ||
              double.parse(value) <= 0)
          ? 'Please enter a valid number'
          : null,
    );
  }
}

// The view for the loading indicator
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          'Analyzing stellar data...',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

// The view for displaying the prediction result
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.prediction,
    required this.certainty,
    required this.onReset,
  });

  final String prediction;
  final String certainty;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, color) = _getResultVisuals(prediction);

    return Card(
      elevation: 10,
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Analysis Complete', style: textTheme.titleLarge),
            const SizedBox(height: 24),
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 16),
            Text(
              prediction,
              style: textTheme.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (certainty.isNotEmpty)
              Text('Certainty: $certainty', style: textTheme.titleMedium)
            else
              const SizedBox(height: 0),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('Analyze Another'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get an icon and color based on the prediction string
  (IconData, Color) _getResultVisuals(String prediction) {
    switch (prediction) {
      case 'CONFIRMED':
        return (Icons.check_circle_outline, Colors.greenAccent.shade400);
      case 'CANDIDATE':
        return (Icons.help_outline, Colors.amber.shade400);
      case 'FALSE POSITIVE':
        return (Icons.highlight_off, Colors.redAccent.shade400);
      default:
        return (Icons.error_outline, Colors.grey);
    }
  }
}
