part of 'car_setting_page.dart';

// トラック検索ダイアログ
class _TrackSearchDialog extends StatefulWidget {
  final bool isEnglish;
  final Function(TrackLocation) onTrackSelected;

  const _TrackSearchDialog({
    required this.isEnglish,
    required this.onTrackSelected,
  });

  @override
  State<_TrackSearchDialog> createState() => _TrackSearchDialogState();
}

class _TrackSearchDialogState extends State<_TrackSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<TrackLocation> _searchResults = [];
  List<TrackLocation> _allTracks = [];
  String? _selectedPrefecture;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    try {
      final tracks = await TrackLocationService.instance.loadTrackLocations();
      setState(() {
        _allTracks = tracks;
        _searchResults = tracks; // 初期状態では全てのトラックを表示
        _isLoading = false;
      });
    } catch (e) {
      debugLog('トラック読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _performSearch() {
    setState(() {
      String query = _searchController.text.trim();
      if (query.isEmpty && _selectedPrefecture == null) {
        _searchResults = _allTracks;
      } else {
        _searchResults = _allTracks.where((track) {
          bool matchesName = query.isEmpty ||
              track.name.toLowerCase().contains(query.toLowerCase());
          bool matchesPrefecture = _selectedPrefecture == null ||
              track.prefecture == _selectedPrefecture;
          return matchesName && matchesPrefecture;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dialogHeight = MediaQuery.sizeOf(context).height * 0.65;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.isEnglish ? 'Search Track' : 'トラック検索'),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: dialogHeight),
          child: Column(
            children: [
              // 検索フィールド
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: widget.isEnglish ? 'Track Name' : 'トラック名',
                  hintText: widget.isEnglish ? 'Enter track name' : 'トラック名を入力',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => _performSearch(),
              ),
              const SizedBox(height: 16),

              // 都道府県フィルター
              DropdownButtonFormField<String>(
                initialValue: _selectedPrefecture,
                decoration: InputDecoration(
                  labelText: widget.isEnglish ? 'Prefecture' : '都道府県',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child:
                        Text(widget.isEnglish ? 'All Prefectures' : '全ての都道府県'),
                  ),
                  ...(_allTracks
                          .map((track) => track.prefecture)
                          .toSet()
                          .toList()
                        ..sort())
                      .map(
                    (prefecture) => DropdownMenuItem<String>(
                      value: prefecture,
                      child: Text(prefecture),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedPrefecture = value;
                  });
                  _performSearch();
                },
              ),
              const SizedBox(height: 16),

              // 検索結果リスト
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              widget.isEnglish
                                  ? 'No tracks found'
                                  : 'トラックが見つかりません',
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final track = _searchResults[index];
                              final surfaceText = track.surfaceType == 'carpet'
                                  ? (widget.isEnglish ? 'Carpet' : 'カーペット')
                                  : (widget.isEnglish ? 'Asphalt' : 'アスファルト');
                              final typeText = track.type == 'indoor'
                                  ? (widget.isEnglish ? 'Indoor' : '屋内')
                                  : (widget.isEnglish ? 'Outdoor' : '屋外');

                              return ListTile(
                                title: Text(track.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${track.prefecture} - ${track.address}'),
                                    Text(
                                      '$typeText • $surfaceText',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      track.surfaceType == 'carpet'
                                          ? Icons.texture
                                          : Icons.straighten,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      track.type == 'indoor'
                                          ? Icons.home
                                          : Icons.landscape,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  widget.onTrackSelected(track);
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isEnglish ? 'Cancel' : 'キャンセル'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
