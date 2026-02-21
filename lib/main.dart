import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  runApp(const GameCounterApp());
}

class GameCounterApp extends StatelessWidget {
  const GameCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brettspiel Zähler',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const GameSelectionScreen(),
        '/entry': (context) => const ScoreEntryScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}

// Datenbank-Helfer
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'game_counter.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_type TEXT NOT NULL,
            date TEXT NOT NULL,
            players TEXT NOT NULL, -- JSON array of {"name":"...", "score":...}
            notes TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertSession(Map<String, dynamic> session) async {
    final database = await db;
    return await database.insert('sessions', session);
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final database = await db;
    return await database.query('sessions', orderBy: 'date DESC');
  }

  Future<List<Map<String, dynamic>>> getSessionsByGame(String gameType) async {
    final database = await db;
    return await database.query(
      'sessions',
      where: 'game_type = ?',
      whereArgs: [gameType],
      orderBy: 'date DESC',
    );
  }
}

// Model
class GameSession {
  final String gameType;
  final DateTime date;
  final List<Map<String, dynamic>> players; // {name, score}
  final String? notes;

  GameSession({
    required this.gameType,
    required this.date,
    required this.players,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'game_type': gameType,
      'date': date.toIso8601String(),
      'players': jsonEncode(players),
      'notes': notes,
    };
  }

  factory GameSession.fromMap(Map<String, dynamic> map) {
    final playersList = jsonDecode(map['players']) as List;
    return GameSession(
      gameType: map['game_type'],
      date: DateTime.parse(map['date']),
      players: playersList.map((e) => Map<String, dynamic>.from(e)).toList(),
      notes: map['notes'],
    );
  }
}

// Spielauswahl-Bildschirm
class GameSelectionScreen extends StatelessWidget {
  const GameSelectionScreen({super.key});

  static const List<Map<String, String>> games = [
    {'key': 'phase10', 'title': 'Phase 10', 'icon': '🔟'},
    {'key': 'uno', 'title': 'Uno', 'icon': '🃏'},
    {'key': 'rumikub', 'title': 'Rumikub', 'icon': '🧩'},
    {'key': 'wizard', 'title': 'Wizard', 'icon': '🧙'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brettspiel Zähler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'Verlauf anzeigen',
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/entry',
                  arguments: {'gameType': game['key'], 'gameTitle': game['title']},
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(game['icon']!, style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text(
                    game['title']!,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Punkte-Eingabe-Bildschirm
class ScoreEntryScreen extends StatefulWidget {
  const ScoreEntryScreen({super.key});

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _gameType;
  String? _gameTitle;
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _scoreControllers = [];
  final _notesController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _gameType = args['gameType'];
    _gameTitle = args['gameTitle'];
    // Start with 2 players by default
    if (_nameControllers.isEmpty) {
      _addPlayerField();
      _addPlayerField();
    }
  }

  void _addPlayerField() {
    setState(() {
      _nameControllers.add(TextEditingController());
      _scoreControllers.add(TextEditingController());
    });
  }

  void _removePlayerField(int index) {
    if (_nameControllers.length > 1) {
      setState(() {
        _nameControllers.removeAt(index);
        _scoreControllers.removeAt(index);
      });
    }
  }

  Future<void> _saveSession() async {
    if (_formKey.currentState!.validate()) {
      final players = <Map<String, dynamic>>[];
      for (int i = 0; i < _nameControllers.length; i++) {
        final name = _nameControllers[i].text.trim();
        final score = int.tryParse(_scoreControllers[i].text.trim()) ?? 0;
        if (name.isNotEmpty) {
          players.add({'name': name, 'score': score});
        }
      }

      final session = GameSession(
        gameType: _gameType,
        date: DateTime.now(),
        players: players,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      await DatabaseHelper().insertSession(session.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('gespeichert!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_gameTitle - Punkte eintragen'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Spielername und Punkte:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...List.generate(_nameControllers.length, (index) {
              return Row(
                key: ValueKey(index),
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _nameControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Name ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Name angeben' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _scoreControllers[index],
                      decoration: const InputDecoration(
                        labelText: 'Punkte',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Punkte' : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removePlayerField(index),
                  ),
                ],
              );
            }),
            TextButton.icon(
              onPressed: _addPlayerField,
              icon: const Icon(Icons.add),
              label: const Text('Spieler hinzufügen'),
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notizen (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveSession,
              icon: const Icon(Icons.save),
              label: const Text('SPEICHERN'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _nameControllers) c.dispose();
    for (final c in _scoreControllers) c.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// Verlaufsbildschirm
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<GameSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final all = await DatabaseHelper().getAllSessions();
    setState(() {
      _sessions = all.map((map) => GameSession.fromMap(map)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielverlauf'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _sessions.isEmpty
          ? const Center(child: Text('Noch keine Spiele gespeichert.'))
          : ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final s = _sessions[index];
                final dateStr = '${s.date.day}.${s.date.month}.${s.date.year}';
                final totalScore = s.players.fold<int>(0, (sum, p) => sum + (p['score'] as int));
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.sports_esports),
                    title: Text('${_gameTitle(s.gameType)} • $dateStr'),
                    subtitle: Text(
                      s.players.map((p) => '${p['name']}: ${p['score']}').join(', ') +
                          (s.notes != null ? '\nNotiz: ${s.notes}' : ''),
                    ),
                    trailing: Text(
                      '∑ $totalScore',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }

  String _gameTitle(String key) {
    const titles = {
      'phase10': 'Phase 10',
      'uno': 'Uno',
      'rumikub': 'Rumikub',
      'wizard': 'Wizard',
    };
    return titles[key] ?? key;
  }
}
