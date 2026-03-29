import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../models/search_query.dart';
import '../../services/update_service.dart';
import '../scanner/scanner_screen.dart';
import '../scanner/text_recognizer_service.dart';
import '../update/update_banner.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  SearchMode _mode = SearchMode.library;
  OcrLanguage _language = OcrLanguage.latin;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();

    Future.microtask(() {
      ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('What are you looking for?'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: const Color(0xFF2D2D3A),
        ),
      );
      return;
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Camera access needed to scan shelves'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: const Color(0xFF2D2D3A),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();

    final searchQuery = SearchQuery(text: query, mode: _mode);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return ScannerScreen(query: searchQuery, language: _language);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      body: Stack(
        children: [
          // Subtle ambient glow — top right
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C5CE7).withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main scrollable content
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildTopBar()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildHero()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildSearchField()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildModeChips()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildLanguageRow()),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      sliver: SliverToBoxAdapter(child: _buildScanButton()),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                          20, 32, 20, bottomPad + 80),
                      sliver: SliverToBoxAdapter(child: _buildTips()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Update banner
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(child: UpdateBanner()),
          ),
        ],
      ),
    );
  }

  // ─── Top bar: minimal, just the logo mark ───
  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Shelfie',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        // Language indicator as a subtle pill
        GestureDetector(
          onTap: _showLanguagePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.translate_rounded,
                  size: 14,
                  color: Color(0xFF8B8B9E),
                ),
                const SizedBox(width: 5),
                Text(
                  _language.displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B8B9E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Hero: large welcoming text ───
  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _mode == SearchMode.library
              ? 'Find your book\non the shelf'
              : 'Find your product\non the shelf',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Point your camera and we\'ll spot it for you.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.4),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ─── Search field: clean, prominent ───
  Widget _buildSearchField() {
    final hasText = _searchController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focusNode.hasFocus
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: _mode == SearchMode.library
              ? 'Book title…'
              : 'Product name…',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.2),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              color: hasText
                  ? const Color(0xFF6C5CE7)
                  : Colors.white.withValues(alpha: 0.2),
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 46,
            minHeight: 0,
          ),
          suffixIcon: hasText
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 16,
          ),
          filled: false,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _startScanning(),
        onTap: () => setState(() {}),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  // ─── Mode chips: horizontal, understated ───
  Widget _buildModeChips() {
    return Row(
      children: SearchMode.values.map((mode) {
        final isSelected = mode == _mode;
        return Padding(
          padding: EdgeInsets.only(
            right: mode != SearchMode.values.last ? 8 : 0,
          ),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _mode = mode);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6C5CE7).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6C5CE7).withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mode.icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? const Color(0xFFB4AEFF)
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Language row (inline, no section header) ───
  Widget _buildLanguageRow() {
    return Row(
      children: [
        Icon(
          Icons.translate_rounded,
          size: 15,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: OcrLanguage.values.map((lang) {
                final isSelected = lang == _language;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _language = lang);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6C5CE7)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lang.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Scan button ───
  Widget _buildScanButton() {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: _startScanning,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: hasQuery ? const Color(0xFF6C5CE7) : const Color(0xFF1A1A22),
          borderRadius: BorderRadius.circular(14),
          boxShadow: hasQuery
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_rounded,
              size: 20,
              color: hasQuery
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 8),
            Text(
              'Scan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: hasQuery
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.25),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tips: subtle, not a tutorial ───
  Widget _buildTips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: Colors.white.withValues(alpha: 0.05),
          height: 1,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            _tipItem(Icons.text_fields_rounded, 'Type a name'),
            const SizedBox(width: 24),
            _tipItem(Icons.center_focus_strong_rounded, 'Aim at shelf'),
            const SizedBox(width: 24),
            _tipItem(Icons.vibration_rounded, 'Feel the buzz'),
          ],
        ),
      ],
    );
  }

  Widget _tipItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.white.withValues(alpha: 0.18),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.22),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ─── Language picker bottom sheet ───
  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'OCR Language',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the language of the text you\'re scanning.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 20),
                ...OcrLanguage.values.map((lang) {
                  final isSelected = lang == _language;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _language = lang);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6C5CE7).withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF6C5CE7)
                                    .withValues(alpha: 0.3),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang.displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: Color(0xFF6C5CE7),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
