import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:takar/widgets/progress_circle.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_slidable/flutter_slidable.dart';

class ActivitiesPage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const ActivitiesPage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  List<Map<String, dynamic>> _activities = [];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = prefs.getStringList('activities') ?? [];
    
    setState(() {
      _activities = activitiesJson.map((jsonStr) {
        return Map<String, dynamic>.from(json.decode(jsonStr));
      }).toList();
    });
  }

  Future<void> _saveActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final activitiesJson = _activities.map((activity) {
      return json.encode(activity);
    }).toList();
    
    await prefs.setStringList('activities', activitiesJson);
  }

  void _addActivity(String title, [String? duration]) {
    final now = DateTime.now();
    setState(() {
      _activities.add({
        'title': title,
        'duration': duration ?? '',
        'time': _selectedTime != null 
          ? _selectedTime!.format(context) 
          : TimeOfDay.now().format(context),
        'date': _selectedDate != null 
          ? DateFormat('yyyy-MM-dd').format(_selectedDate!) 
          : DateFormat('yyyy-MM-dd').format(now),
        'progress': duration != null ? 0.0 : null,
        'completed': false,
        'isRunning': false,
        'timer': null,
        'isChecked': duration == null ? false : null,
      });
      _saveActivities(); // Save after adding
    });
  }

  void _deleteActivity(int index) {
    setState(() {
      _activities.removeAt(index);
      _saveActivities(); // Save after deleting
    });
  }

  void _updateProgress(int index) {
    final activity = _activities[index];
    final totalDuration = int.parse(activity['duration']) * 60; // Convert minutes to seconds
  
    if (activity['timer'] != null) {
      (activity['timer'] as Timer).cancel();
    }

    activity['timer'] = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (activity['isRunning'] == true && activity['progress'] < 1.0) {
          // Calculate progress based on elapsed time
          activity['progress'] = (timer.tick / totalDuration).clamp(0.0, 1.0);
        
          if (activity['progress'] >= 1.0) {
            timer.cancel();
            activity['completed'] = true;
            activity['isRunning'] = false;
          }
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _editActivity(int index) {
    // Add edit logic here
  }

  void _openAddActivityModal() {
    final titleController = TextEditingController();
    final durationController = TextEditingController();
    final inputFormatter = FilteringTextInputFormatter.digitsOnly;

    // Reset selected date and time
    _selectedDate = null;
    _selectedTime = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add Activity',
                    style: GoogleFonts.vazirmatn(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duration (minutes, optional)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [inputFormatter],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              setModalState(() {
                                _selectedDate = pickedDate;
                              });
                            }
                          },
                          child: Text(_selectedDate != null 
                            ? DateFormat('yyyy-MM-dd').format(_selectedDate!) 
                            : 'Select Date (Optional)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setModalState(() {
                                _selectedTime = pickedTime;
                              });
                            }
                          },
                          child: Text(_selectedTime != null 
                            ? _selectedTime!.format(context) 
                            : 'Select Time (Optional)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (titleController.text.isNotEmpty) {
                        _addActivity(
                          titleController.text, 
                          durationController.text.isNotEmpty ? durationController.text : null
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Add", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.isDarkMode ? Colors.white : Colors.black;
    final cardColor = widget.isDarkMode ? Colors.grey[850] : Colors.white;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Activities",
          style: GoogleFonts.vazirmatn(
            color: themeColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
              color: themeColor,
            ),
          ),
        ],
      ),
      body:
          _activities.isEmpty
              ? Center(
                child: Text(
                  'No activities yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.vazirmatn(
                    fontSize: 16,
                    color: themeColor.withOpacity(0.6),
                  ),
                ),
              )
              : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activities.length,
        itemBuilder: (context, index) {
          final activity = _activities[index];
          return Slidable(
            key: ValueKey(activity['id'] ?? index),
            child: Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  activity['title']!,
                  style: GoogleFonts.vazirmatn(
                    fontWeight: FontWeight.w600,
                    color: themeColor,
                  ),
                ),
                subtitle: Text(
                  activity['duration'] != '' 
                    ? "Duration: ${activity['duration']} min, Date: ${activity['date']}, Time: ${activity['time']}"
                    : "Date: ${activity['date']}, Time: ${activity['time']}",
                  style: TextStyle(
                    color: themeColor.withAlpha((0.7 * 255).toInt()),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (activity['duration'] == '') 
                      Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: activity['isChecked'] ?? false,
                          onChanged: (bool? value) {
                            setState(() {
                              activity['isChecked'] = value ?? false;
                              activity['completed'] = value ?? false;
                            });
                          },
                          shape: const CircleBorder(),
                          checkColor: Colors.white,
                          activeColor: Colors.deepPurple,
                          side: BorderSide(
                            color: themeColor.withOpacity(0.5),
                            width: 1,
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                    else ...[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: IconButton(
                          key: ValueKey(activity['isRunning']),
                          icon: Icon(
                            activity['isRunning']
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: themeColor,
                          ),
                          onPressed: () {
                            setState(() {
                              activity['isRunning'] =
                                  !(activity['isRunning'] ?? false);
                            });
                            if (activity['isRunning']) {
                              _updateProgress(index);
                            } else {
                              // Pause logic
                            }
                          },
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ), // space between icon and progress
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: ProgressCircle(
                          progress: activity['progress'],
                          onComplete: () {
                            setState(() {
                              activity['completed'] = true;
                            });
                          },
                          completedColor: const Color.fromARGB(255, 85, 0, 128),
                          tickSize: 20,
                          isCompleted: activity['completed'] ?? false,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddActivityModal,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
