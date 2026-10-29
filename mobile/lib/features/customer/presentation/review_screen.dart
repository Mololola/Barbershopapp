import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n.dart';
import '../application/booking_controller.dart';
import '../application/review_controller.dart';
import '../domain/review.dart';

enum _Step { shop, worker, haircut }

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _shopCommentController = TextEditingController();
  final _workerCommentController = TextEditingController();
  final _haircutCommentController = TextEditingController();
  _Step _step = _Step.shop;
  int? _shopRating;
  int? _workerRating;
  int? _haircutRating;
  String? _haircutType;

  @override
  void dispose() {
    _shopCommentController.dispose();
    _workerCommentController.dispose();
    _haircutCommentController.dispose();
    super.dispose();
  }

  bool get _canAdvance {
    switch (_step) {
      case _Step.shop:
        return _shopRating != null;
      case _Step.worker:
        return _workerRating != null;
      case _Step.haircut:
        return _haircutRating != null && _haircutType != null;
    }
  }

  Future<void> _advance() async {
    if (_step == _Step.haircut) {
      await _finish();
      return;
    }
    setState(() => _step = _Step.values[_step.index + 1]);
  }

  Future<void> _omit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.skipRatingTitle),
        content: Text(context.l10n.skipRatingBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(context.l10n.skipAnyway)),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      switch (_step) {
        case _Step.shop:
          _shopRating = null;
        case _Step.worker:
          _workerRating = null;
        case _Step.haircut:
          _haircutRating = null;
          _haircutType = null;
      }
    });

    if (_step == _Step.haircut) {
      await _finish();
      return;
    }
    setState(() => _step = _Step.values[_step.index + 1]);
  }

  Future<void> _finish() async {
    final booking = await ref.read(bookingProvider(widget.bookingId).future);
    if (booking == null || !mounted) return;

    final success = await ref.read(reviewControllerProvider.notifier).submit(
          bookingId: widget.bookingId,
          businessId: booking.businessId,
          workerId: booking.workerId,
          shopRating: _shopRating,
          shopComment: _shopCommentController.text.trim().isEmpty ? null : _shopCommentController.text.trim(),
          workerRating: _workerRating,
          workerComment:
              _workerCommentController.text.trim().isEmpty ? null : _workerCommentController.text.trim(),
          haircutRating: _haircutRating,
          haircutComment: _haircutCommentController.text.trim().isEmpty
              ? null
              : _haircutCommentController.text.trim(),
          haircutType: _haircutType,
        );

    if (!mounted) return;
    // Reached via a redirect gate (see core/router.dart), not always a
    // manual push, so pop() isn't reliable here — go() plus the redirect
    // re-evaluating is what chains to the next pending review, if any.
    if (success) context.go('/customer');
  }

  @override
  Widget build(BuildContext context) {
    final reviewState = ref.watch(reviewControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: (_step.index + 1) / _Step.values.length),
            const SizedBox(height: 24),
            Expanded(child: SingleChildScrollView(child: _buildStepContent())),
            if (reviewState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  reviewState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Row(
              children: [
                TextButton(
                  onPressed: reviewState.isLoading ? null : _omit,
                  child: Text(context.l10n.omit),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: (_canAdvance && !reviewState.isLoading) ? _advance : null,
                  child: reviewState.isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_step == _Step.haircut ? context.l10n.submitReview : context.l10n.next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _appBarTitle => switch (_step) {
        _Step.shop => context.l10n.rateTheShop,
        _Step.worker => context.l10n.rateTheBarber,
        _Step.haircut => context.l10n.rateTheHaircut,
      };

  Widget _buildStepContent() {
    switch (_step) {
      case _Step.shop:
        return _RatingStep(
          rating: _shopRating,
          onRatingChanged: (value) => setState(() => _shopRating = value),
          commentController: _shopCommentController,
        );
      case _Step.worker:
        return _RatingStep(
          rating: _workerRating,
          onRatingChanged: (value) => setState(() => _workerRating = value),
          commentController: _workerCommentController,
        );
      case _Step.haircut:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RatingStep(
              rating: _haircutRating,
              onRatingChanged: (value) => setState(() => _haircutRating = value),
              commentController: _haircutCommentController,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _haircutType,
              decoration: InputDecoration(labelText: context.l10n.haircutTypeLabel),
              items: [
                for (final type in haircutTypes) DropdownMenuItem(value: type, child: Text(haircutTypeLabel(context.l10n, type))),
              ],
              onChanged: (value) => setState(() => _haircutType = value),
            ),
          ],
        );
    }
  }
}

class _RatingStep extends StatelessWidget {
  const _RatingStep({
    required this.rating,
    required this.onRatingChanged,
    required this.commentController,
  });

  final int? rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController commentController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                icon: Icon(
                  rating != null && star <= rating! ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
                onPressed: () => onRatingChanged(star),
              ),
          ],
        ),
        TextField(
          controller: commentController,
          decoration: InputDecoration(labelText: context.l10n.commentOptional),
          maxLines: 2,
        ),
      ],
    );
  }
}
