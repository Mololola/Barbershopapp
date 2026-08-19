import 'dart:convert';

import '../../../core/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../application/designer_controller.dart';
import 'cap_reached_dialog.dart';

class DesignDetailScreen extends ConsumerStatefulWidget {
  const DesignDetailScreen({super.key, required this.designId});

  final String designId;

  @override
  ConsumerState<DesignDetailScreen> createState() => _DesignDetailScreenState();
}

class _DesignDetailScreenState extends ConsumerState<DesignDetailScreen> {
  late final WebViewController _webViewController;
  bool _webViewReady = false;
  bool _pushedParameters = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => setState(() => _webViewReady = true)),
      )
      ..loadFlutterAsset('assets/haircut_designer/index.html');
  }

  Future<void> _fork() async {
    final design = await ref.read(designProvider(widget.designId).future);
    if (design == null || !mounted) return;
    final result = await ref.read(designEditControllerProvider.notifier).forkDesign(design);
    if (!mounted) return;
    if (result.capReached) {
      showCapReachedDialog(context, ref);
    } else {
      context.pushReplacement('/designs/${result.designId}/edit');
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = ref.watch(designProvider(widget.designId));

    return Scaffold(
      appBar: AppBar(title: Text(design.value?.name ?? 'Design')),
      body: design.when(
        loading: () => const LoadingView(),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (value) {
          if (value == null) {
            return const Center(child: Text('Design not found.'));
          }
          if (_webViewReady && !_pushedParameters) {
            _pushedParameters = true;
            final jsonString = jsonEncode(jsonEncode(value.parameters.toJson()));
            _webViewController.runJavaScript('updateParameters($jsonString)');
          }
          return Column(
            children: [
              Expanded(child: WebViewWidget(controller: _webViewController)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (value.ownerUsername != null) Text('By ${value.ownerUsername}'),
                    const SizedBox(height: 8),
                    FilledButton(onPressed: _fork, child: const Text('Fork this design')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
