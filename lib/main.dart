import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:animated_background/animated_background.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'splash_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:universal_html/html.dart' as html;

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
  // Keys to identify and scroll to different sections of the page.
  final _identifierSectionKey = GlobalKey();
  final _analysisSectionKey = GlobalKey();
  final _teamSectionKey = GlobalKey();
  final _contactSectionKey = GlobalKey();

  // State management variables
  PageState _pageState = PageState.input;
  String _fileName = '';
  Map<String, double> _dataMap = {};
  List<int>? _downloadableFileBytes;
  String _downloadFileName = 'predictions.csv';
  String _predictionCertainty = '';
  // Controllers to get the text from TextFormFields
  final _orbitalPeriodController = TextEditingController();
  final _transitDurationController = TextEditingController();
  final _planetaryRadiusController = TextEditingController();
  final _stellarRadiusController = TextEditingController();

  Future<void> _getExoplanetPrediction() async {
    Uint8List? fileBytes;
    String? fileName;

    if (kIsWeb) {
      // 👇 هنا بنعمل picker يدوي للويب
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
      uploadInput.accept = '.csv';
      uploadInput.click();

      final completer = Completer<html.File>();
      uploadInput.onChange.listen((event) {
        final file = uploadInput.files?.first;
        if (file != null) {
          completer.complete(file);
        }
      });

      final selectedFile = await completer.future;
      fileName = selectedFile.name;

      final reader = html.FileReader();
      final readerCompleter = Completer<Uint8List>();
      reader.readAsArrayBuffer(selectedFile);
      reader.onLoadEnd.listen((event) {
        readerCompleter.complete(reader.result as Uint8List);
      });
      fileBytes = await readerCompleter.future;
    } else {
      // 👇 هنا الـ FilePicker العادي لأي منصة تانية
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return;

      fileBytes = result.files.single.bytes;
      fileName = result.files.single.name;
    }

    if (fileBytes == null) return;

    setState(() {
      _pageState = PageState.loading;
      _fileName = fileName!;
    });

    const apiUrl = "https://nasa-space-apps-backend-production.up.railway.app";
    final dio = Dio(BaseOptions(baseUrl: apiUrl));

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      });

      final response = await dio.post('/predict', data: formData);
      final responseData = response.data as Map<String, dynamic>?;

      if (responseData != null &&
          responseData.containsKey('stats') &&
          responseData.containsKey('file_content')) {
        final stats = responseData['stats'] as Map<String, dynamic>;
        _dataMap = stats.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );

        final fileContentBase64 = responseData['file_content'] as String;
        _downloadableFileBytes = base64Decode(fileContentBase64);
        _downloadFileName =
            responseData['filename'] as String? ?? 'predictions.csv';
      } else if (responseData != null &&
          responseData.containsKey('class_counts') &&
          responseData.containsKey('file')) {
        final classCounts =
            responseData['class_counts'] as Map<String, dynamic>;
        _dataMap = classCounts.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );

        final fileContent = responseData['file'] as String;
        _downloadableFileBytes = utf8.encode(fileContent);
        _downloadFileName = 'predictions_$fileName';

        _predictionCertainty = '';
      } else {
        _dataMap.clear();
        _predictionCertainty =
            'Received an invalid or incomplete response from the server.';
      }
    } on DioException catch (e) {
      _dataMap.clear();
      if (e.response != null) {
        if (e.response?.statusCode == 502) {
          _predictionCertainty =
              'The uploaded CSV file is not in the correct format. Please check the file and try again.';
        } else {
          _predictionCertainty =
              'An error occurred. Status: ${e.response?.statusCode}';
        }
      } else {
        _predictionCertainty = 'Connection Failed';
      }
      print(e);
    } finally {
      setState(() {
        _pageState = PageState.result;
      });
    }
  }

  void _downloadFile() {
    if (_downloadableFileBytes == null) return;
    final blob = html.Blob([_downloadableFileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", _downloadFileName)
      ..click();
    html.Url.revokeObjectUrl(url);
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
          fileName: _fileName,
          dataMap: _dataMap,
          certainty: _predictionCertainty,
          onReset: () => setState(() => _pageState = PageState.input),
          onDownload: _downloadFile,
        );
      case PageState.input:
        return _InputView(onAnalyze: _getExoplanetPrediction);
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 64.0),
      child: Card(
        color: Colors.black.withOpacity(0.2),
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade800, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Model Analysis',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      // Wide screen: show stats in a row
                      return const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(title: 'Accuracy', value: '78%'),
                          _StatColumn(
                            title: 'Dataset',
                            value: 'Kepler Objects of Interest (KOI)',
                          ),
                          _StatColumn(
                            title: 'Model',
                            value: 'CatBoost Classifier',
                          ),
                        ],
                      );
                    } else {
                      // Narrow screen: show stats in a column
                      return const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatColumn(title: 'Accuracy', value: '78%'),
                          SizedBox(height: 16),
                          _StatColumn(
                            title: 'Dataset',
                            value: 'Kepler Objects of Interest (KOI)',
                          ),
                          SizedBox(height: 16),
                          _StatColumn(
                            title: 'Model',
                            value: 'CatBoost Classifier',
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 40),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildImageCard(
                              'Feature Importance',
                              'assets/images/feature_importance.png',
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildImageCard(
                              'Confusion Matrix',
                              'assets/images/confusion_matrix.png',
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildImageCard(
                          'Feature Importance',
                          'assets/images/feature_importance.png',
                        ),
                        const SizedBox(height: 24),
                        _buildImageCard(
                          'Confusion Matrix',
                          'assets/images/confusion_matrix.png',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(String title, String imagePath) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(imagePath, height: 350, fit: BoxFit.contain),
        ),
      ],
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
          // Responsive grid for team members
          LayoutBuilder(
            builder: (context, constraints) {
              int columns;
              double width = constraints.maxWidth;
              if (width > 900) {
                columns = 3;
              } else if (width > 600) {
                columns = 2;
              } else {
                columns = 1;
              }
              final members = const [
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
              ];

              // Split members into rows
              List<Widget> rows = [];
              for (int i = 0; i < members.length; i += columns) {
                rows.add(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: members
                        .sublist(
                          i,
                          (i + columns) > members.length
                              ? members.length
                              : (i + columns),
                        )
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: e,
                          ),
                        )
                        .toList(),
                  ),
                );
              }
              return Column(children: rows);
            },
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
  const _InputView({required this.onAnalyze});

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
                'Upload a CSV file with transit data to classify celestial objects',
                style: textTheme.titleMedium?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: onAnalyze,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload CSV and Analyze'),
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
    required this.fileName,
    required this.dataMap,
    required this.certainty,
    required this.onReset,
    required this.onDownload,
  });

  final String fileName;
  final Map<String, double> dataMap;
  final String certainty;
  final VoidCallback onReset;
  final VoidCallback onDownload;

  bool get _isError => dataMap.isEmpty;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (icon, color) = _getResultVisuals('');

    return Card(
      elevation: 10,
      margin: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isError) ...[
              Text('Analysis Failed', style: textTheme.titleLarge),
              const SizedBox(height: 24),
              Icon(icon, size: 80, color: color),
              const SizedBox(height: 16),
              Text(
                'ERROR',
                style: textTheme.displaySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (certainty.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    certainty,
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ] else ...[
              Text('Analysis Complete', style: textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('File: $fileName', style: textTheme.titleMedium),
              const SizedBox(height: 32),
              const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
                size: 80,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onDownload, // This is the download button
                icon: const Icon(Icons.download),
                label: const Text('Download Predictions'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: const Text('Analyze Another'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper to get an icon and color based on the prediction string
  (IconData, Color) _getResultVisuals(String prediction) {
    if (_isError) {
      return (Icons.error_outline, Colors.redAccent.shade400);
    } else {
      // You can customize this for the success state if you want
      // For now, let's use a generic success icon.
      return (Icons.pie_chart, Colors.greenAccent.shade400);
    }
  }
}
