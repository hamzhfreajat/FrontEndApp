import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../widgets/custom_camera_overlay.dart';

class IdCaptureScreen extends StatefulWidget {
  final bool isFrontMode;

  const IdCaptureScreen({Key? key, this.isFrontMode = true}) : super(key: key);

  @override
  State<IdCaptureScreen> createState() => _IdCaptureScreenState();
}

class _IdCaptureScreenState extends State<IdCaptureScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInit = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) setState(() { _isInit = true; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        // Return the captured image path to the caller!
        Navigator.pop(context, image.path);
      }
    } catch (e) {
      debugPrint('Capture Error: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1A73E8))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isFrontMode ? 'تصوير الجهة الأمامية' : 'تصوير الجهة الخلفية'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          
          CustomCameraOverlay(
            isAligned: true,
            instructionText: widget.isFrontMode 
                ? "قم بمحاذاة الجهة الأمامية واضغط تصوير"
                : "قم بمحاذاة الجهة الخلفية واضغط تصوير",
          ),
          
          // Bottom Action Button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : FloatingActionButton(
                    onPressed: _captureImage, // Always enabled
                    backgroundColor: const Color(0xFF1A73E8),
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
