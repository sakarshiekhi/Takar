import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ActivitiesPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const ActivitiesPage({
    Key? key,
    required this.isDarkMode,
    required this.onToggleTheme,
  }) : super(key: key);

  @override
  _ActivitiesPageState createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  List<Map<String, dynamic>> _activities = [];
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getString('activities');
    
    setState(() {
      if (activitiesJson != null) {
        try {
          final List<dynamic> savedActivities = json.decode(activitiesJson);
          _activities = savedActivities.map<Map<String, dynamic>>((activity) {
            return {
              'title': activity['title'] ?? 'Unnamed Activity',
              'done': activity['done'] ?? false,
              'timeSpent': activity['timeSpent'] ?? 0,
              'isRunning': activity['isRunning'] ?? false,
              'startTime': activity['startTime'],
              'sessions': activity['sessions'] ?? [],
            };
          }).toList();
        } catch (e) {
          _activities = [];
          print('Error loading activities: $e');
        }
      } else {
        _activities = [];
      }
    });
  }

  Future<void> _saveActivities() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('activities', json.encode(_activities));
  }

  void _addActivity(String title) {
    setState(() {
      _activities.add({
        "title": title,
        "done": false,
        "timeSpent": 0,
        "isRunning": false,
        "startTime": null,
        "sessions": []
      });
      _saveActivities();
    });
  }

  void _startTimer(int index) {
    // Ensure we're not starting an already running timer
    if (_activities[index]['isRunning'] ?? false) return;

    setState(() {
      _activities[index]['isRunning'] = true;
      _activities[index]['startTime'] = DateTime.now().toIso8601String();
      _saveActivities();
    });

    // Cancel any existing timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !((_activities[index]['isRunning'] ?? false))) {
        timer.cancel();
        return;
      }

      setState(() {
        // Calculate the duration since the start time
        final startTime = DateTime.parse(_activities[index]['startTime']);
        final currentDuration = DateTime.now().difference(startTime);
        
        // Update the total time spent
        _activities[index]['timeSpent'] = 
          ((_activities[index]['timeSpent'] as int?) ?? 0) + 1;
        
        // Save activities periodically to prevent data loss
        if (DateTime.now().millisecondsSinceEpoch % 5 == 0) {
          _saveActivities();
        }
      });
    });
  }

  void _pauseTimer(int index) {
    // Ensure we're pausing a running timer
    if (!(_activities[index]['isRunning'] ?? false)) return;

    final activity = _activities[index];
    final startTime = DateTime.parse(activity['startTime']);
    final duration = DateTime.now().difference(startTime);
    
    setState(() {
      // Stop the timer
      activity['isRunning'] = false;
      
      // Add the current session to total time spent
      activity['timeSpent'] = 
        ((activity['timeSpent'] as int?) ?? 0) + duration.inSeconds;
      
      // Record the session
      activity['sessions'].add({
        'start': activity['startTime'],
        'end': DateTime.now().toIso8601String(),
        'duration': duration.inSeconds,
      });
      
      // Clear the start time
      activity['startTime'] = null;
      
      // Save the updated activity
      _saveActivities();
    });

    // Cancel the periodic timer
    _timer?.cancel();
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showAddActivityDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Create New Activity',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter activity name',
            filled: true,
            fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel', 
              style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                _addActivity(title);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditActivityDialog(int index) {
    final controller = TextEditingController(text: _activities[index]['title']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          'Edit Activity',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Activity name',
            filled: true,
            fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel', 
              style: TextStyle(color: widget.isDarkMode ? Colors.white70 : Colors.black54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                setState(() {
                  _activities[index]['title'] = title;
                  _saveActivities();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Activities',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: textColor,
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: _activities.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.list_alt,
                    size: 100,
                    color: textColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No activities yet',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final activity = _activities[index];
                final isRunning = activity['isRunning'] ?? false;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  color: widget.isDarkMode 
                    ? Colors.grey[800] 
                    : Colors.grey[100],
                  child: Dismissible(
                    key: Key(activity['title'] + index.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete Activity', style: TextStyle(color: textColor)),
                          content: Text('Are you sure you want to delete this activity?', style: TextStyle(color: textColor)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      setState(() {
                        _activities.removeAt(index);
                        _saveActivities();
                      });
                    },
                    child: ListTile(
                      title: Text(
                        activity['title'],
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        _formatTime(activity['timeSpent'] ?? 0),
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isRunning ? Icons.pause : Icons.play_arrow,
                              color: isRunning ? Colors.orange : Colors.green,
                            ),
                            onPressed: () => isRunning 
                              ? _pauseTimer(index) 
                              : _startTimer(index),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: textColor.withOpacity(0.7),
                            ),
                            onPressed: () => _showEditActivityDialog(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddActivityDialog,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}