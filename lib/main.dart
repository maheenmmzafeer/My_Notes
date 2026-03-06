import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() {
  runApp(const NotesApp());
}

/* =========================================================
   APP ROOT
========================================================= */

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notes',

      theme: ThemeData(
        useMaterial3: true,

        scaffoldBackgroundColor: const Color(0xFFFFF0F3),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFB6C1),
          foregroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600),
          elevation: 2,
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFF69B4),
          foregroundColor: Colors.white,
        ),

        cardColor: const Color(0xFFFFD6E7),
      ),

      home: const NotesHomePage(),
    );
  }
}

/* =========================================================
   NOTE MODEL
========================================================= */

class Note {
  String title;
  String body;
  DateTime createdAt;
  Color color;
  double textSize;
  Color textColor;
  bool isPinned;
  bool isDeleted;
  DateTime? deletedAt;

  Note({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.color,
    this.textSize = 16,
    this.textColor = Colors.black,
    this.isPinned = false,
    this.isDeleted = false,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'color': color.value,
        'textSize': textSize,
        'textColor': textColor.value,
        'isPinned': isPinned,
        'isDeleted': isDeleted,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  static Note fromJson(Map<String, dynamic> json) => Note(
        title: json['title'],
        body: json['body'],
        createdAt: DateTime.parse(json['createdAt']),
        color: Color(json['color']),
        textSize: (json['textSize'] as num).toDouble(),
        textColor: Color(json['textColor']),
        isPinned: json['isPinned'] ?? false,
        isDeleted: json['isDeleted'] ?? false,
        deletedAt: json['deletedAt'] != null
            ? DateTime.parse(json['deletedAt'])
            : null,
      );
}

/* =========================================================
   HOME PAGE
========================================================= */

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key});

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  List<Note> _notes = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showDeleted = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  /* =========================================================
     STORAGE
  ========================================================= */

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList('notes') ?? [];

    final now = DateTime.now();

    _notes = notesJson
        .map((e) => Note.fromJson(json.decode(e)))
        .where((note) {
      if (note.isDeleted && note.deletedAt != null) {
        return now.difference(note.deletedAt!).inDays <= 30;
      }
      return true;
    }).toList();

    _sortNotes();
    _saveNotes();
    setState(() {});
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
        'notes',
        _notes.map((e) => json.encode(e.toJson())).toList());
  }

  /* =========================================================
     SORTING
  ========================================================= */

  void _sortNotes() {
    _notes.sort((a, b) {
      if (a.isDeleted && !b.isDeleted) return 1;
      if (!a.isDeleted && b.isDeleted) return -1;

      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      return b.createdAt.compareTo(a.createdAt);
    });
  }

  /* =========================================================
     NOTE ACTIONS
  ========================================================= */

  void _addNote(Note note) {
    _notes.add(note);
    _sortNotes();
    _saveNotes();
    setState(() {});
  }

  void _editNote(Note oldNote, Note newNote) {
    final index = _notes.indexOf(oldNote);

    if (index != -1) {
      _notes[index] = newNote;
      _sortNotes();
      _saveNotes();
      setState(() {});
    }
  }

  void _deleteNote(Note note) {
    final index = _notes.indexOf(note);

    if (index != -1) {
      _notes[index].isDeleted = true;
      _notes[index].deletedAt = DateTime.now();
    }

    _sortNotes();
    _saveNotes();
    setState(() {});
  }

  void _restoreNote(Note note) {
    final index = _notes.indexOf(note);

    if (index != -1) {
      _notes[index].isDeleted = false;
      _notes[index].deletedAt = null;
    }

    _sortNotes();
    _saveNotes();
    setState(() {});
  }

  void _permanentlyDeleteNote(Note note) {
    _notes.remove(note);
    _sortNotes();
    _saveNotes();
    setState(() {});
  }

  /* ⭐ PIN */
  void _togglePin(Note note) {
    final index = _notes.indexOf(note);

    if (index != -1) {
      _notes[index].isPinned = !_notes[index].isPinned;
      _sortNotes();
      _saveNotes();
      setState(() {});
    }
  }

  /* =========================================================
     FILTERS
  ========================================================= */

  List<Note> get _filteredNotes {
    final list = _notes.where((note) => note.isDeleted == _showDeleted);

    if (_searchQuery.isEmpty) return list.toList();

    return list
        .where((note) =>
            note.title.toLowerCase().contains(_searchQuery) ||
            note.body.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _toggleShowDeleted() {
    _showDeleted = !_showDeleted;
    _searchController.clear();
    _searchQuery = '';
    setState(() {});
  }

  /* =========================================================
     PREVIEW POPUP
  ========================================================= */

  void _openPreview(Note note) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: note.color,
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            note.body,
            style: TextStyle(
                fontSize: note.textSize,
                color: note.textColor),
          ),
        ),
        actions: [
          Text(
            DateFormat('MMM d, yyyy • h:mm a')
                .format(note.createdAt),
            style: const TextStyle(fontSize: 12),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  /* =========================================================
     UI BUILD
  ========================================================= */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showDeleted ? 'Recycle Bin' : 'Notes'),

        actions: [
          IconButton(
              icon: Icon(_showDeleted ? Icons.note : Icons.delete),
              onPressed: _toggleShowDeleted),

          if (!_showDeleted)
            SizedBox(
              width: 200,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notes...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            )
        ],
      ),

      body: _filteredNotes.isEmpty
          ? Center(
              child: Text(
                _showDeleted
                    ? 'Recycle Bin is empty'
                    : 'No notes found',
                style: const TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _filteredNotes.length,
              itemBuilder: (_, index) {
                final note = _filteredNotes[index];

                return Card(
                  color: note.color,
                  child: Stack(
                    children: [
                      ListTile(
                        onTap: () => _openPreview(note),

                        title: Text(
                          note.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18), // slightly bigger title
                        ),

                        subtitle: Text(
                          DateFormat('MMM d, yyyy • h:mm a')
                              .format(note.createdAt),
                        ),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (note.isPinned && !_showDeleted)
                              const Icon(Icons.push_pin,
                                  color: Colors.red),

                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (_showDeleted) {
                                  if (value == 'restore')
                                    _restoreNote(note);

                                  if (value == 'delete')
                                    _permanentlyDeleteNote(note);
                                } else {
                                  if (value == 'edit') {
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                NoteEditor(
                                                    note: note,
                                                    onSave: (updated) =>
                                                        _editNote(
                                                            note,
                                                            updated))));
                                  }

                                  if (value == 'delete')
                                    _deleteNote(note);

                                  if (value == 'pin')
                                    _togglePin(note);
                                }
                              },

                              itemBuilder: (_) =>
                                  _showDeleted
                                      ? [
                                          const PopupMenuItem(
                                              value: 'restore',
                                              child: Text('Restore')),
                                          const PopupMenuItem(
                                              value: 'delete',
                                              child: Text(
                                                  'Delete Permanently')),
                                        ]
                                      : [
                                          const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit')),
                                          const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete')),
                                          const PopupMenuItem(
                                              value: 'pin',
                                              child: Text('Pin/Unpin')),
                                        ],
                            )
                          ],
                        ),
                      ),

                     
                    ],
                  ),
                );
              }),

      floatingActionButton: _showDeleted
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            NoteEditor(onSave: (n) => _addNote(n))));
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

