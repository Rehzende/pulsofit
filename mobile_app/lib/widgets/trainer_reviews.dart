import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

/// Data model for a trainer review.
class TrainerReview {
  final String id;
  final String studentName;
  final String? studentPhoto;
  final int rating;
  final String? text;
  final DateTime createdAt;

  const TrainerReview({
    required this.id,
    required this.studentName,
    this.studentPhoto,
    required this.rating,
    this.text,
    required this.createdAt,
  });

  factory TrainerReview.fromJson(Map<String, dynamic> j) => TrainerReview(
        id: j['id'] as String,
        studentName: j['student_name'] as String? ?? 'Aluno',
        studentPhoto: j['student_photo'] as String?,
        rating: j['rating'] as int,
        text: j['text'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// READ-ONLY SECTION (used in trainer profile / marketplace)
// ─────────────────────────────────────────────────────────────────────────────

class TrainerReviewsSection extends StatefulWidget {
  final String trainerId;

  const TrainerReviewsSection({super.key, required this.trainerId});

  @override
  State<TrainerReviewsSection> createState() => _TrainerReviewsSectionState();
}

class _TrainerReviewsSectionState extends State<TrainerReviewsSection> {
  List<TrainerReview> _reviews = [];
  double _avg = 0;
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final resp = await auth.dio.get(
        '${AppConstants.baseUrl}/reviews/trainer/${widget.trainerId}',
      );
      if (resp.statusCode == 200 && mounted) {
        final data = resp.data as Map<String, dynamic>;
        final list = (data['reviews'] as List)
            .map((e) => TrainerReview.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _reviews = list;
          _avg = (data['average_rating'] as num).toDouble();
          _total = data['total_reviews'] as int;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────
        Row(
          children: [
            Text(
              'Depoimentos',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Spacer(),
            if (_total > 0) ...[
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                '$_avg  ($_total)',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ── Empty ────────────────────────────────────────────
        if (_reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(AppConstants.cardDark),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(AppConstants.borderColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.rate_review_outlined, color: Colors.grey[600]),
                const SizedBox(width: 12),
                Text(
                  'Nenhum depoimento ainda.',
                  style: GoogleFonts.inter(color: Colors.grey),
                ),
              ],
            ),
          )
        else
          // ── Review Cards ─────────────────────────────────
          ...(_reviews.take(5).map((r) => _ReviewCard(review: r))),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final TrainerReview review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(AppConstants.cardDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(AppConstants.borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + name + stars
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(AppConstants.primaryDark),
                backgroundImage: review.studentPhoto != null
                    ? NetworkImage(review.studentPhoto!)
                    : null,
                child: review.studentPhoto == null
                    ? Text(
                        review.studentName[0].toUpperCase(),
                        style: GoogleFonts.inter(
                          color: const Color(AppConstants.neonAccent),
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.studentName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
          // Comment
          if (review.text != null && review.text!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '"${review.text}"',
              style: GoogleFonts.inter(
                color: Colors.grey[300],
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WRITE DIALOG (student leaves a review)
// ─────────────────────────────────────────────────────────────────────────────

class LeaveReviewDialog extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final int? existingRating;
  final String? existingText;

  const LeaveReviewDialog({
    super.key,
    required this.trainerId,
    required this.trainerName,
    this.existingRating,
    this.existingText,
  });

  static Future<bool> show(
    BuildContext ctx, {
    required String trainerId,
    required String trainerName,
    int? existingRating,
    String? existingText,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: const Color(AppConstants.cardDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LeaveReviewDialog(
        trainerId: trainerId,
        trainerName: trainerName,
        existingRating: existingRating,
        existingText: existingText,
      ),
    );
    return result ?? false;
  }

  @override
  State<LeaveReviewDialog> createState() => _LeaveReviewDialogState();
}

class _LeaveReviewDialogState extends State<LeaveReviewDialog> {
  int _rating = 0;
  final _textCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingRating ?? 0;
    if (widget.existingText != null) _textCtrl.text = widget.existingText!;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma nota de 1 a 5 estrelas.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.dio.post(
        '${AppConstants.baseUrl}/reviews/',
        data: {
          'trainer_id': widget.trainerId,
          'rating': _rating,
          'text': _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.existingRating != null ? 'Editar Depoimento' : 'Deixar Depoimento',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.trainerName,
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < _rating ? Colors.amber : Colors.grey[600],
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Comment
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            maxLength: 500,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Conte sua experiência com ${widget.trainerName} (opcional)...',
              hintStyle: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
              filled: true,
              fillColor: const Color(AppConstants.primaryDark),
              counterStyle: GoogleFonts.inter(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(AppConstants.borderColor)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: const Color(AppConstants.neonAccent).withOpacity(0.6)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppConstants.neonAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _sending
                  ? const CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                  : Text(
                      'Enviar Depoimento',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
