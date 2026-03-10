import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../providers/auth_provider.dart';
import 'result_page.dart';

class GdScreen extends StatefulWidget {
  const GdScreen({super.key});

  @override
  State<GdScreen> createState() => _GdScreenState();
}

class _GdScreenState extends State<GdScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _cameraInitialized = false;
  bool _recording = false;
  bool _loading = false;
  bool _isDisposed = false;
  int _countdown = 15;
  Timer? _timer;
  Timer? _frameTimer;

  Map<String, dynamic>? topic;
  Map<String, dynamic>? result;
  String? _error;

  String? _liveWarning = "INITIALIZING";
  bool _screenWarning = false;
  int _switchCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSystem();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (!_loading && result == null) {
        setState(() {
          _screenWarning = true;
          _switchCount++;
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _screenWarning = false);
        });
      }
    }

    if (state == AppLifecycleState.resumed &&
        !_cameraInitialized &&
        _cameraController == null) {
      _initCamera();
    }
  }

  Future<void> _initializeSystem() async {
    await fetchTopic();
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (_isDisposed || !mounted) return;

    // Ensure previous controller is disposed
    if (_cameraController != null) {
      final oldController = _cameraController!;
      _cameraController = null;
      await oldController.dispose();
      if (mounted) setState(() => _cameraInitialized = false);
    }

    setState(() => _error = null);

    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts && !_isDisposed && mounted) {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          if (mounted)
            setState(() {
              _error = "No cameras found.";
              _liveWarning = null;
            });
          return;
        }

        final frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        final controller = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        _cameraController = controller;
        await controller.initialize();

        if (!_isDisposed && mounted) {
          setState(() {
            _cameraInitialized = true;
            _error = null;
            _liveWarning = null;
          });
          _startLiveFrameAnalysis();
          return; // Success!
        } else {
          await controller.dispose();
        }
      } catch (e) {
        attempts++;
        debugPrint("Camera init attempt $attempts failed: $e");

        if (attempts >= maxAttempts) {
          if (!_isDisposed && mounted) {
            setState(() {
              _error =
                  "Camera error: Please ensure no other app is using the webcam.";
              _liveWarning = null;
            });
          }
        } else {
          // Wait before retrying (exponential backoff or fixed delay)
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    }
  }

  Future<void> fetchTopic() async {
    try {
      final data = await ApiConfig.fetchGDTopic();
      if (!_isDisposed) setState(() => topic = data);
    } catch (e) {
      debugPrint("Topic fetch error: $e");
    }
  }

  void _startLiveFrameAnalysis() {
    _frameTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized ||
          _loading ||
          result != null) return;
      if (_cameraController!.value.isTakingPicture) return;

      try {
        final xFile = await _cameraController!.takePicture();
        final auth = Provider.of<AuthProvider>(context, listen: false);
        var req = http.MultipartRequest(
            'POST', Uri.parse('${auth.baseUrl}/process_frame'));
        req.fields['username'] = auth.username ?? "anonymous";
        req.files.add(await http.MultipartFile.fromPath('frame', xFile.path));

        final res = await req.send();
        if (res.statusCode == 200) {
          final body = await http.Response.fromStream(res);
          final data = jsonDecode(body.body);
          if (mounted) {
            setState(() {
              _liveWarning = data['warning'];
            });
          }
        }
        File(xFile.path).delete().catchError((e) => null);
      } catch (e) {
        // Ignore frame dropping errors
      }
    });
  }

  Future<void> startSession() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _recording) return;

    try {
      // Keep frame analysis running during session
      // _frameTimer?.cancel();
      // setState(() => _liveWarning = null);

      if (_cameraController!.value.isRecordingVideo) {
        await _cameraController!.stopVideoRecording();
      }

      await _cameraController!.startVideoRecording();

      final dir = await getTemporaryDirectory();
      final audioPath =
          "${dir.path}/gd_audio_${DateTime.now().millisecondsSinceEpoch}.wav";

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: audioPath,
      );

      setState(() {
        _recording = true;
        _countdown = 15;
        result = null;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_countdown == 0) {
          stopSession(audioPath);
        } else {
          setState(() => _countdown--);
        }
      });
    } catch (e) {
      debugPrint("Start session error: $e");
    }
  }

  Future<void> stopSession(String aPath) async {
    _timer?.cancel();
    if (_isDisposed) return;

    setState(() {
      _recording = false;
      _loading = true;
    });

    try {
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      final String? audioPath = await _audioRecorder.stop();

      if (topic?["topic_id"] != null && audioPath != null) {
        final res = await ApiConfig.submitGD(
          topicId: topic!["topic_id"],
          audioFile: File(audioPath),
          videoFile: File(videoFile.path),
        );
        if (!_isDisposed && mounted) {
          setState(() => result = res);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultPage(result: res),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Submit error: $e");
    } finally {
      if (!_isDisposed) {
        setState(() => _loading = false);
        // Restart frame analysis if they want to try again
        if (result == null) _startLiveFrameAnalysis();
      }
    }
  }

  @override
  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _frameTimer?.cancel();

    // Dispose camera safely
    final controller = _cameraController;
    _cameraController = null;
    controller?.dispose();

    _audioRecorder.dispose();
    super.dispose();
  }

  String _getWarningMessage() {
    if (_screenWarning)
      return "⚠️  WARNING: Screen change detected (#$_switchCount)! Stay on this screen.";
    switch (_liveWarning) {
      case "INITIALIZING":
        return "🔄 Initializing Camera... Please wait.";
      case "FACE_NOT_DETECTED":
        return "🤷 Face not detected! Move into view.";
      case "OUT_OF_BOX":
        return "📦 Face out of frame! Center yourself.";
      case "EYE_GAZE":
        return "👀 Looking away! Maintain eye contact.";
      case "PROPER_LIGHTING_REQUIRED":
        return "💡 Poor lighting! Increase brightness.";
      default:
        return "";
    }
  }

  Color _getWarningColor() {
    if (_screenWarning) return Colors.redAccent.shade700;
    switch (_liveWarning) {
      case "INITIALIZING":
        return Colors.blueAccent;
      case "FACE_NOT_DETECTED":
        return Colors.red;
      case "OUT_OF_BOX":
        return Colors.orange;
      case "EYE_GAZE":
        return Colors.amber.shade700;
      case "PROPER_LIGHTING_REQUIRED":
        return Colors.deepOrange;
      default:
        return Colors.transparent;
    }
  }

  // ================= UI SECTION =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Group Discussion",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: topic == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent))
            : _loading
                ? _buildLoadingView()
                : _buildInterviewView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Colors.cyanAccent),
        SizedBox(height: 25),
        Text("Analyzing Content & Behavior...",
            style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500))
      ],
    ));
  }

  Widget _buildInterviewView() {
    final warningMsg = _getWarningMessage();
    final hasWarning = warningMsg.isNotEmpty;

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.redAccent, size: 64),
              const SizedBox(height: 20),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _initCamera,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent),
                child: const Text("Retry Connection",
                    style: TextStyle(color: Colors.black)),
              )
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Camera Preview will now start from the top

          // Topic Display Header
          if (topic != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161625),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyanAccent.withAlpha(51)),
                ),
                child: Column(
                  children: [
                    const Text("CURRENT TOPIC",
                        style: TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Text(
                      topic!["topic"],
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Camera Preview
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                              color: hasWarning
                                  ? _getWarningColor().withAlpha(128)
                                  : Colors.cyanAccent.withAlpha(25),
                              blurRadius: 20,
                              spreadRadius: 2)
                        ],
                        border: Border.all(
                            color: hasWarning
                                ? _getWarningColor()
                                : Colors.white12,
                            width: hasWarning ? 3 : 1)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(_cameraController!),
                            // Live Warning Overlay
                            if (hasWarning)
                              Positioned(
                                top: 20,
                                left: 20,
                                right: 20,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                      color: _getWarningColor().withAlpha(204),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              warningMsg,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Controls
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161625),
              borderRadius: BorderRadius.circular(30),
            ),
            child: _recording
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: _countdown < 5
                                    ? Colors.redAccent.withAlpha(51)
                                    : Colors.greenAccent.withAlpha(51),
                                borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                Icon(Icons.timer,
                                    size: 20,
                                    color: _countdown < 5
                                        ? Colors.redAccent
                                        : Colors.greenAccent),
                                const SizedBox(width: 8),
                                Text(
                                    "00:${_countdown.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                        color: _countdown < 5
                                            ? Colors.redAccent
                                            : Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic,
                                color: _countdown % 2 == 0
                                    ? Colors.redAccent
                                    : Colors.white54,
                                size: 28),
                            const SizedBox(width: 15),
                            const Text("RECORDING LIVE",
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 16,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: hasWarning ? null : startSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withAlpha(204),
                        disabledBackgroundColor: Colors.grey.withAlpha(77),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        hasWarning
                            ? "Fix Warnings to Start"
                            : "Start GD Speech",
                        style: TextStyle(
                            color: hasWarning ? Colors.white54 : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(
      String title, String content, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 10),
        Text(content,
            style: const TextStyle(
                color: Colors.white70, fontSize: 15, height: 1.4)),
      ],
    );
  }
}