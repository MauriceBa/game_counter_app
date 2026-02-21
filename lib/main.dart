import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

// ==========================================
// Radio Player Setup
// ==========================================
final AudioPlayer radioPlayer = AudioPlayer();

Future<void> initRadioPlayer() async {
  try {
    await radioPlayer.setAudioSource(AudioSource.uri(
      Uri.parse('https://hosting2.studioradiomedia.com:8029/stream.mp3'), // Stream URL for R' Tignes
      tag: MediaItem(
        id: 'tignes_live',
        album: 'R\' La Radiostation',
        title: 'Live Tignes',
        artUri: Uri.parse('https://laradiostation.fr/wp-content/uploads/2021/09/Logo-R-La-Radiostation.png'),
      ),
    ));
  } catch (e) {
    debugPrint("Fehler beim Laden des Radio-Streams: $e");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background audio execution for lock screen widget
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Radio Tignes Playback',
    androidNotificationOngoing: true,
  );
  
  await initRadioPlayer();
  
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardTheme(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardTheme(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        // Wrap everything in a scaffold to provide a persistent bottom radio player
        return Scaffold(
          body: child,
          bottomNavigationBar: const GlobalRadioPlayer(),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const GameSelectionScreen(),
        '/setup': (context) => const PlayerSetupScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}

// ==========================================
// Global Radio Player Widget
// ==========================================
class GlobalRadioPlayer extends StatelessWidget {
  const GlobalRadioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                ],
                image: const DecorationImage(
                  image: NetworkImage('https://laradiostation.fr/wp-content/uploads/2021/09/Logo-R-La-Radiostation.png'),
                  fit: BoxFit.contain,
                )
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('R\' Tignes Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('La Radiostation', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            StreamBuilder<PlayerState>(
              stream: radioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final processingState = playerState?.processingState;
                final playing = playerState?.playing;
                
                if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator()),
                  );
                } else if (playing != true) {
                  return IconButton(
                    icon: const Icon(Icons.play_circle_fill, size: 40),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: radioPlayer.play,
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.pause_circle_filled, size: 40),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: radioPlayer.pause,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// Phase 10 Regeln
// ==========================================
const List<String> phase10Rules = [
  "1. Zwei Drillinge",
  "2. Ein Drilling und eine Viererfolge",
  "3. Ein Vierling und eine Viererfolge",
  "4. Eine Siebenerfolge",
  "5. Eine Achterfolge",
  "6. Eine Neunerfolge",
  "7. Zwei Vierlinge",
  "8. Sieben Karten einer Farbe",
  "9. Ein Fünfling und ein Zwilling",
  "10. Ein Fünfling und ein Drilling"
];

// ==========================================
// Models & Datenbank
// ==========================================
class PlayerState {
  String name;
  int score;
  int phase; // Speziell für Phase 10 (1-10)

  PlayerState({required this.name, this.score = 0, this.phase = 1});

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'phase': phase,
      };

  factory PlayerState.fromJson(Map<String, dynamic> json) => PlayerState(
        name: json['name'],
        score: json['score'] ?? 0,
        phase: json['phase'] ?? 1,
      );
}

class GameSession {
  final int? id;
  final String gameType;
  final DateTime date;
  final List<PlayerState> players;
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
      'players': jsonEncode(players.map((p) => p.toJson()).toList()),
      'notes': notes,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory GameSession.fromMap(Map<String, dynamic> map) {
    final playersList = jsonDecode(map['players']) as List;
    return GameSession(
      id: map['id'],
      gameType: map['game_type'],
      date: DateTime.parse(map['date']),
      players: playersList.map((e) => PlayerState.fromJson(Map<String, dynamic>.from(e))).toList(),
      notes: map['notes'],
    );
  }
}

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
            players TEXT NOT NULL,
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

  Future<int> deleteSession(int id) async {
    final database = await db;
    return await database.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }
}

