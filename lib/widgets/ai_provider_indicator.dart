import 'package:flutter/material.dart';

import '../models/ai_provider.dart';
import '../services/ai_configuration_service.dart';

class AiProviderIndicator extends StatefulWidget {
  const AiProviderIndicator({
    super.key,
    this.configurationService,
    this.compact = false,
  });

  final AiConfigurationService? configurationService;
  final bool compact;

  @override
  State<AiProviderIndicator> createState() => _AiProviderIndicatorState();
}

class _AiProviderIndicatorState extends State<AiProviderIndicator> {
  late AiConfigurationService _configurationService;
  late Future<AiProviderSettings> _settings;

  @override
  void initState() {
    super.initState();
    _configurationService =
        widget.configurationService ?? AiConfigurationService();
    _settings = _configurationService.activeSettings;
  }

  @override
  void didUpdateWidget(covariant AiProviderIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configurationService != widget.configurationService) {
      _configurationService =
          widget.configurationService ?? AiConfigurationService();
      _settings = _configurationService.activeSettings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AiProviderSettings>(
      future: _settings,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final settings = snapshot.requireData;
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 10,
            vertical: widget.compact ? 4 : 6,
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
                size: widget.compact ? 14 : 16,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  settings.provider == AiProvider.gemini
                      ? 'Gemini'
                      : '${settings.provider.displayName} / ${settings.model}',
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
