import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/loading.dart';
import '../../../core/app_network_image.dart';
import '../application/designer_controller.dart';
import '../domain/haircut_design.dart';

class DesignerGalleryScreen extends StatelessWidget {
  const DesignerGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Haircut designs'),
          bottom: const TabBar(tabs: [Tab(text: 'My Designs'), Tab(text: 'Browse')]),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: () => context.push('/designs/new'),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [_MyDesignsTab(), _BrowseTab()],
        ),
      ),
    );
  }
}

class _MyDesignsTab extends ConsumerWidget {
  const _MyDesignsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designs = ref.watch(myDesignsProvider);
    final extraSlots = ref.watch(designExtraSlotsProvider).value ?? 0;
    return designs.when(
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (list) {
        final cap = maxFreeDesigns + extraSlots;
        final label = extraSlots > 0
            ? '${list.length}/$cap designs used ($maxFreeDesigns free + $extraSlots purchased)'
            : '${list.length}/$cap free designs used';
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(label),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No designs yet — tap + to create one.'))
                  : _DesignGrid(
                      designs: list,
                      onTap: (design) => context.push('/designs/${design.id}/edit'),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _BrowseTab extends ConsumerWidget {
  const _BrowseTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designs = ref.watch(publicDesignsProvider);
    return designs.when(
      loading: () => const LoadingView(),
      error: (error, _) => Center(child: Text('Error: $error')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No public designs yet.'));
        }
        return _DesignGrid(
          designs: list,
          onTap: (design) => context.push('/designs/${design.id}'),
        );
      },
    );
  }
}

class _DesignGrid extends StatelessWidget {
  const _DesignGrid({required this.designs, required this.onTap});

  final List<HaircutDesign> designs;
  final ValueChanged<HaircutDesign> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.85),
      itemCount: designs.length,
      itemBuilder: (context, index) {
        final design = designs[index];
        return InkWell(
          onTap: () => onTap(design),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: design.thumbnailUrl != null
                      ? AppNetworkImage(design.thumbnailUrl!)
                      : const Center(child: Icon(Icons.face_retouching_natural, size: 40)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(design.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
