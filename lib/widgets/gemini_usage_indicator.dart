import 'package:flutter/material.dart';

import '../services/gemini_usage_service.dart';

class GeminiUsageIndicator extends StatelessWidget {
  final bool isEnglish;
  final EdgeInsetsGeometry padding;

  const GeminiUsageIndicator({
    super.key,
    required this.isEnglish,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GeminiUsageStatus?>(
      valueListenable: GeminiUsageService.usage,
      builder: (context, usage, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final isExhausted = usage != null &&
            (usage.daily.remaining <= 0 || usage.burst.remaining <= 0);

        return Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: isExhausted
                ? colorScheme.errorContainer
                : colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isExhausted ? Icons.timer_off_outlined : Icons.bolt_outlined,
                color: isExhausted
                    ? colorScheme.onErrorContainer
                    : colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _label(usage),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isExhausted
                            ? colorScheme.onErrorContainer
                            : colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _label(GeminiUsageStatus? usage) {
    if (usage == null) {
      return isEnglish
          ? 'AI usage remaining: checking on first use'
          : 'AI利用可能回数：初回利用時に確認します';
    }

    if (isEnglish) {
      return 'Today: ${usage.daily.remaining}/${usage.daily.limit} remaining'
          '  •  10-minute limit: '
          '${usage.burst.remaining}/${usage.burst.limit} remaining';
    }

    return '本日残り ${usage.daily.remaining}/${usage.daily.limit}回'
        '  ・  10分枠 残り${usage.burst.remaining}/${usage.burst.limit}回';
  }
}
