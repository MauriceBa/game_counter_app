import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

void main() {
  runApp(const GameCounterApp());
}

class GameCounterApp extends StatelessWidget {
  const GameCounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brettspiel Zähler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const GameSelectionScreen(),
        '/entry': (context) => const ScoreEntryScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}

// ==========================================
// Datenbank-Helfer
// ==========================================
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

  Future<int> deleteSession(int id) async {
    final database = await db;
    return await database.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// ==========================================
// Model
// ==========================================
class GameSession {
  final int? id;
  final String gameType;
  final DateTime date;
  final List<Map<String, dynamic>> players; // {name, score}
  final String? notes;

  GameSession({
    this.id,
    required this.gameType,
    required this.date,
    required this.players,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'game_type': gameType,
      'date': date.toIso8601String(),
      'players': jsonEncode(players),
      'notes': notes,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory GameSession.fromMap(Map<String, dynamic> map) {
    final playersList = jsonDecode(map['players']) as List;
    return GameSession(
      id: map['id'],
      gameType: map['game_type'],
      date: DateTime.parse(map['date']),
      players: playersList.map((e) => Map<String, dynamic>.from(e)).toList(),
      notes: map['notes'],
    );
  }
}

// ==========================================
// Spielauswahl-Bildschirm
// ==========================================
class GameSelectionScreen extends StatelessWidget {
  const GameSelectionScreen({super.key});

  static final List<Map<String, dynamic>> games = [
    {'key': 'phase10', 'title': 'Phase 10', 'icon': '🔟', 'color': Colors.redAccent},
    {'key': 'uno', 'title': 'Uno', 'icon': '🃏', 'color': Colors.green},
    {'key': 'rumikub', 'title': 'Rummikub', 'icon': '🧩', 'color': Colors.blueAccent},
    {'key': 'wizard', 'title': 'Wizard', 'icon': '🧙', 'color': Colors.deepPurpleAccent},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Brettspiel Zähler', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.pushNamed(context, '/history'),
                tooltip: 'Verlauf',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final game = games[index];
                  final color = game['color'] as Color;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 4,
                    shadowColor: color.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/entry',
                          arguments: {
                            'gameType': game['key'],
                            'gameTitle': game['title'],
                            'color': color.value,
                          },
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.05),
                              color.withOpacity(0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(game['icon'] as String, style: const TextStyle(fontSize: 54)),
                            const SizedBox(height: 16),
                            Text(
                              game['title'] as String,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: games.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// Punkte-Eingabe-Bildschirm
// ==========================================
class ScoreEntryScreen extends StatefulWidget {
  const ScoreEntryScreen({super.key});

  @override
  State<ScoreEntryScreen> createState() => _ScoreEntryScreenState();
}

class _ScoreEntryScreenState extends State<ScoreEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _gameType;
  late String _gameTitle;
  late Color _themeColor;

  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _scoreControllers = [];
  final _notesController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _gameType = args['gameType'];
    _gameTitle = args['gameTitle'];
    _themeColor = Color(args['color'] ?? Colors.indigo.value);

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
        _nameControllers[index].dispose();
        _scoreControllers[index].dispose();
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

      if (players.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte mindestens einen Spieler eintragen.')),
        );
        return;
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
          SnackBar(
            content: const Text('Spiel erfolgreich gespeichert! 🏆'),
            backgroundColor: _themeColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _themeColor,
          brightness: Theme.of(context).brightness,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_gameTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              Text(
                'Spieler & Punkte',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ...List.generate(_nameControllers.length, (index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: _themeColor.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _themeColor.withOpacity(0.15),
                          foregroundColor: _themeColor,
                          child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _nameControllers[index],
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (val) => val == null || val.isEmpty ? '?' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _scoreControllers[index],
                            keyboardType: const TextInputType.numberWithOptions(signed: true),
                            decoration: InputDecoration(
                              labelText: 'Punkte',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            validator: (val) => val == null || val.isEmpty ? '?' : null,
                          ),
                        ),
                        if (_nameControllers.length > 1) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.close),
                            color: Colors.redAccent,
                            onPressed: () => _removePlayerField(index),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addPlayerField,
                icon: const Icon(Icons.person_add),
                label: const Text('Weiterer Spieler'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: _themeColor.withOpacity(0.5), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notizen (Optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 100), // Platz für FAB
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saveSession,
          backgroundColor: _themeColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.check),
          label: const Text(
            'SPEICHERN',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _scoreControllers) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }
}

// ==========================================
// Verlaufsbildschirm
// ==========================================
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
        title: const Text('Spielverlauf', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Noch keine Spiele gespeichert.',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final s = _sessions[index];

                final pad = (int n) => n.toString().padLeft(2, '0');
                final dateStr = '${pad(s.date.day)}.${pad(s.date.month)}.${s.date.year} • ${pad(s.date.hour)}:${pad(s.date.minute)}';
                final totalScore = s.players.fold<int>(0, (sum, p) => sum + ((p['score'] ?? 0) as int));

                final gameInfo = _getGameInfo(s.gameType);
                final icon = gameInfo['icon'] as String;
                final title = gameInfo['title'] as String;
                final color = gameInfo['color'] as Color;

                return Dismissible(
                  key: ValueKey(s.id ?? s.date.millisecondsSinceEpoch),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Löschen bestätigen'),
                          content: const Text('Möchtest du dieses Spiel wirklich aus dem Verlauf löschen?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Abbrechen'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Löschen', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) async {
                    if (s.id != null) {
                      await DatabaseHelper().deleteSession(s.id!);
                      setState(() {
                        _sessions.removeAt(index);
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Spiel gelöscht.'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shadowColor: color.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: color.withOpacity(0.2), width: 1),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Text(icon, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(dateStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (s.notes != null && s.notes!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.notes, size: 16, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(s.notes!, style: const TextStyle(fontStyle: FontStyle.italic))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          const Text('Spieler & Punkte:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          ...s.players.map((p) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('👤 ${p['name']}', style: const TextStyle(fontSize: 16)),
                                  Text(
                                    '${p['score']}',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Gesamtpunkte:', style: TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                '$totalScore',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Map<String, dynamic> _getGameInfo(String key) {
    final games = GameSelectionScreen.games;
    return games.firstWhere(
      (g) => g['key'] == key,
      orElse: () => {'key': key, 'title': key, 'icon': '🎲', 'color': Colors.grey},
    );
  }
}
