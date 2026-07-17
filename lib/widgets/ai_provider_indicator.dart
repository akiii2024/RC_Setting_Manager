import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../services/ai_configuration_service.dart';

class AiProviderIndicator extends StatelessWidget {
  const AiProviderIndicator({
    super.key,
    this.configurationService,
    this.compact = false,
  });

  final AiConfigurationService? configurationService;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AiProviderSettings>(
      future: (configurationService ?? AiConfigurationService()).activeSettings,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final settings = snapshot.requireData;
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: compact ? 14 : 16,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  '${settings.provider.displayName} / ${settings.model}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