/* =========================================================
   NOTE EDITOR
========================================================= */

class NoteEditor extends StatefulWidget {
  final Note? note;
  final Function(Note)? onSave;

  const NoteEditor({super.key, this.note, this.onSave});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late TextEditingController _titleController;
  late TextEditingController _bodyController;

  Color _selectedColor = const Color(0xFFFFD6E7);
  double _textSize = 16;
  Color _textColor = Colors.black;

  @override
  void initState() {
    super.initState();

    _titleController =
        TextEditingController(text: widget.note?.title ?? '');

    _bodyController =
        TextEditingController(text: widget.note?.body ?? '');

    _selectedColor =
        widget.note?.color ?? const Color(0xFFFFD6E7);

    _textSize = widget.note?.textSize ?? 16;
    _textColor = widget.note?.textColor ?? Colors.black;
  }

  void _pickColor({required bool isBackground}) {
    Color pickerColor =
        isBackground ? _selectedColor : _textColor;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Pick ${isBackground ? "Background" : "Text"} Color',
        ),
        content: ColorPicker(
          pickerColor: pickerColor,
          onColorChanged: (c) => pickerColor = c,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () {
                setState(() {
                  if (isBackground) {
                    _selectedColor = pickerColor;
                  } else {
                    _textColor = pickerColor;
                  }
                });

                Navigator.pop(context);
              },
              child: const Text("Select"))
        ],
      ),
    );
  }

  void _changeTextSize(double delta) {
    setState(() {
      _textSize = (_textSize + delta).clamp(8.0, 26.0);
    });
  }

  void _saveNote() {
    final note = Note(
      title: _titleController.text,
      body: _bodyController.text,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      color: _selectedColor,
      textSize: _textSize,
      textColor: _textColor,
      isPinned: widget.note?.isPinned ?? false,
      isDeleted: widget.note?.isDeleted ?? false,
      deletedAt: widget.note?.deletedAt,
    );

    widget.onSave?.call(note);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: _textColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),

        actions: [
          IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote),
        ],
      ),

      body: Container(
        color: _selectedColor,
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            TextField(
              controller: _titleController,
              style: titleStyle,
              decoration: const InputDecoration(
                  hintText: 'Title', border: InputBorder.none),
            ),

            Expanded(
              child: TextField(
                controller: _bodyController,
                expands: true,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                    fontSize: _textSize,
                    color: _textColor),
                decoration: const InputDecoration(
                    hintText: 'Start typing...',
                    border: InputBorder.none),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceEvenly,
                children: [

                  _ControlButton(
                      icon: Icons.color_lens,
                      label: "Bg",
                      onTap: () =>
                          _pickColor(isBackground: true)),

                  _ControlButton(
                      icon: Icons.text_fields,
                      label: "Text",
                      onTap: () =>
                          _pickColor(isBackground: false)),

                  Row(
                    children: [
                      IconButton(
                          onPressed: () =>
                              _changeTextSize(-1),
                          icon: const Icon(
                              Icons.remove_circle_outline)),
                      Text(
                        _textSize.toInt().toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                          onPressed: () =>
                              _changeTextSize(1),
                          icon: const Icon(
                              Icons.add_circle_outline)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   CONTROL BUTTON WIDGET
========================================================= */

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: [
            Icon(icon, size: 22),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}