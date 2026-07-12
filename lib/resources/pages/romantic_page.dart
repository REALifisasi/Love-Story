import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nylo_framework/nylo_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RomanticPage extends NyStatefulWidget {
  static RouteView path = ("/romantic", (_) => RomanticPage());

  RomanticPage({super.key}) : super(child: () => _RomanticPageState());
}

class _RomanticPageState extends NyPage<RomanticPage> {
  // ─── Greeting ─────────────────────────────────────────────────────────────
  late TextEditingController _greetingController;

  // ─── Note ─────────────────────────────────────────────────────────────────
  late TextEditingController _noteController;

  // ─── Relationship Timer ───────────────────────────────────────────────────
  /// ✏️  Ganti tanggal ini lewat tombol ⚙️ di kanan bawah.
  DateTime _startDate = DateTime(2023, 2, 14);
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  // ─── Gallery ──────────────────────────────────────────────────────────────
  final List<File> _photos = [];
  final List<String> _photoNotes = [];
  final ImagePicker _imagePicker = ImagePicker();
  late ScrollController _scrollController;

  // ─── Palette ──────────────────────────────────────────────────────────────
  static const Color _parchment = Color(0xFFFFF5F7); // kept for compat refs
  static const Color _linen     = Color(0xFFFDE8EE);
  static const Color _ink       = Color(0xFF1C1C1E);
  static const Color _burgundy  = Color(0xFFD4607A);
  static const Color _blush     = Color(0xFFF5C6D0);
  static const Color _muted     = Color(0xFFB08090);
  static const Color _rose      = Color(0xFFE8A0B0);
  static const Color _charcoal  = Color(0xFF1C1C1E);

  // Polaroid rotation list (index % 6)
  static const List<double> _rotations = [-0.03, 0.02, -0.02, 0.03, -0.01, 0.02];

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  get init => () async {
        _greetingController =
            TextEditingController(text: "HAI SAYANG KU 💕");
        _noteController = TextEditingController();
        _scrollController = ScrollController();
        await _loadSettings();
        _elapsed = DateTime.now().difference(_startDate);
        _startTimer();
        await _loadPhotoPaths();
      };

