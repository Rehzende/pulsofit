import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/trainer_service.dart';
import '../models/trainer_marketplace.dart';
import '../models/chat_model.dart';
import '../widgets/trainer_reviews.dart';
import 'chat_detail_screen.dart';
import '../widgets/error_retry_view.dart';

class CoachesScreen extends StatefulWidget {
  const CoachesScreen({super.key});

  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

// Shared accents for the marketplace redesign.
const Color _spark = Color(0xFFD4FF3F); // lime spark, used sparingly
const Color _ratingGold = Color(0xFFFFC233); // warm amber/gold for the star

/// First letter for avatar fallbacks — safe against empty/blank names
/// (`name[0]` throws a RangeError on an empty string).
String _initialOf(String? name) {
  final n = (name ?? '').trim();
  return n.isNotEmpty ? n[0].toUpperCase() : '?';
}

class _CoachesScreenState extends State<CoachesScreen> {
  List<TrainerMarketplaceItem> _trainers = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _searchQuery = '';
  String? _activeSpecialty;
  String? _activeModality;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _specialties = [
    'Hipertrofia', 'Emagrecimento', 'Postura', 'Força', 'Crossfit', 'Reabilitação', 'Calistenia'
  ];

  final Map<String, String> _modalities = {
    'presencial': 'Presencial',
    'online': 'Online',
    'hibrido': 'Híbrido',
  };

  @override
  void initState() {
    super.initState();
    _loadTrainers();
  }

  Future<void> _loadTrainers() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      // Fetch all and filter in memory like Web for speed
      final trainers = await trainerService.getMarketplaceTrainers();
      
