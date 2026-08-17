import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../providers/auth_provider.dart';
import '../core/constants.dart';
import 'package:intl/intl.dart';
import '../widgets/error_retry_view.dart';

class AssessmentsScreen extends StatefulWidget {
  final String? studentId; // If null, show current user's assessments

  const AssessmentsScreen({super.key, this.studentId});

  @override
  State<AssessmentsScreen> createState() => _AssessmentsScreenState();
}

class _AssessmentsScreenState extends State<AssessmentsScreen> {
  List<dynamic> _assessments = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // For now using raw dio call, ideally should be in a service
      final response = await authProvider.dio.get('${AppConstants.baseUrl}/assessments/');
      
      if (mounted) {
        setState(() {
          _assessments = response.data;
          // If studentId provided, filter them (though backend should ideally handle this)
          if (widget.studentId != null) {
            _assessments = _assessments.where((a) => a['user_id'] == widget.studentId).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading assessments: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _createNewAssessment() async {
    // Show a dialog to enter data
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _CreateAssessmentDialog(studentId: widget.studentId),
    );

    if (result != null) {
      _loadAssessments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.cardDark),
        title: Text(
          'Avaliações Corporais',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(AppConstants.neonAccent)))
          : _hasError
              ? ErrorRetryView(onRetry: _loadAssessments)
              : RefreshIndicator(
              onRefresh: _loadAssessments,
              color: const Color(AppConstants.neonAccent),
              child: _assessments.isEmpty
                  ? _buildEmptyState()
                  : _buildAssessmentsList(),
            ),
      floatingActionButton: Provider.of<AuthProvider>(context).isTrainer
          ? FloatingActionButton(
              onPressed: _createNewAssessment,
              backgroundColor: const Color(AppConstants.neonAccent),
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Nenhuma avaliação encontrada',
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assessments.length,
      itemBuilder: (context, index) {
        final a = _assessments[index];
        final date = DateTime.parse(a['created_at']);
        return Card(
          color: const Color(AppConstants.cardDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              'Gordura: ${a['body_fat_percent']}% | Músculo: ${a['muscle_mass_percent']}%',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPhotoPreview('Frente', a['photo_front_url']),
                        _buildPhotoPreview('Lado', a['photo_side_url']),
                        _buildPhotoPreview('Costas', a['photo_back_url']),
                      ],
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

  Widget _buildPhotoPreview(String label, String? url) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null
              ? Image.network(
                  url.startsWith('http') ? url : '${AppConstants.baseUrl.replaceAll('/api/v1', '')}$url',
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                )
              : const Icon(Icons.add_a_photo, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _CreateAssessmentDialog extends StatefulWidget {
  final String? studentId;
  const _CreateAssessmentDialog({this.studentId});

  @override
  State<_CreateAssessmentDialog> createState() => _CreateAssessmentDialogState();
}

class _CreateAssessmentDialogState extends State<_CreateAssessmentDialog> {
  final _fatController = TextEditingController();
  final _muscleController = TextEditingController();
  String? _frontUrl, _sideUrl, _backUrl;
  bool _isSaving = false;

  Future<void> _uploadPhoto(String position) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isSaving = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(image.path, filename: image.name),
      });

      final resp = await authProvider.dio.post('${AppConstants.baseUrl}/uploads/assessment', data: formData);
      setState(() {
        if (position == 'front') _frontUrl = resp.data['url'];
        if (position == 'side') _sideUrl = resp.data['url'];
        if (position == 'back') _backUrl = resp.data['url'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro no upload')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(AppConstants.cardDark),
      title: Text('Nova Avaliação', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fatController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: '% Gordura', labelStyle: TextStyle(color: Colors.grey)),
            ),
            TextField(
              controller: _muscleController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: '% Massa Muscular', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildUploadButton('Frente', _frontUrl, () => _uploadPhoto('front')),
                _buildUploadButton('Lado', _sideUrl, () => _uploadPhoto('side')),
                _buildUploadButton('Costas', _backUrl, () => _uploadPhoto('back')),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(AppConstants.neonAccent)),
          child: const Text('Salvar', style: TextStyle(color: Colors.black)),
        ),
      ],
    );
  }

  Widget _buildUploadButton(String label, String? url, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: url != null ? Colors.green.withOpacity(0.2) : Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: url != null ? Colors.green : Colors.white12),
            ),
            child: Icon(url != null ? Icons.check : Icons.camera_alt, color: url != null ? Colors.green : Colors.grey, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_fatController.text.isEmpty || _muscleController.text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.dio.post('${AppConstants.baseUrl}/assessments/', data: {
        'user_id': widget.studentId ?? authProvider.userId,
        'body_fat_percent': double.parse(_fatController.text),
        'muscle_mass_percent': double.parse(_muscleController.text),
        'photo_front_url': _frontUrl,
        'photo_side_url': _sideUrl,
        'photo_back_url': _backUrl,
        'status': 'COMPLETED'
      });
      Navigator.pop(context, {'success': true});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
