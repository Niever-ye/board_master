import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/models/game_record.dart';
import 'package:board_master/storage/record_dao.dart';
import 'package:board_master/storage/seed_data.dart';

class RecordBrowserState {
  final List<GameRecord> records;
  final GameType? filterType;
  final bool isLoading;
  final bool loaded;

  const RecordBrowserState({
    this.records = const [],
    this.filterType,
    this.isLoading = false,
    this.loaded = false,
  });

  RecordBrowserState copyWith({
    List<GameRecord>? records,
    GameType? filterType,
    bool? isLoading,
    bool? loaded,
    bool clearFilter = false,
  }) {
    return RecordBrowserState(
      records: records ?? this.records,
      filterType: clearFilter ? null : (filterType ?? this.filterType),
      isLoading: isLoading ?? this.isLoading,
      loaded: loaded ?? this.loaded,
    );
  }
}

class RecordBrowserNotifier extends StateNotifier<RecordBrowserState> {
  final RecordDao _dao;

  RecordBrowserNotifier(this._dao) : super(const RecordBrowserState());

  Future<void> loadRecords() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true);

    await SeedData.seedIfNeeded(_dao);
    final records = await _dao.getRecords(
      gameType: state.filterType,
      limit: 100,
    );

    state = state.copyWith(records: records, isLoading: false, loaded: true);
  }

  Future<void> setFilter(GameType? type) async {
    if (type == null) {
      state = state.copyWith(clearFilter: true, isLoading: true);
    } else {
      state = state.copyWith(filterType: type, isLoading: true);
    }
    final records = await _dao.getRecords(
      gameType: state.filterType,
      limit: 100,
    );
    state = state.copyWith(records: records, isLoading: false);
  }

  Future<void> deleteRecord(int id) async {
    await _dao.delete(id);
    await loadRecords();
  }

  Future<GameRecord?> getRecord(int id) async {
    return _dao.getById(id);
  }

  Future<List<GameRecord>> search(String query) async {
    return _dao.searchRecords(query);
  }
}
