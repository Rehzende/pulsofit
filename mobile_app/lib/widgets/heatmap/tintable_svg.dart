import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;

class TintableSvg extends StatefulWidget {
  final String assetPath;
  final Color color;

  const TintableSvg({
    super.key,
    required this.assetPath,
    required this.color,
  });

  @override
  State<TintableSvg> createState() => _TintableSvgState();
}

class _TintableSvgState extends State<TintableSvg> {
  String? _svgString;
  String? _currentAssetPath;

  @override
  void initState() {
    super.initState();
    _loadAndProcessSvg();
  }

  @override
  void didUpdateWidget(TintableSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _loadAndProcessSvg();
    }
  }

  Future<void> _loadAndProcessSvg() async {
    try {
      final path = widget.assetPath;
      String svgContent = await rootBundle.loadString(path);
      
      // Remove fills to allow tinting
      // Remove style="...fill:..." handling optional spaces
      String processed = svgContent.replaceAll(RegExp(r'fill:\s*(?!none)[^;"]+;?'), '');
      // Remove fill="..." attributes
      processed = processed.replaceAll(RegExp(r'fill\s*=\s*"(?!(none))[^"]*"'), '');
      
      // Also remove stroke colors if any, or maybe we want to keep outlines?
      // The current SVGs seem to rely on fill.
      
      if (mounted) {
        setState(() {
          _svgString = processed;
          _currentAssetPath = path;
        });
      }
    } catch (e) {
      debugPrint('Error loading SVG $widget.assetPath: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_svgString == null || _currentAssetPath != widget.assetPath) {
      return const SizedBox.shrink(); 
    }

    return SvgPicture.string(
      _svgString!,
      // Do not force infinity, let layout constraints (FractionallySizedBox) handle sizing
      colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
    );
  }
}
