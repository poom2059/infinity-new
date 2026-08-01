import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'map_picker_screen.dart';
import '../data/places/saved_places_store.dart';

/// หน้าจัดการที่อยู่ที่บันทึก — ปักหมุดบนแผนที่ Google Maps
class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});

  Future<void> _addPlace(BuildContext context) async {
    final SavedPlace? place = await Navigator.of(context).push<SavedPlace>(
      MaterialPageRoute<SavedPlace>(builder: (_) => const MapPickerScreen()),
    );
    if (place != null && context.mounted) {
      await context.read<SavedPlacesStore>().add(place);
    }
  }

  Future<void> _editPlace(BuildContext context, SavedPlace existing) async {
    final SavedPlace? place = await Navigator.of(context).push<SavedPlace>(
      MaterialPageRoute<SavedPlace>(builder: (_) => MapPickerScreen(initial: existing)),
    );
    if (place != null && context.mounted) {
      await context.read<SavedPlacesStore>().update(place);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SavedPlacesStore store = context.watch<SavedPlacesStore>();
    final List<SavedPlace> places = store.items;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.topBar,
        foregroundColor: AppColors.topBarFg,
        title: const Text('ที่อยู่ที่บันทึก', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPlace(context),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('เพิ่มที่อยู่', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: places.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: places.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int i) {
                final SavedPlace p = places[i];
                return _PlaceCard(
                  place: p,
                  onTap: () => _editPlace(context, p),
                  onDelete: () => context.read<SavedPlacesStore>().remove(p.id),
                );
              },
            ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap, required this.onDelete});

  final SavedPlace place;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _MapThumb(label: place.label),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_iconFor(place.label), size: 18, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            place.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
                tooltip: 'ลบ',
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String label) {
    if (label.contains('บ้าน')) {
      return Icons.home_rounded;
    }
    if (label.contains('ทำงาน') || label.contains('ออฟฟิศ')) {
      return Icons.work_rounded;
    }
    return Icons.place_rounded;
  }
}

/// ไอคอนตัวอย่างของที่อยู่ (แทนแผนที่ย่อ เพื่อความลื่นไหลบนเว็บ)
class _MapThumb extends StatelessWidget {
  const _MapThumb({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final IconData icon = label.contains('บ้าน')
        ? Icons.home_rounded
        : (label.contains('ทำงาน') || label.contains('ออฟฟิศ'))
            ? Icons.work_rounded
            : Icons.place_rounded;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE3001B), Color(0xFFFF6A3D)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: Icon(Icons.map_rounded, size: 64, color: Colors.white),
            ),
          ),
          Icon(icon, size: 30, color: Colors.white),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 14),
            const Text(
              'ยังไม่มีที่อยู่ที่บันทึก',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'กดปุ่ม “เพิ่มที่อยู่” เพื่อปักหมุดตำแหน่งบนแผนที่',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
