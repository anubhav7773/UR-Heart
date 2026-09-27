import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'five_slot_photo_grid.dart';

class FiveSlotMediaGrid extends ConsumerWidget {
  final Future<void> Function(int slotNumber)? onSelectImage;

  const FiveSlotMediaGrid({super.key, this.onSelectImage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FiveSlotPhotoGrid(onSelectImage: onSelectImage);
  }
}