// ==========================================
// Startseite: Spielauswahl
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
                crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.9,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final game = games[index];
                  final color = game['color'] as Color;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 4,
                    shadowColor: color.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/setup',
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
                            colors: [color.withOpacity(0.05), color.withOpacity(0.2)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(game['icon'] as String, style: const TextStyle(fontSize: 54)),
                            const SizedBox(height: 16),
                            Text(
                              game['title'] as String,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color),
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
// Setup: Spieler hinzufügen
// ==========================================
class PlayerSetupScreen extends StatefulWidget {
  const PlayerSetupScreen({super.key});

  @override
  State<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends State<PlayerSetupScreen> {
  final List<TextEditingController> _nameControllers = [];
  late String _gameType;
  late String _gameTitle;
  late Color _themeColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _gameType = args['gameType'];
    _gameTitle = args['gameTitle'];
    _themeColor = Color(args['color'] ?? Colors.indigo.value);

    if (_nameControllers.isEmpty) {
      _addPlayerField();
      _addPlayerField();
    }
  }

  void _addPlayerField() {
    setState(() => _nameControllers.add(TextEditingController()));
  }

  void _removePlayerField(int index) {
    if (_nameControllers.length > 1) {
      setState(() {
        _nameControllers[index].dispose();
        _nameControllers.removeAt(index);
      });
    }
  }

  void _startGame() {
    final names = _nameControllers.map((c) => c.text.trim()).where((n) => n.isNotEmpty).toList();
    if (names.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte mindestens 2 Spieler eingeben!')));
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveGameScreen(
          gameType: _gameType,
          gameTitle: _gameTitle,
          themeColor: _themeColor,
          playerNames: names,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _themeColor, brightness: Theme.of(context).brightness)),
      child: Scaffold(
        appBar: AppBar(title: Text('$_gameTitle Setup', style: const TextStyle(fontWeight: FontWeight.bold))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Wer spielt mit?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...List.generate(_nameControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _themeColor.withOpacity(0.15),
                      foregroundColor: _themeColor,
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _nameControllers[index],
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Spielername',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    if (_nameControllers.length > 2) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () => _removePlayerField(index),
                      ),
                    ]
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addPlayerField,
              icon: const Icon(Icons.add),
              label: const Text('Weiterer Spieler'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: _themeColor.withOpacity(0.5), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _startGame,
          backgroundColor: _themeColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.play_arrow),
          label: const Text('SPIEL STARTEN', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _nameControllers) { c.dispose(); }
    super.dispose();
  }
}

// ==========================================
// Aktives Spiel: Runden eintragen
// ==========================================
class ActiveGameScreen extends StatefulWidget {
  final String gameType;
  final String gameTitle;
  final Color themeColor;
  final List<String> playerNames;

  const ActiveGameScreen({
    super.key,
    required this.gameType,
    required this.gameTitle,
    required this.themeColor,
    required this.playerNames,
  });

  @override
  State<ActiveGameScreen> createState() => _ActiveGameScreenState();
}

class _ActiveGameScreenState extends State<ActiveGameScreen> {
  late List<PlayerState> players;
  int currentRound = 1;

  @override
  void initState() {
    super.initState();
    players = widget.playerNames.map((name) => PlayerState(name: name)).toList();
  }

  void _showPhase10Rules() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phase 10 - Phasen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: phase10Rules.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(phase10Rules[i], style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel abbrechen?'),
        content: const Text('Der aktuelle Spielfortschritt geht verloren.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Weiter spielen')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abbrechen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return result ?? false;
  }

  void _endGame() async {
    final notesController = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spiel beenden & Speichern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Möchtest du das Spiel jetzt beenden und im Verlauf speichern?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notizen (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, foregroundColor: Colors.white),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (save == true) {
      final session = GameSession(
        gameType: widget.gameType,
        date: DateTime.now(),
        players: players,
        notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
      );
      await DatabaseHelper().insertSession(session.toMap());
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.gameTitle} gespeichert! 🏆')));
      }
    }
  }

  void _addRound() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        if (widget.gameType == 'phase10') {
          return Phase10RoundDialog(
            players: players,
            themeColor: widget.themeColor,
            onSave: (results) {
              setState(() {
                for (int i = 0; i < players.length; i++) {
                  players[i].score += results[i].penalty;
                  if (results[i].completed && players[i].phase < 10) {
                    players[i].phase += 1;
                  }
                }
                currentRound++;
              });
            },
          );
        } else if (widget.gameType == 'wizard') {
          return WizardRoundDialog(
            players: players,
            themeColor: widget.themeColor,
            currentRound: currentRound,
            onSave: (results) {
              setState(() {
                for (int i = 0; i < players.length; i++) {
                  int ansage = results[i].prediction;
                  int stiche = results[i].actual;
                  if (ansage == stiche) {
                    players[i].score += 20 + (stiche * 10);
                  } else {
                    players[i].score -= (ansage - stiche).abs() * 10;
                  }
                }
                currentRound++;
              });
            },
          );
        } else {
          return StandardRoundDialog(
            players: players,
            themeColor: widget.themeColor,
            currentRound: currentRound,
            gameType: widget.gameType,
            onSave: (scores) {
              setState(() {
                for (int i = 0; i < players.length; i++) {
                  players[i].score += scores[i];
                }
                currentRound++;
              });
            },
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<PlayerState> displayPlayers = List.from(players);
    displayPlayers.sort((a, b) {
      if (widget.gameType == 'phase10') {
        if (b.phase != a.phase) return b.phase.compareTo(a.phase);
        return a.score.compareTo(b.score);
      } else if (widget.gameType == 'wizard') {
        return b.score.compareTo(a.score);
      } else {
        return a.score.compareTo(b.score); 
      }
    });

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: widget.themeColor, brightness: Theme.of(context).brightness)),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.gameTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (widget.gameType == 'phase10')
                IconButton(icon: const Icon(Icons.info_outline), onPressed: _showPhase10Rules, tooltip: 'Phasen'),
              IconButton(icon: const Icon(Icons.save), onPressed: _endGame, tooltip: 'Spiel beenden & Speichern'),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Runde $currentRound', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: displayPlayers.length,
                  itemBuilder: (context, index) {
                    final p = displayPlayers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: index == 0 ? widget.themeColor : Colors.transparent, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (index == 0) const Text('👑 ', style: TextStyle(fontSize: 20)),
                                      Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  if (widget.gameType == 'phase10') ...[
                                    const SizedBox(height: 4),
                                    Text('Aktuell: Phase ${p.phase}', style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.w600)),
                                    Text(phase10Rules[p.phase - 1], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  ]
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${p.score}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: widget.themeColor)),
                                Text('Punkte', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addRound,
            backgroundColor: widget.themeColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('RUNDE EINTRAGEN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// Dialog: Phase 10
// ==========================================
class Phase10RoundResult {
  final bool completed;
  final int penalty;
  Phase10RoundResult(this.completed, this.penalty);
}

class Phase10RoundDialog extends StatefulWidget {
  final List<PlayerState> players;
  final Color themeColor;
  final Function(List<Phase10RoundResult>) onSave;

  const Phase10RoundDialog({super.key, required this.players, required this.themeColor, required this.onSave});

  @override
  State<Phase10RoundDialog> createState() => _Phase10RoundDialogState();
}

class _Phase10RoundDialogState extends State<Phase10RoundDialog> {
  late List<bool> completed;
  late List<TextEditingController> penalties;

  @override
  void initState() {
    super.initState();
    completed = List.filled(widget.players.length, false);
    penalties = List.generate(widget.players.length, (_) => TextEditingController());
  }

  void _save() {
    List<Phase10RoundResult> results = [];
    for (int i = 0; i < widget.players.length; i++) {
      int pen = int.tryParse(penalties[i].text) ?? 0;
      results.add(Phase10RoundResult(completed[i], pen));
    }
    widget.onSave(results);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Runde auswerten', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...List.generate(widget.players.length, (index) {
            final p = widget.players[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text('${p.name} (Ph. ${p.phase})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                  Expanded(
                    flex: 2,
                    child: CheckboxListTile(
                      title: const Text('Geschafft', style: TextStyle(fontSize: 12)),
                      value: completed[index],
                      activeColor: widget.themeColor,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) => setState(() => completed[index] = val ?? false),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: penalties[index],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Strafpunkte',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
              child: const Text('RUNDE SPEICHERN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ==========================================
// Dialog: Wizard
// ==========================================
class WizardRoundResult {
  final int prediction;
  final int actual;
  WizardRoundResult(this.prediction, this.actual);
}

class WizardRoundDialog extends StatefulWidget {
  final List<PlayerState> players;
  final Color themeColor;
  final int currentRound;
  final Function(List<WizardRoundResult>) onSave;

  const WizardRoundDialog({super.key, required this.players, required this.themeColor, required this.currentRound, required this.onSave});

  @override
  State<WizardRoundDialog> createState() => _WizardRoundDialogState();
}

class _WizardRoundDialogState extends State<WizardRoundDialog> {
  late List<TextEditingController> predictions;
  late List<TextEditingController> actuals;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    predictions = List.generate(widget.players.length, (_) => TextEditingController());
    actuals = List.generate(widget.players.length, (_) => TextEditingController());
  }

  void _save() {
    int totalActual = 0;
    List<WizardRoundResult> results = [];
    
    for (int i = 0; i < widget.players.length; i++) {
      int pred = int.tryParse(predictions[i].text) ?? 0;
      int act = int.tryParse(actuals[i].text) ?? 0;
      totalActual += act;
      results.add(WizardRoundResult(pred, act));
    }

    if (totalActual != widget.currentRound) {
      setState(() {
        errorMsg = 'Achtung: Die Summe der Stiche ($totalActual) muss der Runde (${widget.currentRound}) entsprechen!';
      });
      return;
    }

    widget.onSave(results);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Runde ${widget.currentRound} eintragen', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...List.generate(widget.players.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(widget.players[index].name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: predictions[index],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Ansage',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: actuals[index],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Stiche',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (errorMsg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(errorMsg!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
              child: const Text('RUNDE SPEICHERN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ==========================================
// Dialog: Standard (Uno, Rummikub)
// ==========================================
class StandardRoundDialog extends StatefulWidget {
  final List<PlayerState> players;
  final Color themeColor;
  final int currentRound;
  final String gameType;
  final Function(List<int>) onSave;

  const StandardRoundDialog({super.key, required this.players, required this.themeColor, required this.currentRound, required this.gameType, required this.onSave});

  @override
  State<StandardRoundDialog> createState() => _StandardRoundDialogState();
}

class _StandardRoundDialogState extends State<StandardRoundDialog> {
  late List<TextEditingController> points;

  @override
  void initState() {
    super.initState();
    points = List.generate(widget.players.length, (_) => TextEditingController());
  }

  void _save() {
    List<int> results = [];
    for (int i = 0; i < widget.players.length; i++) {
      results.add(int.tryParse(points[i].text) ?? 0);
    }
    widget.onSave(results);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String hint = widget.gameType == 'rumikub' ? 'Minuspunkte eintragen (Gewinner leer lassen oder positiv berechnen)' : 'Punkte diese Runde';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Punkte eintragen (Runde ${widget.currentRound})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(hint, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ),
          ...List.generate(widget.players.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(widget.players[index].name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: points[index],
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      decoration: InputDecoration(
                        labelText: 'Punkte (+/-)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
              child: const Text('RUNDE SPEICHERN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
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
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSessions, tooltip: 'Aktualisieren')],
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Noch keine Spiele gespeichert.', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
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

                final gameInfo = _getGameInfo(s.gameType);
                final icon = gameInfo['icon'] as String;
                final title = gameInfo['title'] as String;
                final color = gameInfo['color'] as Color;

                return Dismissible(
                  key: ValueKey(s.id ?? s.date.millisecondsSinceEpoch),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white, size: 28),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Löschen bestätigen'),
                        content: const Text('Möchtest du dieses Spiel wirklich löschen?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Abbrechen')),
                          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Löschen', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) async {
                    if (s.id != null) {
                      await DatabaseHelper().deleteSession(s.id!);
                      setState(() => _sessions.removeAt(index));
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shadowColor: color.withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color.withOpacity(0.2), width: 1)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Text(icon, style: const TextStyle(fontSize: 20))),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(dateStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          if (s.notes != null && s.notes!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
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
                          const Align(alignment: Alignment.centerLeft, child: Text('Endstand:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          const SizedBox(height: 8),
                          ...s.players.map((p) {
                            String extra = '';
                            if (s.gameType == 'phase10') extra = ' (Phase ${p.phase})';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('👤 ${p.name}$extra', style: const TextStyle(fontSize: 16)),
                                  Text('${p.score}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                                ],
                              ),
                            );
                          }),
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
    return games.firstWhere((g) => g['key'] == key, orElse: () => {'key': key, 'title': key, 'icon': '🎲', 'color': Colors.grey});
  }
}