  @override
  LoadingStyle get loadingStyle => LoadingStyle.none();

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = DateTime.now().difference(_startDate);
      });
    });
  }

  @override
  void dispose() {
    _greetingController.dispose();
    _noteController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final List<XFile> picked = await _imagePicker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        _photos.addAll(picked.map((x) => File(x.path)));
        // Pad notes list with empty strings for new photos
        while (_photoNotes.length < _photos.length) {
          _photoNotes.add('');
        }
      });
      await _savePhotoPaths();
      await _savePhotoNotes();
    }
  }

  Future<void> _savePhotoPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = _photos.map((f) => f.path).toList();
    await prefs.setStringList('gallery_paths', paths);
  }

  Future<void> _savePhotoNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('gallery_notes', List<String>.from(_photoNotes));
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('greeting', _greetingController.text);
    await prefs.setString('note', _noteController.text);
    await prefs.setString('start_date', _startDate.toIso8601String());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final greeting = prefs.getString('greeting');
    final note = prefs.getString('note');
    final dateStr = prefs.getString('start_date');

    if (greeting != null) _greetingController.text = greeting;
    if (note != null) _noteController.text = note;
    if (dateStr != null) {
      _startDate = DateTime.parse(dateStr);
      _elapsed = DateTime.now().difference(_startDate);
    }
  }

  Future<void> _loadPhotoPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('gallery_paths') ?? [];
    final notes = prefs.getStringList('gallery_notes') ?? [];
    final files = paths
        .map((p) => File(p))
        .where((f) => f.existsSync())
        .toList();
    if (files.isNotEmpty) {
      setState(() {
        _photos.clear();
        _photos.addAll(files);
        _photoNotes.clear();
        // Align notes to files (paths may have been removed if files missing)
        for (int i = 0; i < files.length; i++) {
          final originalIndex = paths.indexOf(files[i].path);
          _photoNotes.add(
            (originalIndex >= 0 && originalIndex < notes.length)
                ? notes[originalIndex]
                : '',
          );
        }
      });
    }
  }

  // ─── Timer units ──────────────────────────────────────────────────────────
  Map<String, int> get _timerUnits {
    final int totalDays = _elapsed.inDays;
    return {
      'THN': totalDays ~/ 365,
      'BLN': (totalDays % 365) ~/ 30,
      'HRI': (totalDays % 365) % 30,
      'JAM': _elapsed.inHours % 24,
      'MNT': _elapsed.inMinutes % 60,
      'DTK': _elapsed.inSeconds % 60,
    };
  }

  // ─── Settings Bottom Sheet ────────────────────────────────────────────────
  void _openSettings() {
    final tempGreeting =
        TextEditingController(text: _greetingController.text);
    final tempNote = TextEditingController(text: _noteController.text);
    DateTime tempDate = _startDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF5F7), Color(0xFFFDE8EE)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: _rose.withOpacity(0.18),
                        blurRadius: 32,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 14, bottom: 4),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _blush,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Row(
                          children: [
                            Text(
                              "Pengaturan",
                              style: GoogleFonts.cormorantGaramond(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () async {
                                setState(() {
                                  _greetingController.text = tempGreeting.text;
                                  _noteController.text = tempNote.text;
                                  if (tempDate != _startDate) {
                                    _startDate = tempDate;
                                    _elapsed = DateTime.now()
                                        .difference(_startDate);
                                  }
                                });
                                await _saveSettings();
                                if (context.mounted) Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _charcoal,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Text(
                                  "Simpan",
                                  style: GoogleFonts.cormorantGaramond(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 1, color: _blush.withOpacity(0.5)),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 20),
                          children: [
                            _sheetLabel("Sapaan"),
                            const SizedBox(height: 8),
                            _sheetTextField(tempGreeting,
                                hint: "HAI SAYANG KU 💕"),
                            const SizedBox(height: 20),

                            _sheetLabel("Catatan"),
                            const SizedBox(height: 8),
                            _sheetTextField(tempNote,
                                hint: "tulis sesuatu yang indah...",
                                maxLines: 4),
                            const SizedBox(height: 20),

                            _sheetLabel("Tanggal Mulai"),
                            const SizedBox(height: 8),

                            // Date picker card
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: tempDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                  builder: (ctx, child) => Theme(
                                    data: Theme.of(ctx).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: _burgundy,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: _ink,
                                      ),
                                      datePickerTheme: DatePickerThemeData(
                                        backgroundColor: Colors.white,
                                        headerBackgroundColor: _burgundy,
                                        headerForegroundColor: Colors.white,
                                        dayForegroundColor:
                                            WidgetStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              WidgetState.selected)) {
                                            return Colors.white;
                                          }
                                          return _ink;
                                        }),
                                        dayBackgroundColor:
                                            WidgetStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              WidgetState.selected)) {
                                            return _burgundy;
                                          }
                                          return Colors.transparent;
                                        }),
                                        todayForegroundColor:
                                            WidgetStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              WidgetState.selected)) {
                                            return Colors.white;
                                          }
                                          return _burgundy;
                                        }),
                                        todayBackgroundColor:
                                            WidgetStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              WidgetState.selected)) {
                                            return _burgundy;
                                          }
                                          return Colors.transparent;
                                        }),
                                        yearForegroundColor:
                                            WidgetStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              WidgetState.selected)) {
                                            return Colors.white;
                                          }
                                          return const Color(0xFF1C1C1E);
                                        }),
                                        yearBackgroundColor:
                                            WidgetStateProperty.resolveWith(
                                                (states) {
                                          if (states.contains(
                                              WidgetState.selected)) {
                                            return _burgundy;
                                          }
                                          return Colors.transparent;
                                        }),
                                        dayStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        rangePickerHeaderForegroundColor:
                                            Colors.white,
                                        rangePickerBackgroundColor:
                                            Colors.white,
                                        dividerColor: Color(0xFFF5C6D0),
                                      ),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) {
                                  setSheetState(() => tempDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _blush, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _rose.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: _burgundy.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                          Icons.calendar_today_rounded,
                                          color: _burgundy,
                                          size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Mulai Bersama",
                                          style: GoogleFonts.cormorantGaramond(
                                            fontSize: 11,
                                            color: _muted,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${tempDate.day}/${tempDate.month}/${tempDate.year}",
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 16,
                                            color: _ink,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: _burgundy,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        "Ubah",
                                        style: GoogleFonts.cormorantGaramond(
                                          fontSize: 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            _sheetLabel("Galeri Foto"),
                            const SizedBox(height: 12),
                            if (_photos.isNotEmpty)
                              SizedBox(
                                height: 88,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _photos.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (_, i) => Stack(
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _rose.withOpacity(0.12),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            _photos[i],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: GestureDetector(
                                          onTap: () async {
                                            setSheetState(
                                                () => _photos.removeAt(i));
                                            setState(() {});
                                            await _savePhotoPaths();
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _charcoal.withOpacity(0.6),
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(3),
                                            child: const Icon(Icons.close,
                                                color: Colors.white,
                                                size: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () async {
                                await _pickImage();
                                setSheetState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _blush, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        color: _burgundy, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Tambah Foto",
                                      style: GoogleFonts.cormorantGaramond(
                                        fontSize: 15,
                                        color: _burgundy,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sheetLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.cormorantGaramond(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _muted,
            letterSpacing: 1.8,
          ),
        ),
      );

  Widget _sheetTextField(
    TextEditingController controller, {
    required String hint,
    int maxLines = 1,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.cormorantGaramond(
            fontSize: 16, color: _ink, height: 1.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cormorantGaramond(
              color: _muted.withOpacity(0.6), fontSize: 15),
          filled: true,
          fillColor: Colors.white.withOpacity(0.7),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _blush, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _blush, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _burgundy, width: 1.5),
          ),
        ),
      );

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget view(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE0),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _openSettings,
        backgroundColor: _charcoal,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.settings_rounded, color: Colors.white, size: 16),
      ),
      body: Stack(
        children: [
          // ── Paper background ──
          Container(
            width: sw,
            height: sh,
            color: const Color(0xFFF5EFE0),
          ),
          // ── Subtle paper grain overlay ──
          Opacity(
            opacity: 0.06,
            child: Container(
              width: sw,
              height: sh,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/paper_texture.png'),
                  repeat: ImageRepeat.repeat,
                  fit: BoxFit.none,
                ),
              ),
            ),
          ),
          // ── Soft vignette edges to enhance paper feel ──
          Container(
            width: sw,
            height: sh,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  const Color(0xFFD4C5A9).withOpacity(0.35),
                ],
              ),
            ),
          ),

          // ── Floating hearts ──
          const IgnorePointer(child: _LoveParticles()),

          // ── Content ──
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Greeting + Note card ──
                  _buildGreetingCard(),
                  const SizedBox(height: 20),

                  // ── Timer card ──
                  _buildTimerCard(),
                  const SizedBox(height: 20),

                  // ── Gallery card ──
                  if (_photos.isNotEmpty) _buildGalleryCard(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plain section wrapper — no card shape, floats on paper ──
  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(0),
      child: child,
    );
  }

  // ─── Section Builders ─────────────────────────────────────────────────────

  // Combined greeting + note in one glass card
  Widget _buildGreetingCard() {
    final noteText = _noteController.text.trim();
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Small label
          Text(
            'untuk kamu',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 12,
              color: _muted,
              letterSpacing: 2.0,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          // Greeting
          Text(
            _greetingController.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          if (noteText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: _blush.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              noteText,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 16,
                color: _ink.withOpacity(0.70),
                height: 1.8,
                letterSpacing: 0.2,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              '— belum ada catatan —',
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 14,
                color: _muted.withOpacity(0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Gallery wrapped in a glass card
  Widget _buildGalleryCard() {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 12, color: _burgundy.withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(
                  'kenangan kita',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 13,
                    color: _muted,
                    letterSpacing: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          ClipRect(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildPinterestGallery(),
            ),
          ),
        ],
      ),
    );
  }

  // Timer wrapped in a glass card
  Widget _buildTimerCard() {
    return _glassCard(
      child: _buildTimer(),
    );
  }

  Widget _buildOrnamentalDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 0.8, color: _blush.withOpacity(0.6))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.favorite, size: 9, color: _burgundy.withOpacity(0.5)),
        ),
        Expanded(child: Container(height: 0.8, color: _blush.withOpacity(0.6))),
      ],
    );
  }

  Widget _buildTimer() {
    final totalSeconds = _elapsed.inSeconds;
    final digits = totalSeconds.toString().split('');

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'sudah bersama selama',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 14,
              color: _muted,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          // Each digit in its own AnimatedSwitcher — only changed digits animate
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(digits.length, (i) {
                final digit = digits[i];
                final posFromRight = digits.length - 1 - i;
                return SizedBox(
                  width: 36,
                  height: 64,
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        final isIncoming = child.key ==
                            ValueKey('d$posFromRight-$digit');
                        if (isIncoming) {
                          final slideIn = Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ));
                          return SlideTransition(
                              position: slideIn, child: child);
                        }
                        return FadeTransition(
                          opacity: Tween<double>(begin: 0, end: 0)
                              .animate(animation),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        key: ValueKey('d$posFromRight-$digit'),
                        width: 36,
                        height: 64,
                        child: Center(
                          child: Text(
                            digit,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              height: 1.0,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'DETIK',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _burgundy,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  // _buildRouletteUnit is no longer used but kept for safety
  Widget _buildRouletteUnit(int value, String label) => const SizedBox.shrink();

  Widget _buildPinterestGallery() {
    if (_photos.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 104;
        // 3 cards per row, 2 gaps of 8px each
        final double cardW = (availW - 16) / 3;
        final double cardH = cardW * 1.25;

        const List<double> rots = [-0.04, 0.03, -0.03, 0.04, -0.02, 0.03];
        // Stagger offsets for middle card
        const List<double> staggerYs = [0, 12, 0];

        final List<Widget> rows = [];
        for (int i = 0; i < _photos.length; i += 3) {
          final indices = [i, i + 1, i + 2];
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int j = 0; j < 3; j++) ...[
                    if (j > 0) const SizedBox(width: 8),
                    if (indices[j] < _photos.length)
                      _photoCard(
                        _photos[indices[j]],
                        indices[j],
                        rots[indices[j] % rots.length],
                        cardW,
                        cardH,
                        staggerY: staggerYs[j],
                      )
                    else
                      SizedBox(width: cardW),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: rows,
        );
      },
    );
  }

  Widget _photoCard(File file, int index, double rotation,
      double cardW, double cardH, {required double staggerY}) {
    final note = index < _photoNotes.length ? _photoNotes[index] : '';
    return Transform.translate(
      offset: Offset(0, staggerY),
      child: Transform.rotate(
        angle: rotation,
        child: GestureDetector(
          onTap: () => showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.75),
            builder: (_) => _PhotocardModal(
              file: file,
              rotation: rotation,
              note: note,
              onNoteSaved: (newNote) async {
                setState(() {
                  while (_photoNotes.length <= index) _photoNotes.add('');
                  _photoNotes[index] = newNote;
                });
                await _savePhotoNotes();
              },
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // ── Photocard body ──
              Container(
                width: cardW,
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: _ink.withOpacity(0.14),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(2, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.file(
                      file,
                      fit: BoxFit.fitWidth,
                      width: double.infinity,
                    ),
                    // ── Note strip ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 6, 2, 4),
                      child: Text(
                        note.isEmpty ? '+ catatan' : note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.caveat(
                          fontSize: 11,
                          color: note.isEmpty
                              ? _muted.withOpacity(0.6)
                              : _ink.withOpacity(0.75),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Paper clip ──
              Positioned(
                top: -10,
                child: CustomPaint(
                  size: const Size(24, 20),
                  painter: _PaperClipPainter(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paper Clip Painter
// ─────────────────────────────────────────────────────────────────────────────

class _PaperClipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.grey.shade400;

    // Outer loop
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 4, size.width, size.height - 4),
      const Radius.circular(6),
    );
    canvas.drawRRect(outerRect, paint);

    // Inner loop (smaller, overlapping, offset upward)
    paint.color = Colors.grey.shade300;
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.18, 0, size.width * 0.64, size.height - 6),
      const Radius.circular(4),
    );
    canvas.drawRRect(innerRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Photocard Modal (shown on gallery tap)
// ─────────────────────────────────────────────────────────────────────────────

class _PhotocardModal extends StatefulWidget {
  final File file;
  final double rotation;
  final String note;
  final Future<void> Function(String) onNoteSaved;

  const _PhotocardModal({
    required this.file,
    required this.rotation,
    required this.note,
    required this.onNoteSaved,
  });

  @override
  State<_PhotocardModal> createState() => _PhotocardModalState();
}

class _PhotocardModalState extends State<_PhotocardModal> {
  late TextEditingController _noteCtrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.note);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onNoteSaved(_noteCtrl.text.trim());
    if (mounted) setState(() { _saving = false; _editing = false; });
  }

  @override
  Widget build(BuildContext context) {
    final cardW = MediaQuery.of(context).size.width * 0.72;
    return GestureDetector(
      onTap: () {
        if (_editing) {
          FocusScope.of(context).unfocus();
          _save();
        } else {
          Navigator.pop(context);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: Center(
          child: SingleChildScrollView(
            child: GestureDetector(
              onTap: () {}, // prevent dismiss when tapping card
              child: Transform.rotate(
                angle: widget.rotation,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // ── Card body ──
                    Container(
                      width: cardW,
                      padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 32,
                            spreadRadius: 2,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Photo ──
                          Image.file(
                            widget.file,
                            fit: BoxFit.fitWidth,
                            width: double.infinity,
                          ),
                          const SizedBox(height: 10),
                          // ── Note area ──
                          GestureDetector(
                            onTap: () => setState(() => _editing = true),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _editing
                                  ? TextField(
                                      key: const ValueKey('edit'),
                                      controller: _noteCtrl,
                                      autofocus: true,
                                      maxLines: 3,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.caveat(
                                        fontSize: 16,
                                        color: const Color(0xFF1C1C1E),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'tulis catatan…',
                                        hintStyle: GoogleFonts.caveat(
                                          fontSize: 16,
                                          color: Colors.black26,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        suffixIcon: _saving
                                            ? const Padding(
                                                padding: EdgeInsets.all(8),
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFFD4607A),
                                                  ),
                                                ),
                                              )
                                            : IconButton(
                                                icon: const Icon(
                                                  Icons.check_rounded,
                                                  size: 18,
                                                  color: Color(0xFFD4607A),
                                                ),
                                                onPressed: _save,
                                              ),
                                      ),
                                    )
                                  : Padding(
                                      key: const ValueKey('view'),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      child: Text(
                                        _noteCtrl.text.isEmpty
                                            ? '✏️ tambah catatan'
                                            : _noteCtrl.text,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.caveat(
                                          fontSize: 16,
                                          color: _noteCtrl.text.isEmpty
                                              ? Colors.black26
                                              : const Color(0xFF1C1C1E)
                                                  .withOpacity(0.8),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                    // ── Paper clip ──
                    Positioned(
                      top: -12,
                      child: CustomPaint(
                        size: const Size(32, 28),
                        painter: _PaperClipPainter(),
                      ),
                    ),
                    // ── Close hint ──
                    Positioned(
                      bottom: -22,
                      child: Text(
                        _editing ? 'tap di luar untuk simpan' : 'tap di luar untuk tutup',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: 0.5,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scroll Reveal Widget
// ─────────────────────────────────────────────────────────────────────────────

class _RevealOnScroll extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;

  const _RevealOnScroll({
    required this.child,
    required this.scrollController,
  });

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll> {
  bool _visible = false;
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_checkVisibility);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_checkVisibility);
    super.dispose();
  }

  void _checkVisibility() {
    if (_visible) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final screenH = MediaQuery.of(ctx).size.height;
    if (pos.dy < screenH - 40) {
      setState(() => _visible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: _key,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _visible ? 0 : 20, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        opacity: _visible ? 1.0 : 0.0,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Love Particles Background
// ─────────────────────────────────────────────────────────────────────────────

class _LoveParticles extends StatefulWidget {
  const _LoveParticles();

  @override
  State<_LoveParticles> createState() => _LoveParticlesState();
}

class _LoveParticlesState extends State<_LoveParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_HeartParticle> _particles;
  final _rng = Random();

  static const int _count = 14;
  static const Color _heartColor = Color(0xFF8B1A2F);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _particles = List.generate(_count, (_) => _HeartParticle(
      x: _rng.nextDouble(),
      startY: _rng.nextDouble(),
      size: 10 + _rng.nextDouble() * 12,
      speed: 0.03 + _rng.nextDouble() * 0.05,
      opacity: 0.07 + _rng.nextDouble() * 0.09,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return SizedBox.expand(
          child: Stack(
            children: _particles.map((p) {
              // y goes from startY upward, wraps around
              final dy = (p.startY - _controller.value * p.speed * 10) % 1.0;
              final y = (dy < 0 ? dy + 1.0 : dy) * size.height;
              return Positioned(
                left: p.x * size.width,
                top: y,
                child: Icon(
                  Icons.favorite,
                  color: _heartColor.withOpacity(p.opacity),
                  size: p.size,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _HeartParticle {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double opacity;

  const _HeartParticle({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}
