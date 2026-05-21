import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/state/providers.dart';
import 'package:board_master/ui/records/record_card.dart';
import 'package:board_master/models/game_record.dart';

class RecordBrowserScreen extends ConsumerStatefulWidget {
  const RecordBrowserScreen({super.key});

  @override
  ConsumerState<RecordBrowserScreen> createState() => _RecordBrowserScreenState();
}

class _RecordBrowserScreenState extends ConsumerState<RecordBrowserScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(recordBrowserProvider.notifier).loadRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordBrowserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(recordBrowserProvider.notifier).loadRecords(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip('All', null, state.filterType),
                const SizedBox(width: 8),
                _filterChip('Go', GameType.go, state.filterType),
                const SizedBox(width: 8),
                _filterChip('Chess', GameType.chess, state.filterType),
              ],
            ),
          ),
          const Divider(height: 1),
          // Records list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.records.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.library_books,
                                size: 48, color: Colors.brown),
                            SizedBox(height: 12),
                            Text('No game records yet',
                                style: TextStyle(color: Colors.brown)),
                            SizedBox(height: 4),
                            Text('Play a game to create one!',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: state.records.length,
                        itemBuilder: (context, index) {
                          final record = state.records[index];
                          return RecordCard(
                            record: record,
                            onTap: () => _showDetail(context, record),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, GameRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(record.title ?? 'Game Record',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _detailRow('Game', record.gameType.name == 'go' ? 'Go' : 'Chinese Chess'),
              _detailRow('Black/Red', record.playerName),
              _detailRow('White/Black', record.opponentName),
              if (record.result != null) _detailRow('Result', record.result!),
              _detailRow('Date', record.datePlayed.toIso8601String().substring(0, 10)),
              _detailRow('Moves', '${record.totalMoves}'),
              _detailRow('Difficulty', record.difficulty),
              if (record.gameType.name == 'go') ...[
                _detailRow('Board Size', '${record.boardSize}'),
                _detailRow('Komi', '${record.komi}'),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _filterChip(String label, GameType? type, GameType? current) {
    final selected = type == current || (type == null && current == null);
    return GestureDetector(
      onTap: () => ref.read(recordBrowserProvider.notifier).setFilter(type),
      child: Chip(
        label: Text(label),
        backgroundColor:
            selected ? const Color(0xFF5C3A28) : Colors.grey.shade200,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide.none,
      ),
    );
  }
}
