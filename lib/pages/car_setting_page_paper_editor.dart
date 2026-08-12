// ignore_for_file: unused_element

part of 'car_setting_page.dart';

mixin _CarSettingPaperEditor on State<CarSettingPage> {
  Map<String, dynamic> get settings;
  String get carName;
  CarSettingDefinition? get _carSettingDefinition;
  TextEditingController get _settingNameController;
  TextEditingController get _trackNameController;
  TrackLocation? get _currentTrack;
  bool get _isLocationLoading;
  bool get _isTrf420x;

  Future<void> _refreshLocation();
  Future<void> _searchTrackManually();
  Widget _buildEditorLayoutSelector(
    bool isEnglish,
    bool usePaperStyleEditor,
  );
  Widget _buildSettingField(SettingItem setting);
  Widget _buildSettingFieldWithFavorite(SettingItem setting);
  bool _isTrf420xHiddenCompositePart(String key);

  bool _useSimplePaperCopy() => true;

  Widget _buildPaperEditorBody(BuildContext context, bool isEnglish) {
    if (_carSettingDefinition == null) {
      return Center(
        child: Text(
          isEnglish
              ? 'No setting definition found for this car.'
              : 'この車種の設定定義が見つかりません。',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 920;
        final isCompact = constraints.maxWidth < 560;
        final lowerRowHeight = isWide
            ? 270.0
            : isCompact
                ? 210.0
                : 235.0;
        final stackedSectionHeight = isWide
            ? 340.0
            : isCompact
                ? 256.0
                : 300.0;
        const stackedSectionGap = 12.0;
        final stackedButtonHeight =
            (stackedSectionHeight - stackedSectionGap) / 2;
        final memoHeight = isCompact ? 124.0 : 144.0;
        final theme = Theme.of(context);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEditorLayoutSelector(isEnglish, true),
              const SizedBox(height: 16),
              _buildPaperHeaderCard(isEnglish),
              const SizedBox(height: 16),
              if (!_useSimplePaperCopy()) ...[
                Text(
                  isEnglish
                      ? 'Tap the same area you would look at on the paper sheet.'
                      : '紙で見る場所と同じ位置のセクションをタップして編集します。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildPaperSectionButton(
                          category: 'front',
                          title: isEnglish ? 'Front' : 'フロント',
                          subtitle:
                              _buildPaperSectionSubtitle('front', isEnglish),
                          icon: Icons.north_west_rounded,
                          tint: const Color(0xFF1976D2),
                          height: stackedButtonHeight,
                          isEnglish: isEnglish,
                        ),
                        const SizedBox(height: stackedSectionGap),
                        _buildPaperSectionButton(
                          category: 'frontDamper',
                          title: isEnglish ? 'Front Damper' : 'フロントダンパー',
                          subtitle: _buildPaperSectionSubtitle(
                              'frontDamper', isEnglish),
                          icon: Icons.swap_vert_rounded,
                          tint: const Color(0xFF3949AB),
                          height: stackedButtonHeight,
                          isEnglish: isEnglish,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildPaperSectionButton(
                          category: 'rear',
                          title: isEnglish ? 'Rear' : 'リア',
                          subtitle:
                              _buildPaperSectionSubtitle('rear', isEnglish),
                          icon: Icons.north_east_rounded,
                          tint: const Color(0xFF00897B),
                          height: stackedButtonHeight,
                          isEnglish: isEnglish,
                        ),
                        const SizedBox(height: stackedSectionGap),
                        _buildPaperSectionButton(
                          category: 'rearDamper',
                          title: isEnglish ? 'Rear Damper' : 'リアダンパー',
                          subtitle: _buildPaperSectionSubtitle(
                              'rearDamper', isEnglish),
                          icon: Icons.swap_vert_circle_rounded,
                          tint: const Color(0xFF00796B),
                          height: stackedButtonHeight,
                          isEnglish: isEnglish,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 3 : 2,
                    child: _buildPaperSectionButton(
                      category: 'top',
                      title: isEnglish ? 'Top Deck' : 'トップ',
                      subtitle: _buildPaperSectionSubtitle('top', isEnglish),
                      icon: Icons.view_in_ar_rounded,
                      tint: const Color(0xFF6A1B9A),
                      height: lowerRowHeight,
                      isEnglish: isEnglish,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _buildPaperSectionButton(
                      category: 'other',
                      title: isEnglish ? 'Other' : 'その他',
                      subtitle: _buildPaperSectionSubtitle('other', isEnglish),
                      icon: Icons.tune_rounded,
                      tint: const Color(0xFFEF6C00),
                      height: lowerRowHeight,
                      isEnglish: isEnglish,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPaperSectionButton(
                category: 'memo',
                title: isEnglish ? 'Notes' : 'メモ',
                subtitle: _buildPaperSectionSubtitle('memo', isEnglish),
                icon: Icons.note_alt_rounded,
                tint: const Color(0xFF5D4037),
                height: memoHeight,
                isEnglish: isEnglish,
                showFavorite: false,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaperHeaderCard(bool isEnglish) {
    final theme = Theme.of(context);
    final trackSummary = _buildTrackSummary(isEnglish);

    final firstRow = <Widget>[
      _buildSettingNameField(isEnglish, dense: true),
    ];
    final dateField = _buildSettingWidgetByKey('date', showFavorite: false);
    if (dateField != null) {
      firstRow.add(dateField);
    }

    final secondRow = <Widget>[
      _buildTrackNameField(isEnglish, dense: true),
    ];
    for (final key in ['surface', 'condition']) {
      final field = _buildSettingWidgetByKey(key, showFavorite: false);
      if (field != null) {
        secondRow.add(field);
      }
    }

    final weatherRow = <Widget>[];
    for (final key in ['airTemp', 'humidity', 'trackTemp']) {
      final field = _buildSettingWidgetByKey(key, showFavorite: false);
      if (field != null) {
        weatherRow.add(field);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_useSimplePaperCopy()) ...[
                      Text(
                        isEnglish ? 'SETTING SHEET' : 'SETTING SHEET',
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      carName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_useSimplePaperCopy())
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    isEnglish ? 'Paper Layout' : '紙レイアウト',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (trackSummary != null) ...[
            const SizedBox(height: 8),
            Text(
              trackSummary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildResponsiveFieldWrap(firstRow, minItemWidth: 240),
          const SizedBox(height: 16),
          _buildResponsiveFieldWrap(secondRow, minItemWidth: 220),
          if (weatherRow.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildResponsiveFieldWrap(weatherRow, minItemWidth: 180),
          ],
        ],
      ),
    );
  }

  Widget _buildPaperSectionButtonLegacy({
    required String category,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required double height,
    required bool isEnglish,
    bool showFavorite = true,
    int previewCount = 3,
  }) {
    final categorySettings = _getCategorySettings(category);
    final theme = Theme.of(context);
    final previewItems =
        _buildPaperPreviewItems(categorySettings, previewCount: previewCount);
    final canOpen = categorySettings.isNotEmpty;

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canOpen
              ? () => _showPaperSectionEditor(
                    category: category,
                    title: title,
                    subtitle: subtitle,
                    isEnglish: isEnglish,
                    showFavorite: showFavorite,
                  )
              : null,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: tint.withValues(alpha: 0.32),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: 0.16),
                  theme.colorScheme.surface,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: tint.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tint.withValues(alpha: 0.16),
                        ),
                        child: Icon(icon, color: tint),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.72),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 18,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isEnglish ? 'Tap to edit this section' : 'タップしてこのセクションを編集',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: previewItems.isEmpty
                        ? Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              isEnglish
                                  ? 'No values entered yet.'
                                  : 'まだ入力されている値はありません。',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: previewItems.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.key,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        item.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: tint.withValues(alpha: 0.12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          isEnglish
                              ? '${categorySettings.length} items'
                              : '${categorySettings.length}項目',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: tint,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          isEnglish ? 'Open Editor' : '編集を開く',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: tint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaperSectionButtonWithPreview({
    required String category,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required double height,
    required bool isEnglish,
    bool showFavorite = true,
    int previewCount = 3,
  }) {
    final categorySettings = _getCategorySettings(category);
    final theme = Theme.of(context);
    final canOpen = categorySettings.isNotEmpty;
    final displayTitle = _paperCategoryTitle(category, isEnglish);
    final displaySubtitle = _paperCategorySubtitle(category, isEnglish);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMicro = constraints.maxHeight < 150;
          final isTight = constraints.maxHeight < 205;
          final isCompact = constraints.maxHeight < 235;
          final contentPadding = isMicro
              ? const EdgeInsets.all(14)
              : isTight
                  ? const EdgeInsets.all(16)
                  : const EdgeInsets.all(18);
          final subtitleMaxLines = isMicro
              ? 1
              : isTight
                  ? 2
                  : 3;
          final visiblePreviewCount = isMicro
              ? 0
              : isTight
                  ? 0
                  : isCompact
                      ? 1
                      : previewCount;
          final previewItems = _buildPaperPreviewItems(
            categorySettings,
            previewCount: visiblePreviewCount,
          );
          final showInstruction = !isMicro;
          final showPreview = previewItems.isNotEmpty;
          final showEmptyState = !isMicro && !showPreview;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canOpen
                  ? () => _showPaperSectionEditor(
                        category: category,
                        title: title,
                        subtitle: subtitle,
                        isEnglish: isEnglish,
                        showFavorite: showFavorite,
                      )
                  : null,
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: tint.withValues(alpha: 0.32),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tint.withValues(alpha: 0.16),
                      theme.colorScheme.surface,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: contentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: isMicro ? 40 : 44,
                            height: isMicro ? 40 : 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: tint.withValues(alpha: 0.16),
                            ),
                            child: Icon(icon, color: tint),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displaySubtitle,
                                  maxLines: subtitleMaxLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.72),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                      if (showInstruction) ...[
                        SizedBox(height: isTight ? 10 : 14),
                        Text(
                          isEnglish
                              ? 'Tap to edit this section'
                              : 'タップしてこのセクションを編集',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: tint,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (showPreview || showEmptyState) ...[
                        SizedBox(height: isTight ? 8 : 12),
                        Expanded(
                          child: showPreview
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: previewItems.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.key,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme
                                                    .colorScheme.onSurface
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              item.value,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.right,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                )
                              : Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    isEnglish
                                        ? 'No values entered yet.'
                                        : 'まだ入力されている値はありません。',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.65),
                                    ),
                                  ),
                                ),
                        ),
                      ] else
                        const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMicro ? 10 : 12,
                          vertical: isMicro ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: tint.withValues(alpha: 0.12),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              isEnglish
                                  ? '${categorySettings.length} items'
                                  : '${categorySettings.length}項目',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: tint,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isEnglish ? 'Open Editor' : '編集を開く',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: tint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaperSectionButton({
    required String category,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color tint,
    required double height,
    required bool isEnglish,
    bool showFavorite = true,
  }) {
    final categorySettings = _getCategorySettings(category);
    final theme = Theme.of(context);
    final canOpen = categorySettings.isNotEmpty;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMicro = constraints.maxHeight < 150;
          final isTight = constraints.maxHeight < 205;
          final contentPadding = isMicro
              ? const EdgeInsets.all(14)
              : isTight
                  ? const EdgeInsets.all(16)
                  : const EdgeInsets.all(18);
          final subtitleMaxLines = isMicro
              ? 1
              : isTight
                  ? 2
                  : 3;

          Widget buildItemBadge({
            required EdgeInsets padding,
            bool showAction = true,
          }) {
            return Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: tint.withValues(alpha: 0.12),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    isEnglish
                        ? '${categorySettings.length} items'
                        : '${categorySettings.length}項目',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (showAction)
                    Text(
                      isEnglish ? 'Open Editor' : '編集を開く',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: tint,
                      ),
                    ),
                ],
              ),
            );
          }

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canOpen
                  ? () => _showPaperSectionEditor(
                        category: category,
                        title: title,
                        subtitle: subtitle,
                        isEnglish: isEnglish,
                        showFavorite: showFavorite,
                      )
                  : null,
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: tint.withValues(alpha: 0.32),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tint.withValues(alpha: 0.16),
                      theme.colorScheme.surface,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: contentPadding,
                  child: isMicro
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tint.withValues(alpha: 0.16),
                                  ),
                                  child: Icon(icon, color: tint, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.72),
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ],
                            ),
                            const Spacer(),
                            buildItemBadge(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              showAction: false,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: isMicro ? 40 : 44,
                                  height: isMicro ? 40 : 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tint.withValues(alpha: 0.16),
                                  ),
                                  child: Icon(icon, color: tint),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        maxLines: subtitleMaxLines,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.72),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ],
                            ),
                            SizedBox(height: isTight ? 10 : 14),
                            if (!_useSimplePaperCopy()) ...[
                              Text(
                                isEnglish
                                    ? 'Tap to open this section'
                                    : 'タップしてこのセクションを開く',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: tint,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            SizedBox(height: isTight ? 8 : 12),
                            if (!_useSimplePaperCopy())
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    isEnglish
                                        ? 'Open this area to edit the detailed values.'
                                        : 'このエリアを開いて詳細な設定値を編集します。',
                                    maxLines: isMicro ? 1 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.68),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ),
                            buildItemBadge(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPaperSectionEditor({
    required String category,
    required String title,
    required String subtitle,
    required bool isEnglish,
    bool showFavorite = true,
  }) {
    final categorySettings = _getCategorySettings(category);
    if (categorySettings.isEmpty) {
      return;
    }
    final displayTitle = _paperCategoryTitle(category, isEnglish);
    final displaySubtitle = _paperCategorySubtitle(category, isEnglish);

    showDialog(
      context: context,
      builder: (dialogContext) => _buildResponsiveDialog(
        context: dialogContext,
        maxWidth: 920,
        heightFactor: 0.9,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: Theme.of(dialogContext)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displaySubtitle,
                          style: Theme.of(dialogContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(dialogContext)
                                    .colorScheme
                                    .onPrimaryContainer
                                    .withValues(alpha: 0.78),
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_useSimplePaperCopy()) ...[
                      Text(
                        isEnglish
                            ? 'This editor focuses only on the selected paper area.'
                            : '選択した紙のエリアだけを集中して編集できます。',
                        style: Theme.of(dialogContext).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildPaperFieldGrid(
                      categorySettings,
                      showFavorite: showFavorite,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SettingItem> _getCategorySettings(String category) {
    if (_carSettingDefinition == null) {
      return const [];
    }

    return _filterHiddenTrf420xCompositeParts(
      _carSettingDefinition!.availableSettings
          .where((setting) => displayCategoryForSetting(setting) == category),
    );
  }

  List<SettingItem> _filterHiddenTrf420xCompositeParts(
    Iterable<SettingItem> items,
  ) {
    if (!_isTrf420x) {
      return items.toList();
    }

    return items
        .where((setting) => !_isTrf420xHiddenCompositePart(setting.key))
        .toList();
  }

  String _buildPaperSectionSubtitle(String category, bool isEnglish) {
    switch (category) {
      case 'front':
        return isEnglish ? 'Upper-left area on the sheet' : '紙の左上にあるフロント周辺';
      case 'frontDamper':
        return isEnglish
            ? 'Front shock and spring settings'
            : 'フロント側のダンパーとスプリング';
      case 'rear':
        return isEnglish ? 'Upper-right area on the sheet' : '紙の右上にあるリア周辺';
      case 'rearDamper':
        return isEnglish ? 'Rear shock and spring settings' : 'リア側のダンパーとスプリング';
      case 'top':
        return isEnglish
            ? 'Lower area for top deck and chassis'
            : '紙の下側にあるトップデッキ周辺';
      case 'other':
        return isEnglish
            ? 'Lower-right area for power and body'
            : '紙の右下にあるメカとボディ';
      case 'memo':
        return isEnglish ? 'Notes section at the bottom' : '紙の下部にあるメモ欄';
      default:
        return '';
    }
  }

  List<MapEntry<String, String>> _buildPaperPreviewItems(
    List<SettingItem> items, {
    required int previewCount,
  }) {
    final filledItems = <MapEntry<String, String>>[];
    final emptyItems = <MapEntry<String, String>>[];

    for (final setting in items) {
      if (_isTrf420xHiddenCompositePart(setting.key)) {
        continue;
      }
      final previewValue = _buildSettingPreviewValue(setting);
      final previewItem = MapEntry(setting.label, previewValue);
      if (previewValue == '-') {
        emptyItems.add(previewItem);
      } else {
        filledItems.add(previewItem);
      }
    }

    final orderedItems = <MapEntry<String, String>>[
      ...filledItems.take(previewCount),
    ];

    if (orderedItems.length < previewCount) {
      orderedItems.addAll(
        emptyItems.take(previewCount - orderedItems.length),
      );
    }

    return orderedItems;
  }

  String _buildSettingPreviewValue(SettingItem setting) {
    final trf420xCompositeValue = _buildTrf420xCompositePreviewValue(setting);
    if (trf420xCompositeValue != null) {
      return trf420xCompositeValue;
    }

    final value = settings[setting.key];
    if (value == null) {
      return '-';
    }

    if (value is num) {
      final numericText = value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value
              .toStringAsFixed(1)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
      if (setting.unit != null && setting.unit!.isNotEmpty) {
        return '$numericText${setting.unit}';
      }
      return numericText;
    }

    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }

    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map) {
        final row = first['row'];
        final col = first['col'];
        if (row is int && col is int) {
          return '${row + 1},${col + 1}';
        }
      }
      return '${value.length}';
    }

    return value.toString();
  }

  String? _buildTrf420xCompositePreviewValue(SettingItem setting) {
    final compositeType = _compositeTypeForSetting(setting);
    if (compositeType == null) {
      return null;
    }

    final isEnglish =
        Provider.of<SettingsProvider>(context, listen: false).isEnglish;
    final holeUnit = isEnglish ? 'hole(s)' : '穴';
    final values = switch (compositeType) {
      'stabilizer' => [
          _previewTextForSettingValue(
            settings[_compositeKey(setting, 'diameterKey', setting.key)],
            suffix: 'φ',
          ),
          _previewTextForSettingValue(
            settings[_compositeKey(setting, 'noteKey', '${setting.key}Note')],
          ),
        ],
      'diffOil' => [
          _previewTextForSettingValue(
            settings[
                _compositeKey(setting, 'oilTypeKey', '${setting.key}Type')],
          ),
          _previewTextForSettingValue(
            settings[_compositeKey(setting, 'oilKey', setting.key)],
            prefix: '#',
          ),
          _previewTextForSettingValue(
            settings[
                _compositeKey(setting, 'weightKey', '${setting.key}Weight')],
            suffix: 'g',
          ),
        ],
      'damperPiston' => [
          _previewTextForSettingValue(
            _settingValueForKeys(
              _compositeKeys(
                setting,
                primaryKey: 'pistonKey',
                fallback: setting.key,
                aliasesKey: 'pistonAliases',
              ),
            ),
            suffix: 'φ',
          ),
          _previewTextForSettingValue(
            _settingValueForKeys(
              _compositeKeys(
                setting,
                primaryKey: 'holeKey',
                fallback: '${setting.key}Hole',
                aliasesKey: 'holeAliases',
              ),
            ),
            suffix: holeUnit,
          ),
        ],
      'damperOil' => [
          _previewTextForSettingValue(
            _settingValueForKeys(
              _compositeKeys(
                setting,
                primaryKey: 'oilKey',
                fallback: setting.key,
                aliasesKey: 'oilAliases',
              ),
            ),
            prefix: '#',
          ),
          _previewTextForSettingValue(
            _settingValueForKeys(
              _compositeKeys(
                setting,
                primaryKey: 'oilNameKey',
                fallback: '${setting.key}Name',
                aliasesKey: 'oilNameAliases',
              ),
            ),
          ),
        ],
      _ => const <String>[],
    };

    final filledValues = values.where((value) => value.isNotEmpty).toList();
    if (filledValues.isEmpty) {
      return '-';
    }
    return filledValues.join(' / ');
  }

  String? _compositeTypeForSetting(SettingItem setting) {
    final compositeType = setting.constraints['composite'];
    return compositeType is String ? compositeType : null;
  }

  String _compositeKey(
    SettingItem setting,
    String constraintKey,
    String fallback,
  ) {
    final value = setting.constraints[constraintKey];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  List<String> _compositeKeys(
    SettingItem setting, {
    required String primaryKey,
    required String fallback,
    String? aliasesKey,
  }) {
    final keys = <String>[
      _compositeKey(setting, primaryKey, fallback),
    ];

    final aliases = aliasesKey == null ? null : setting.constraints[aliasesKey];
    if (aliases is List) {
      keys.addAll(aliases.whereType<String>());
    }

    return keys.toSet().toList(growable: false);
  }

  String _previewTextForSettingValue(
    dynamic value, {
    String prefix = '',
    String suffix = '',
  }) {
    if (value == null) {
      return '';
    }

    final text = value is num
        ? (value == value.roundToDouble()
            ? value.toStringAsFixed(0)
            : value
                .toStringAsFixed(1)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), ''))
        : value.toString().trim();

    if (text.isEmpty) {
      return '';
    }
    return '$prefix$text$suffix';
  }

  dynamic _settingValueForKeys(List<String> keys) {
    for (final key in keys) {
      final value = settings[key];
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      return value;
    }
    return null;
  }

  String _settingTextForKey(
    String key, {
    List<String> aliases = const [],
  }) {
    final value = _settingValueForKeys([key, ...aliases]);
    return value?.toString() ?? '';
  }

  void _updateTextSettingWithAliases(
    String key,
    List<String> aliases,
    String value,
  ) {
    setState(() {
      settings[key] = value;
      for (final alias in aliases) {
        settings[alias] = value;
      }
    });
  }

  Widget _buildPaperFieldGrid(
    List<SettingItem> items, {
    bool showFavorite = true,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        int columns = 1;

        if (constraints.maxWidth >= 840) {
          columns = 3;
        } else if (constraints.maxWidth >= 520) {
          columns = 2;
        }

        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((setting) {
            return SizedBox(
              width: itemWidth,
              child: showFavorite
                  ? _buildSettingFieldWithFavorite(setting)
                  : _buildSettingField(setting),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildResponsiveFieldWrap(
    List<Widget> children, {
    double minItemWidth = 220,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final maxWidth = constraints.maxWidth;
        var columns = (maxWidth / (minItemWidth + spacing)).floor();
        if (columns < 1) {
          columns = 1;
        }

        final itemWidth = columns == 1
            ? maxWidth
            : (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _buildSettingNameField(
    bool isEnglish, {
    bool dense = false,
  }) {
    return TextField(
      controller: _settingNameController,
      decoration: InputDecoration(
        labelText: isEnglish ? 'Setting Name' : 'セッティング名',
        hintText: isEnglish ? 'e.g. Race Setup 1' : '例: レースセットアップ1',
        border: const OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: dense ? 14.0 : 16.0,
        ),
      ),
    );
  }

  Widget _buildTrackNameField(
    bool isEnglish, {
    bool dense = false,
  }) {
    final helperText = _buildTrackSummary(isEnglish);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _trackNameController,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Track Name' : 'トラック名',
                  hintText: isEnglish ? 'e.g. Tamiya Circuit' : '例: タミヤサーキット',
                  border: const OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: dense ? 14.0 : 16.0,
                  ),
                  prefixIcon: _currentTrack != null
                      ? Icon(
                          _currentTrack!.type == 'indoor'
                              ? Icons.home_work
                              : Icons.landscape,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(Icons.place),
                  suffixIcon: _isLocationLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _refreshLocation,
              icon: const Icon(Icons.my_location),
              visualDensity: VisualDensity.compact,
              tooltip: isEnglish ? 'Get current location' : '現在地から候補を取得',
            ),
            IconButton(
              onPressed: _searchTrackManually,
              icon: const Icon(Icons.search),
              visualDensity: VisualDensity.compact,
              tooltip: isEnglish ? 'Search track' : 'トラック検索',
            ),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ],
      ],
    );
  }

  String? _buildTrackSummary(bool isEnglish) {
    if (_currentTrack == null) {
      return null;
    }

    final typeLabel = isEnglish
        ? (_currentTrack!.type == 'indoor' ? 'Indoor' : 'Outdoor')
        : (_currentTrack!.type == 'indoor' ? '屋内' : '屋外');
    final surfaceLabel = _currentTrack!.surfaceType == 'carpet'
        ? (isEnglish ? 'Carpet' : 'カーペット')
        : (isEnglish ? 'Asphalt' : 'アスファルト');

    return '${_currentTrack!.prefecture} / $typeLabel / $surfaceLabel';
  }

  SettingItem? _getSettingItemByKey(String key) {
    if (_carSettingDefinition == null) {
      return null;
    }

    for (final setting in _carSettingDefinition!.availableSettings) {
      if (setting.key == key) {
        return setting;
      }
    }
    return null;
  }

  Widget? _buildSettingWidgetByKey(
    String key, {
    bool showFavorite = true,
  }) {
    final setting = _getSettingItemByKey(key);
    if (setting == null) {
      return null;
    }

    return showFavorite
        ? _buildSettingFieldWithFavorite(setting)
        : _buildSettingField(setting);
  }
}
