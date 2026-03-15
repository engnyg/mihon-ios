import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../domain/repositories/chapter_repository.dart';
import '../../domain/repositories/history_repository.dart';
import 'reader_providers.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.chapterId,
    required this.mangaId,
  });

  final int chapterId;
  final int mangaId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onPageChanged(int page, int totalPages) {
    setState(() => _currentPage = page);

    // Save reading progress
    GetIt.I<ChapterRepository>()
        .updateReadingProgress(widget.chapterId, page);

    // Mark as read when reaching the last page
    if (page == totalPages - 1) {
      GetIt.I<ChapterRepository>()
          .markRead(widget.chapterId, read: true);
      GetIt.I<HistoryRepository>()
          .recordHistory(widget.chapterId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = (chapterId: widget.chapterId, mangaId: widget.mangaId);
    final pagesAsync = ref.watch(readerPagesProvider(params));

    return Scaffold(
      backgroundColor: Colors.black,
      body: pagesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load pages\n$e',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(readerPagesProvider(params)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (pages) => GestureDetector(
          onTap: () => setState(() => _showOverlay = !_showOverlay),
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (p) => _onPageChanged(p, pages.length),
                itemBuilder: (context, i) => _PageView(
                  imageUrl: pages[i].imageUrl ?? pages[i].url ?? '',
                ),
              ),
              if (_showOverlay) ...[
                _TopBar(onBack: () => Navigator.pop(context)),
                _BottomBar(
                  currentPage: _currentPage,
                  totalPages: pages.length,
                  onSliderChanged: (v) {
                    _pageController.jumpToPage(v.round());
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.onSliderChanged,
  });

  final int currentPage;
  final int totalPages;
  final void Function(double) onSliderChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${currentPage + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                    value: currentPage.toDouble(),
                    min: 0,
                    max: (totalPages - 1).toDouble().clamp(0, double.infinity),
                    divisions: totalPages > 1 ? totalPages - 1 : 1,
                    onChanged: onSliderChanged,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white38,
                  ),
                ),
                Text(
                  '$totalPages',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
