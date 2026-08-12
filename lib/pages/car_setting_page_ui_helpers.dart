part of 'car_setting_page.dart';

class _SelectGuideLabels {
  final String start;
  final String end;

  const _SelectGuideLabels({
    required this.start,
    required this.end,
  });
}

// 設定項目の型に応じたデフォルト値を返す。
dynamic _getDefaultValueForType(SettingItem setting) {
  switch (setting.type) {
    case 'number':
      final parsedDefault = double.tryParse(setting.defaultValue ?? '');
      final constraintDefault = setting.constraints['default'];
      return parsedDefault ??
          (constraintDefault is num ? constraintDefault.toDouble() : null) ??
          0.0;
    case 'text':
      if (setting.key == 'date' && setting.isAutoFilled) {
        return DateTime.now().toString().split(' ')[0];
      }
      return setting.defaultValue ?? '';
    case 'select':
      return setting.defaultValue ?? setting.options?.first;
    case 'slider':
      final parsedDefault = double.tryParse(setting.defaultValue ?? '');
      return parsedDefault ?? setting.constraints['min'] ?? 0.0;
    case 'grid':
      return <Map<String, int>>[];
    default:
      return null;
  }
}

WeatherStatus _weatherStatusForLocation(LocationStatus status) {
  return switch (status) {
    LocationStatus.permissionDenied => WeatherStatus.locationPermissionDenied,
    LocationStatus.serviceDisabled => WeatherStatus.locationServiceDisabled,
    LocationStatus.timeout => WeatherStatus.locationTimeout,
    _ => WeatherStatus.noLocation,
  };
}

String _paperCategoryTitle(String category, bool isEnglish) {
  switch (category) {
    case 'front':
      return isEnglish ? 'Front' : 'フロント';
    case 'rear':
      return isEnglish ? 'Rear' : 'リア';
    case 'frontDamper':
      return isEnglish ? 'Front Damper' : 'フロントダンパー';
    case 'rearDamper':
      return isEnglish ? 'Rear Damper' : 'リアダンパー';
    case 'top':
      return isEnglish ? 'Top Deck' : 'トップ';
    case 'other':
      return isEnglish ? 'Other' : 'その他';
    case 'memo':
      return isEnglish ? 'Notes' : 'メモ';
    default:
      return category;
  }
}

String _paperCategorySubtitle(String category, bool isEnglish) {
  switch (category) {
    case 'front':
      return isEnglish ? 'Front suspension and steering' : 'フロント周り';
    case 'rear':
      return isEnglish ? 'Rear suspension and drivetrain' : 'リア周り';
    case 'frontDamper':
      return isEnglish ? 'Front shock and spring' : '前ダンパー';
    case 'rearDamper':
      return isEnglish ? 'Rear shock and spring' : '後ダンパー';
    case 'top':
      return isEnglish ? 'Deck and chassis' : 'シャーシ周り';
    case 'other':
      return isEnglish ? 'Power, body, tires' : 'メカ・ボディ・タイヤ';
    case 'memo':
      return isEnglish ? 'Free notes' : 'メモ';
    default:
      return '';
  }
}

String _selectGuideValue(String settingKey, String edge) {
  return '__select_guide_${settingKey}_$edge';
}

bool _isSelectGuideValue(String? value) {
  return value?.startsWith('__select_guide_') ?? false;
}

BoxConstraints _responsiveDialogConstraints(
  BuildContext context, {
  double maxWidth = 720,
  double heightFactor = 0.85,
}) {
  final size = MediaQuery.sizeOf(context);
  return BoxConstraints(
    maxWidth: maxWidth,
    maxHeight: size.height * heightFactor,
  );
}

Dialog _buildResponsiveDialog({
  required BuildContext context,
  required Widget child,
  double maxWidth = 720,
  double heightFactor = 0.85,
}) {
  return Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: _responsiveDialogConstraints(
        context,
        maxWidth: maxWidth,
        heightFactor: heightFactor,
      ),
      child: child,
    ),
  );
}

class _SettingTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  const _SettingTabBarDelegate({
    required this.tabBar,
    required this.backgroundColor,
  });

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SettingTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