      if (mounted) {
        setState(() {
          _trainers = trainers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trainers: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  List<TrainerMarketplaceItem> get _filteredTrainers {
    return _trainers.where((t) {
      final matchesSearch = t.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t.brandName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (t.specialties?.any((s) => s.toLowerCase().contains(_searchQuery.toLowerCase())) ?? false);

      final matchesSpecialty = _activeSpecialty == null || (t.specialties?.contains(_activeSpecialty) ?? false);

      final matchesModality = _activeModality == null || t.modality == _activeModality;

      return matchesSearch && matchesSpecialty && matchesModality;
    }).toList();
  }

  Map<String, dynamic> _getModalityInfo(String? modality) {
    switch (modality) {
      case 'presencial':
        return {'label': 'Presencial', 'icon': Icons.location_on, 'color': Colors.blue};
      case 'online':
        return {'label': 'Online', 'icon': Icons.videocam, 'color': Colors.purple};
      case 'hibrido':
        return {'label': 'Híbrido', 'icon': Icons.swap_horiz, 'color': Colors.orange};
      default:
        return {'label': null, 'icon': null, 'color': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.primaryDark),
      body: SafeArea(
        child: Column(
          children: [
            // HERO Premium Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(AppConstants.cardDark),
                    const Color(AppConstants.primaryDark),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: _spark,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "VITRINE ELITE",
                        style: GoogleFonts.archivo(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(AppConstants.neonAccentLight),
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Treinadores Premium",
                    style: GoogleFonts.bebasNeue(
                      fontSize: 46,
                      color: const Color(AppConstants.textPrimary),
                      height: 0.95,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: GoogleFonts.archivo(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nome ou especialidade...',
                      hintStyle: GoogleFonts.archivo(color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.4),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(AppConstants.neonAccent), width: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Unified filter row: modality segment (left) + scrollable
            // specialties (right). Single "Todos" resets the specialty list;
            // modality is a compact segmented toggle to remove the duplicate
            // "Todos" ambiguity of the old two-tray design.
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  _buildModalitySegment(),
                  Container(
                    width: 1,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 16),
                      children: [
                        _buildFilterChip('Todos', _activeSpecialty == null,
                            () => setState(() => _activeSpecialty = null)),
                        ..._specialties.map((s) => _buildFilterChip(
                              s,
                              _activeSpecialty == s,
                              () => setState(() => _activeSpecialty = s),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Rich single-column list
            Expanded(
              child: _isLoading
                  ? _buildLoadingSkeleton()
                  : _hasError
                      ? ErrorRetryView(onRetry: _loadTrainers)
                      : _filteredTrainers.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadTrainers,
                              color: const Color(AppConstants.neonAccent),
                              backgroundColor: const Color(AppConstants.cardDark),
                              child: ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                    16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
                                itemCount: _filteredTrainers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _buildTrainerCard(_filteredTrainers[index], context);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(AppConstants.neonAccent)
                : const Color(AppConstants.cardDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(AppConstants.neonAccent)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.archivo(
              color: isSelected ? Colors.white : const Color(AppConstants.textSecondary),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  // Compact modality toggle: tap an active modality again to clear it.
  // Replaces the second filter tray + its duplicate "Todos".
  Widget _buildModalitySegment() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _modalities.entries.map((e) {
        final isSelected = _activeModality == e.key;
        final info = _getModalityInfo(e.key);
        final color = info['color'] as Color? ?? const Color(AppConstants.cyanAccent);
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeModality = isSelected ? null : e.key);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.18)
                    : const Color(AppConstants.cardDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                info['icon'] as IconData? ?? Icons.tune,
                size: 16,
                color: isSelected ? color : const Color(AppConstants.textSecondary),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Lightweight pulsing skeleton (replaces the bare spinner).
  Widget _buildLoadingSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.35, end: 0.7),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, value, child) => Opacity(opacity: value, child: child),
        child: Container(
          height: 108,
          decoration: BoxDecoration(
            color: const Color(AppConstants.cardDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 140, color: Colors.white.withValues(alpha: 0.08)),
                    const SizedBox(height: 10),
                    Container(height: 10, width: 90, color: Colors.white.withValues(alpha: 0.06)),
                    const SizedBox(height: 10),
                    Container(height: 10, width: 60, color: Colors.white.withValues(alpha: 0.06)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(AppConstants.cardDark),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Text(
            "Nenhum treinador encontrado",
            style: GoogleFonts.archivo(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            "Tente ajustar os filtros ou a busca.",
            style: GoogleFonts.archivo(color: const Color(AppConstants.textSecondary)),
          ),
        ],
      ),
    );
  }

  // Rich single-column list row: avatar (with logo backdrop) on the left,
  // name + verified + rating + specialty + price/status on the right.
  Widget _buildTrainerCard(TrainerMarketplaceItem trainer, BuildContext context) {
    final bool isAccepted = trainer.requestStatus == 'ACCEPTED';
    final bool isPending = trainer.requestStatus == 'PENDING';
    final modalityInfo = _getModalityInfo(trainer.modality);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showTrainerProfileSheet(context, trainer.userId);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(AppConstants.cardDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAccepted
                ? const Color(AppConstants.cyanAccent).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──────────────────────────────────────────
              _buildListAvatar(trainer, isAccepted),
              const SizedBox(width: 14),

              // ── Info column ─────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name + verified badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            trainer.brandName ?? trainer.fullName,
                            style: GoogleFonts.archivo(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(AppConstants.textPrimary),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trainer.isVerified) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.verified,
                              size: 16, color: Color(AppConstants.cyanAccent)),
                        ],
                      ],
                    ),
                    if (trainer.brandName != null)
                      Text(
                        trainer.fullName,
                        style: GoogleFonts.archivo(
                          color: const Color(AppConstants.textSecondary),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 6),

                    // Rating row (key trust signal)
                    _buildRatingRow(trainer),

                    // One line of specialties + modality
                    if (trainer.specialties != null && trainer.specialties!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        trainer.specialties!.take(2).join("  ·  "),
                        style: GoogleFonts.archivo(
                          color: const Color(AppConstants.neonAccentLight),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Bottom row: price (decision signal) + modality/status
                    Row(
                      children: [
                        if (!isAccepted) ...[
                          Flexible(child: _buildPriceTag(trainer)),
                          const SizedBox(width: 8),
                        ],
                        if (modalityInfo['label'] != null)
                          _buildMiniChip(
                            modalityInfo['label'] as String,
                            modalityInfo['color'] as Color? ?? const Color(AppConstants.cyanAccent),
                            icon: modalityInfo['icon'] as IconData?,
                          ),
                        if (isAccepted) ...[
                          const SizedBox(width: 6),
                          _buildMiniChip('Contratado', const Color(AppConstants.cyanAccent),
                              icon: Icons.shield_rounded),
                        ] else if (isPending) ...[
                          const SizedBox(width: 6),
                          _buildMiniChip('Pendente', const Color(0xFFFFC233),
                              icon: Icons.hourglass_top_rounded),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.25), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListAvatar(TrainerMarketplaceItem trainer, bool isAccepted) {
    const double size = 72;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAccepted
              ? const Color(AppConstants.cyanAccent)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
        color: Colors.grey.shade900,
        gradient: trainer.logoUrl == null && trainer.photoUrl == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF252830), Color(0xFF1A1C21)],
              )
            : null,
        image: trainer.photoUrl != null
            ? DecorationImage(
                image: NetworkImage(_getImageUrl(trainer.photoUrl!)),
                fit: BoxFit.cover,
              )
            : (trainer.logoUrl != null
                ? DecorationImage(
                    image: NetworkImage(_getImageUrl(trainer.logoUrl!)),
                    fit: BoxFit.cover,
                  )
                : null),
      ),
      clipBehavior: Clip.antiAlias,
      child: (trainer.photoUrl == null && trainer.logoUrl == null)
          ? Center(
              child: Text(
                _initialOf(trainer.fullName),
                style: GoogleFonts.bebasNeue(
                  fontSize: 30,
                  color: const Color(AppConstants.textPrimary),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildRatingRow(TrainerMarketplaceItem trainer) {
    if (trainer.averageRating == null) {
      // No reviews yet — subtle "Novo" tag.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _spark.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "NOVO · sem avaliações",
          style: GoogleFonts.archivo(
            color: _spark,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: _ratingGold, size: 17),
        const SizedBox(width: 3),
        Text(
          trainer.averageRating!.toStringAsFixed(1),
          style: GoogleFonts.archivo(
            color: const Color(AppConstants.textPrimary),
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          "· ${trainer.totalReviews}",
          style: GoogleFonts.archivo(
            color: const Color(AppConstants.textSecondary),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceTag(TrainerMarketplaceItem trainer) {
    final hasRate = trainer.hourlyRate != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasRate
            ? const Color(AppConstants.cyanAccent).withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasRate
              ? const Color(AppConstants.cyanAccent).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: hasRate
          ? RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "R\$ ${trainer.hourlyRate!.toStringAsFixed(0)}",
                    style: GoogleFonts.archivo(
                      color: const Color(AppConstants.cyanAccentLight),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: " /h",
                    style: GoogleFonts.archivo(
                      color: const Color(AppConstants.cyanAccent),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Text(
              "Sob consulta",
              style: GoogleFonts.archivo(
                color: const Color(AppConstants.textSecondary),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildMiniChip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.archivo(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- BOTTOM SHEET PROFILE ---------- //

  void _showTrainerProfileSheet(BuildContext context, String trainerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TrainerProfileSheetContent(
        trainerId: trainerId,
        onRequestSent: () {
          // UPDATE LIST STATE WHEN BOTTOM SHEET FIRES CALLBACK
          setState(() {
            final index = _trainers.indexWhere((t) => t.userId == trainerId);
            if (index != -1) {
              _trainers[index] = TrainerMarketplaceItem(
                userId: _trainers[index].userId,
                fullName: _trainers[index].fullName,
                photoUrl: _trainers[index].photoUrl,
                brandName: _trainers[index].brandName,
                logoUrl: _trainers[index].logoUrl,
                bio: _trainers[index].bio,
                modality: _trainers[index].modality,
                specialties: _trainers[index].specialties,
                gyms: _trainers[index].gyms,
                hourlyRate: _trainers[index].hourlyRate,
                whatsappNumber: _trainers[index].whatsappNumber,
                isAvailableForHire: _trainers[index].isAvailableForHire,
                requestStatus: 'PENDING',
              );
            }
          });
        },
      ),
    );
  }

  String _getImageUrl(String url) {
    if (url.startsWith('http')) return url;
    var cleanUrl = url;
    while (cleanUrl.startsWith('/')) { cleanUrl = cleanUrl.substring(1); }
    return '${AppConstants.apiUrl}/$cleanUrl';
  }
}

// Stateful Widget for the BottomSheet to handle async Loading & Status Mutability
class _TrainerProfileSheetContent extends StatefulWidget {
  final String trainerId;
  final VoidCallback? onRequestSent;

  const _TrainerProfileSheetContent({required this.trainerId, this.onRequestSent});

  @override
  State<_TrainerProfileSheetContent> createState() => _TrainerProfileSheetContentState();
}

class _TrainerProfileSheetContentState extends State<_TrainerProfileSheetContent> {
  bool _isLoading = true;
  bool _hasError = false;
  bool _isRequesting = false;
  TrainerMarketplaceItem? _trainer;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      final profile = await trainerService.getTrainerProfile(widget.trainerId);
      if (mounted) {
        setState(() {
          _trainer = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao abrir perfil do treinador.')));
      }
    }
  }

  Future<void> _sendHiringRequest() async {
    setState(() => _isRequesting = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final trainerService = TrainerService(authProvider.dio);
      await trainerService.sendHiringRequest(widget.trainerId);
      
      if (mounted) {
        setState(() {
          // Manually update the requestStatus to reflect immediate change
          _trainer = TrainerMarketplaceItem(
            userId: _trainer!.userId,
            fullName: _trainer!.fullName,
            photoUrl: _trainer!.photoUrl,
            brandName: _trainer!.brandName,
            logoUrl: _trainer!.logoUrl,
            bio: _trainer!.bio,
            modality: _trainer!.modality,
            specialties: _trainer!.specialties,
            gyms: _trainer!.gyms,
            hourlyRate: _trainer!.hourlyRate,
            whatsappNumber: _trainer!.whatsappNumber,
            isAvailableForHire: _trainer!.isAvailableForHire,
            requestStatus: 'PENDING',
          );
        });

        // Notify parent list to update its UI
        if (widget.onRequestSent != null) {
          widget.onRequestSent!();
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('Request already pending') || e.toString().contains('400')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sua solicitação já está pendente.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Não foi possível solicitar vaga.')));
        }
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  void _openWhatsApp(String? number) async {
    if (number == null || number.isEmpty) return;
    final cleanNumber = number.replaceAll(RegExp(r'[^\d]'), '');
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _getImageUrl(String url) {
    if (url.startsWith('http')) return url;
    var cleanUrl = url;
    while (cleanUrl.startsWith('/')) { cleanUrl = cleanUrl.substring(1); }
    return '${AppConstants.apiUrl}/$cleanUrl';
  }

  Map<String, dynamic> _getModalityInfo(String? modality) {
    switch (modality) {
      case 'presencial':
        return {'label': 'Presencial', 'icon': Icons.location_on, 'color': Colors.blue};
      case 'online':
        return {'label': 'Online', 'icon': Icons.videocam, 'color': Colors.purple};
      case 'hibrido':
        return {'label': 'Híbrido', 'icon': Icons.swap_horiz, 'color': Colors.orange};
      default:
        return {'label': null, 'icon': null, 'color': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(AppConstants.primaryDark),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(AppConstants.neonAccent))),
      );
    }

    if (_trainer == null) return const SizedBox.shrink();

    final isPending = _trainer!.requestStatus == 'PENDING';
    final isAccepted = _trainer!.requestStatus == 'ACCEPTED';

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(AppConstants.primaryDark),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Banner ─────────────────────────────────────────
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background colour
                        Container(color: const Color(AppConstants.cardDark)),

                        // Logo image with error handling
                        if (_trainer!.logoUrl != null)
                          Image.network(
                            _getImageUrl(_trainer!.logoUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                            loadingBuilder: (context, child, progress) =>
                                progress == null ? child : const SizedBox.shrink(),
                          ),

                        // Gradient overlay
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(AppConstants.primaryDark)],
                              stops: [0.3, 1.0],
                            ),
                          ),
                        ),

                        // Status badge
                        if (isPending)
                          Positioned(
                            top: 24,
                            right: 24,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.2),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Text("Solicitação Pendente", style: GoogleFonts.inter(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        if (isAccepted)
                          Positioned(
                            top: 24,
                            right: 24,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield, color: Colors.green, size: 13),
                                  const SizedBox(width: 8),
                                  Text("Seu Treinador", style: GoogleFonts.inter(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Avatar row (floated over banner via negative margin) ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Avatar — negative margin pulls it up over banner
                        Container(
                          margin: const EdgeInsets.only(bottom: 0),
                          transform: Matrix4.translationValues(0, -44, 0),
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(AppConstants.primaryDark), width: 4),
                            color: const Color(AppConstants.cardDark),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _trainer!.photoUrl != null
                              ? Image.network(
                                  _getImageUrl(_trainer!.photoUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Center(
                                    child: Text(_initialOf(_trainer!.fullName),
                                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                )
                              : Center(
                                  child: Text(_initialOf(_trainer!.fullName),
                                      style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                        ),

                        const Spacer(),

                        // Rating chip
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(AppConstants.cardDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 5),
                                Text("5.0", style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Name & info ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _trainer!.brandName ?? _trainer!.fullName,
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
                        ),
                        if (_trainer!.brandName != null) ...[
                          const SizedBox(height: 2),
                          Text(_trainer!.fullName, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500)),
                        ],

                        // Hourly rate
                        if (_trainer!.hourlyRate != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Investimento", style: GoogleFonts.inter(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                                    const SizedBox(height: 2),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text("R\$ ${_trainer!.hourlyRate!.toStringAsFixed(0)}", style: GoogleFonts.inter(color: Colors.green.shade400, fontSize: 22, fontWeight: FontWeight.w900)),
                                        Text(" /hora", style: GoogleFonts.inter(color: Colors.green.shade700, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Bio
                        const SizedBox(height: 24),
                        Text("Sobre", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 10),
                        Text(
                          _trainer!.bio ?? "Sem descrição detalhada.",
                          style: GoogleFonts.inter(color: Colors.grey.shade400, height: 1.6, fontSize: 14),
                        ),

                        // Modality Info
                        if (_trainer!.modality != null) ...[
                          const SizedBox(height: 24),
                          Text("Modalidade de Atendimento", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final modalityInfo = _getModalityInfo(_trainer!.modality);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: (modalityInfo['color'] as Color? ?? Colors.grey).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (modalityInfo['color'] as Color? ?? Colors.grey).withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      modalityInfo['icon'] as IconData? ?? Icons.location_on,
                                      color: modalityInfo['color'] as Color? ?? Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      modalityInfo['label'] as String? ?? 'N/A',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        // Gyms/Locations
                        if (_trainer!.gyms != null && _trainer!.gyms!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text("Locais de Atendimento", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _trainer!.gyms!.map((gym) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.cardDark),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.blue),
                                  const SizedBox(width: 6),
                                  Text(gym, style: GoogleFonts.inter(color: Colors.grey.shade300, fontWeight: FontWeight.w500, fontSize: 13)),
                                ],
                              ),
                            )).toList(),
                          ),
                        ],

                        // Specialties
                        if (_trainer!.specialties != null && _trainer!.specialties!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text("Especialidades", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _trainer!.specialties!.map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(AppConstants.cardDark),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Text(s, style: GoogleFonts.inter(color: Colors.grey.shade300, fontWeight: FontWeight.w500, fontSize: 13)),
                            )).toList(),
                          ),
                        ],

                        // Reviews
                        const SizedBox(height: 24),
                        TrainerReviewsSection(trainerId: widget.trainerId),

                        // Leave review button
                        if (isAccepted) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await LeaveReviewDialog.show(
                                context,
                                trainerId: widget.trainerId,
                                trainerName: _trainer!.brandName ?? _trainer!.fullName,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), // AUMENTADO HORIZONTALMENTE
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.star_outline_rounded, color: Colors.amber, size: 18),
                            label: Text(
                              'Avaliar',
                              style: GoogleFonts.inter(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],

                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Fixed Bottom Action Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 20 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: const Color(AppConstants.primaryDark),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -10)),
                  ],
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                child: () {
                  if (isAccepted) {
                    return ElevatedButton(
                      onPressed: () async {
                        // Open chat with trainer
                        final chatProvider = context.read<ChatProvider>();
                        await chatProvider.openOrCreateConversation(
                          contactId: _trainer!.userId,
                          existingConversationId: null,  // Will be created if doesn't exist
                        );

                        if (mounted && chatProvider.currentConversation != null) {
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                  conversation: ChatConversation(
                                    id: chatProvider.currentConversation!.id,
                                    otherUserId: _trainer!.userId,
                                    otherUserName: _trainer!.fullName,
                                    otherUserPhotoUrl: _trainer!.photoUrl,
                                    lastMessageBody: null,
                                    lastMessageAt: null,
                                    unreadCount: 0,
                                    isFromTrainer: false,
                                  ),
                                ),
                              ),
                            );
                          }
                        } else if (mounted && chatProvider.error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(chatProvider.error!)),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.neonAccent),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble, color: Colors.white),
                          const SizedBox(width: 8),
                          Text("Abrir conversa", style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  } else if (isPending) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.mail, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            "Solicitação Enviada. Aguarde.",
                            style: GoogleFonts.inter(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return ElevatedButton(
                      onPressed: _isRequesting ? null : _sendHiringRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.neonAccent),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                        shadowColor: const Color(AppConstants.neonAccent).withValues(alpha: 0.5),
                      ),
                      child: _isRequesting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text("Solicitar Vaga (Entrevista)", style: GoogleFonts.inter(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
                    );
                  }
                }(),
              ),
            ),
            
            // Close Button
            Positioned(
              top: 16,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
