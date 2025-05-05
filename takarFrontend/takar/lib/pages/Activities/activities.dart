import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
// Assuming progress_circle.dart exists and contains the ProgressCircle widget
import 'package:takar/widgets/progress_circle.dart'; // Make sure this path is correct
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_slidable/flutter_slidable.dart';

// --- Data Model ---
class Activity {
  String id;
  String title;
  String? duration;
  String? time;
  String? date;
  double progress;
  int elapsedSeconds;
  bool completed;
  bool isRunning;
  bool? isChecked;
  Timer? timer; // Transient state, not saved

  Activity({
    required this.id,
    required this.title,
    this.duration,
    this.time,
    this.date,
    this.progress = 0.0,
    this.elapsedSeconds = 0,
    this.completed = false,
    this.isRunning = false, // Transient state, saved to indicate if it *should* be running
    this.isChecked,
    this.timer,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Untitled',
      duration: json['duration'],
      time: json['time'],
      date: json['date'],
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      elapsedSeconds: json['elapsedSeconds'] ?? 0,
      completed: json['completed'] ?? false,
      isRunning: json['isRunning'] ?? false, // Load the saved running state
      isChecked: json['isChecked'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration': duration,
      'time': time,
      'date': date,
      'progress': progress,
      'elapsedSeconds': elapsedSeconds,
      'completed': completed,
      'isRunning': isRunning, // Save the running state
      'isChecked': isChecked,
    };
  }

  bool get isTimed => duration != null && duration!.isNotEmpty;

  int get totalDurationSeconds {
    if (!isTimed) return 0;
    // Ensure duration is a valid number before parsing
    final minutes = int.tryParse(duration!) ?? 0;
    return minutes * 60;
  }
}

// --- Activities Page ---
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
  List<Activity> _activities = [];
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  // To prevent rapid multi-swipes or actions causing issues
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void dispose() {
    // Cancel all timers when the widget is disposed
    for (var activity in _activities) {
      activity.timer?.cancel();
    }
    super.dispose();
  }

  // --- Data Persistence ---
  Future<void> _loadActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = prefs.getStringList('activities') ?? [];
      final loadedActivities = activitiesJson.map((jsonStr) {
        try {
          return Activity.fromJson(
            Map<String, dynamic>.from(json.decode(jsonStr)),
          );
        } catch (e) {
          print("Error decoding activity: $jsonStr, Error: $e");
          return null;
        }
      }).whereType<Activity>().toList();

      // Reset transient timer state and cancel any lingering timers
      for (var activity in loadedActivities) {
        activity.timer?.cancel();
        activity.timer = null;
        // Note: isRunning is loaded from saved state, so we don't reset it here.
      }

      if (mounted) {
        setState(() {
          _activities = loadedActivities;
        });

        // --- Resume Timers for Activities that were running ---
        // Iterate through the activities *after* setting the state
        for (int i = 0; i < _activities.length; i++) {
          final activity = _activities[i];
          // Check if the activity was marked as running AND is timed AND not completed
          if (activity.isRunning && activity.isTimed && !activity.completed) {
            print("Attempting to resume timer for: ${activity.title}");
            // Call _startTimer to resume counting from the saved elapsedSeconds
            _startTimer(i);
          } else {
             // Ensure isRunning is false if it shouldn't be running (e.g., completed)
             activity.isRunning = false;
          }
        }
        // Save state again after potentially updating isRunning flags
        _saveActivities();
      }
    } catch (e) {
      print("Error loading activities: $e");
    }
  }


  Future<void> _saveActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activitiesJson = _activities.map((activity) {
        try {
          // Don't save the transient 'timer' object itself
          return json.encode(activity.toJson());
        } catch (e) {
          print(
            "Error encoding activity: ${activity.title}, Error: $e",
          );
          return null;
        }
      }).whereType<String>().toList();
      await prefs.setStringList('activities', activitiesJson);
      print("Activities saved successfully."); // Debug print
    } catch (e) {
      print("Error saving activities: $e");
    }
  }

  // --- Activity Management ---
  void _addActivity(String title, [String? duration]) {
    print("Add Activity: Starting add process."); // Debug print

    final now = DateTime.now();
    final newActivity = Activity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      duration: duration,
      time: _selectedTime?.format(context) ?? TimeOfDay.now().format(context),
      date: _selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
          : DateFormat('yyyy-MM-dd').format(now),
      isChecked: duration == null || duration.isEmpty ? false : null,
      isRunning: false, // New activities are not running initially
      completed: false, // New activities are not completed initially
      progress: 0.0,
      elapsedSeconds: 0,
    );

    _selectedDate = null;
    _selectedTime = null;

    // Always use AnimatedList's insertItem if the key is available
    if (_listKey.currentState != null) {
      setState(() {
        _activities.insert(0, newActivity);
        print(
          "Add Activity: Item added to _activities list. List size: ${_activities.length}",
        ); // Debug print
      });
      _listKey.currentState!.insertItem(
        0,
        duration: const Duration(milliseconds: 300),
      );
      print("Add Activity: AnimatedList insertItem called."); // Debug print
    } else {
      // Fallback if list key is not available (shouldn't happen in typical flow)
      setState(() {
        _activities.insert(0, newActivity);
        print(
          "Add Activity: Item added to _activities list (fallback). List size: ${_activities.length}",
        ); // Debug print
      });
    }
    _saveActivities();

    Future.delayed(const Duration(milliseconds: 400), () {
      _isActionInProgress = false;
      print("Add Activity: Action flag reset."); // Debug print
    });
  }

  // --- Modified Delete Logic (integrated into swipe and button tap) ---
  void _handleDelete(int index) {
    if (_isActionInProgress) {
      print("Delete: Action in progress, skipping."); // Debug print
      return; // Prevent concurrent actions
    }
    if (index < 0 || index >= _activities.length) {
      print("Delete: Index out of bounds ($index). Aborting."); // Debug print
      return; // Index check
    }

    _isActionInProgress = true; // Mark action as started
    print("Delete: Starting delete process for index $index."); // Debug print

    final removedActivity = _activities[index];
    removedActivity.timer?.cancel(); // Cancel timer first

    // 1. Remove data from the list *within* setState
    setState(() {
      _activities.removeAt(index);
      print(
        "Delete: Item removed from _activities list. List size: ${_activities.length}",
      ); // Debug print
    });

    // 2. Trigger AnimatedList removal animation
    // Pass the *removed* item to the builder and use a placeholder index (-1)
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildActivityItem(
        context,
        removedActivity,
        animation,
        index: -1, // Indicate this is for a removed item animation
      ),
      duration: const Duration(milliseconds: 300),
    );
    print(
      "Delete: AnimatedList removeItem called for index $index.",
    ); // Debug print

    // 3. Save the updated list
    _saveActivities();

    // 4. Show Undo Snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removedActivity.title} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _undoDelete(index, removedActivity);
          },
        ),
        duration: const Duration(seconds: 4), // Slightly longer for undo
      ),
    );

    // Reset flag after a delay (allow animation to settle and snackbar to appear)
    Future.delayed(const Duration(milliseconds: 500), () {
      _isActionInProgress = false;
      print("Delete: Action flag reset."); // Debug print
    });
  }

  void _undoDelete(int index, Activity activity) {
    if (_isActionInProgress) {
      print("Undo Delete: Action in progress, skipping."); // Debug print
      return; // Prevent concurrent actions
    }
    _isActionInProgress = true;
    print(
      "Undo Delete: Starting undo process for index $index.",
    ); // Debug print

    // Check if insertion index is still valid relative to current list size
    if (index < 0 || index > _activities.length) {
      print(
        "Undo Delete: Insertion index out of bounds ($index). Aborting.",
      ); // Debug print
      _isActionInProgress = false;
      return;
    }

    // Reset transient state before re-inserting
    activity.isRunning = false;
    activity.timer
        ?.cancel(); // Ensure timer is cancelled if undo happens mid-run
    activity.timer = null;

    // Always use AnimatedList's insertItem if the key is available
    if (_listKey.currentState != null) {
      setState(() {
        _activities.insert(index, activity);
        print(
          "Undo Delete: Item inserted into _activities list at index $index. List size: ${_activities.length}",
        ); // Debug print
      });
      _listKey.currentState!.insertItem(
        index,
        duration: const Duration(milliseconds: 300),
      );
      print(
        "Undo Delete: AnimatedList insertItem called for index $index.",
      ); // Debug print
    } else {
      // Fallback if list key is not available
      setState(() {
        _activities.insert(index, activity);
        print(
          "Undo Delete: Item inserted into _activities list (fallback) at index $index. List size: ${_activities.length}",
        ); // Debug print
      });
    }
    _saveActivities();

    Future.delayed(const Duration(milliseconds: 400), () {
      _isActionInProgress = false;
      print("Undo Delete: Action flag reset."); // Debug print
    });
  }

  void _toggleTimer(int index) {
    // Removed _isActionInProgress check
    if (index < 0 || index >= _activities.length) {
      print(
        "Toggle Timer: Index out of bounds ($index). Aborting.",
      ); // Debug print
      return; // Index check
    }

    final activity = _activities[index];
    if (!activity.isTimed || activity.completed) return;

    setState(() {
      activity.isRunning = !activity.isRunning;
      if (activity.isRunning) {
        _startTimer(index);
        print("Toggle Timer: Timer started for index $index."); // Debug print
      } else {
        _pauseTimer(index);
        print("Toggle Timer: Timer paused for index $index."); // Debug print
      }
    });
    _saveActivities(); // Save state change
  }

  void _startTimer(int index) {
    if (index < 0 || index >= _activities.length) {
      print(
        "Start Timer: Index out of bounds ($index). Aborting.",
      ); // Debug print
      return; // Index check
    }
    final activity = _activities[index];
    final totalDuration = activity.totalDurationSeconds;
    // Only start if it's a timed activity, not completed, and timer is not already running
    if (!activity.isTimed || activity.completed || activity.timer != null) {
      print(
        "Start Timer: Conditions not met for index $index. isTimed: ${activity.isTimed}, completed: ${activity.completed}, timer != null: ${activity.timer != null}",
      ); // Debug print
      return;
    }

    print("Starting timer for index $index, title: ${activity.title}");

    activity.timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Check if the widget is still mounted and the activity at this index is the same
      // Also check if the activity is still marked as running in the state
      if (!mounted ||
          index >= _activities.length ||
          _activities[index].id != activity.id ||
          !_activities[index].isRunning) {
        print(
          "Start Timer: Timer cancelled due to unmounted widget, invalid index, activity mismatch, or activity no longer running for index $index.",
        ); // Debug print
        timer.cancel();
        // Only set timer to null if it's the *current* activity's timer
        if (index < _activities.length && _activities[index].id == activity.id) {
             _activities[index].timer = null;
        }
        return;
      }

      final currentActivity = _activities[index];

      setState(() {
        currentActivity.elapsedSeconds++;
        currentActivity.progress =
            (currentActivity.elapsedSeconds / totalDuration).clamp(0.0, 1.0);

        if (currentActivity.progress >= 1.0) {
          print(
            "Start Timer: Timer completed for index $index.",
          ); // Debug print
          timer.cancel();
          currentActivity.timer = null;
          currentActivity.completed = true;
          currentActivity.isRunning = false; // Mark as not running when completed
          _saveActivities(); // Save completed state
        }
      });
      // Save progress periodically, but not on every tick to avoid excessive writes
      // Also save when completed
      if (currentActivity.elapsedSeconds % 5 == 0 ||
          currentActivity.completed) {
        _saveActivities();
      }
    });
    print("Start Timer: Timer initialized for index $index."); // Debug print
  }


  void _pauseTimer(int index) {
    if (index < 0 || index >= _activities.length) {
      print(
        "Pause Timer: Index out of bounds ($index). Aborting.",
      ); // Debug print
      return; // Index check
    }
    final activity = _activities[index];
    activity.timer?.cancel();
    activity.timer = null;
    // isRunning is set to false in _toggleTimer
    print("Pause Timer: Timer cancelled for index $index."); // Debug print
    _saveActivities(); // Save paused state
  }

  void _toggleCheckbox(int index, bool? value) {
    if (_isActionInProgress) {
      print("Toggle Checkbox: Action in progress, skipping."); // Debug print
      return; // Prevent concurrent actions
    }
    if (index < 0 || index >= _activities.length) {
      print(
        "Toggle Checkbox: Index out of bounds ($index). Aborting.",
      ); // Debug print
      return; // Index check
    }

    final activity = _activities[index];
    if (activity.isTimed) return; // Only for non-timed activities

    setState(() {
      activity.isChecked = value ?? false;
      activity.completed =
          value ?? false; // Checkbox state determines completion
      print(
        "Toggle Checkbox: Checkbox toggled for index $index. Value: ${activity.isChecked}",
      ); // Debug print
    });
    _saveActivities(); // Save state change
  }

  void _resetActivity(int index) {
    // Removed _isActionInProgress check
    if (index < 0 || index >= _activities.length) {
      print(
        "Reset Activity: Index out of bounds ($index). Aborting.",
      ); // Debug print
      return; // Index check
    }

    final activity = _activities[index];
    if (!activity.isTimed) return; // Only for timed activities

    print(
      "Reset Activity: Starting reset process for index $index.",
    ); // Debug print

    activity.timer?.cancel(); // Cancel any running timer

    setState(() {
      activity.completed = false; // Mark as not completed
      activity.isRunning = false; // Mark as not running
      activity.progress = 0.0; // Reset progress
      activity.elapsedSeconds = 0; // Reset elapsed time
      activity.timer = null; // Clear the timer object
      print("Reset Activity: State reset for index $index."); // Debug print
    });
    _saveActivities(); // Save reset state

    // Removed Future.delayed and _isActionInProgress reset here
  }


  // --- UI: Modals ---
  void _showEditActivityModal(int index) {
    if (_isActionInProgress) {
      print("Edit Modal: Action in progress, skipping."); // Debug print
      return; // Prevent opening modal during another action
    }
    if (index < 0 || index >= _activities.length) {
      print(
        "Edit Modal: Index out of bounds ($index). Aborting.",
      ); // Debug print
      return; // Index check
    }

    _isActionInProgress = true; // Mark action as started
    print("Edit Modal: Showing modal for index $index."); // Debug print

    final activity = _activities[index];
    final titleController = TextEditingController(text: activity.title);
    final durationController = TextEditingController(
      text: activity.duration ?? '',
    );

    DateTime? modalSelectedDate;
    if (activity.date != null && activity.date!.isNotEmpty) {
      try {
        modalSelectedDate = DateFormat('yyyy-MM-dd').parse(activity.date!);
      } catch (e) {
        print("Error parsing date for edit: $e");
      }
    }

    TimeOfDay? modalSelectedTime;
    if (activity.time != null && activity.time!.isNotEmpty) {
      try {
        // Use parseLoose for potentially flexible time formats
        final parsedDateTime = DateFormat.jm().parseLoose(activity.time!);
        modalSelectedTime = TimeOfDay.fromDateTime(parsedDateTime);
      } catch (e) {
        print("Error parsing time for edit: $e");
      }
    }


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Activity',
                      style: GoogleFonts.vazirmatn(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes, optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    // Date and Time Pickers
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              modalSelectedDate != null
                                  ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(modalSelectedDate!)
                                  : 'Select Date',
                            ),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate:
                                    modalSelectedDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (pickedDate != null) {
                                setModalState(() {
                                  modalSelectedDate = pickedDate;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              modalSelectedTime != null
                                  ? modalSelectedTime!.format(context)
                                  : 'Select Time',
                            ),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime:
                                    modalSelectedTime ?? TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                setModalState(() {
                                  modalSelectedTime = pickedTime;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Update Button
                    ElevatedButton(
                      onPressed: () {
                        // Re-check index validity on press just in case
                        if (index < 0 || index >= _activities.length) {
                          print(
                            "Edit modal save: Index out of bounds ($index). Aborting.",
                          ); // Debug print
                          Navigator.pop(context);
                          return;
                        }
                        final currentActivity = _activities[index];
                        if (titleController.text.isNotEmpty) {
                          final updatedDuration =
                              durationController.text.isNotEmpty
                                  ? durationController.text
                                  : null;
                          final bool wasTimed = currentActivity.isTimed;
                          final bool isNowTimed = updatedDuration != null && updatedDuration.isNotEmpty; // Corrected check
                          final newTitle = titleController.text;
                          final newDate =
                              modalSelectedDate != null
                                  ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(modalSelectedDate!)
                                  : currentActivity.date;
                          final newTime =
                              modalSelectedTime != null
                                  ? modalSelectedTime!.format(context)
                                  : currentActivity.time;

                          setState(() {
                            currentActivity.title = newTitle;
                            currentActivity.duration = updatedDuration;
                            currentActivity.date = newDate;
                            currentActivity.time = newTime;

                            // Reset timer/progress state if duration changes or timed status changes
                            // Check if the *parsed* total duration changes
                            final int oldTotalDuration = wasTimed ? (int.tryParse(currentActivity.duration!) ?? 0) * 60 : 0;
                            final int newTotalDuration = isNowTimed ? (int.tryParse(updatedDuration!) ?? 0) * 60 : 0;


                            if (wasTimed != isNowTimed || (isNowTimed && oldTotalDuration != newTotalDuration)) {
                               print("Edit modal save: Duration or timed status changed. Resetting timer state.");
                               currentActivity.timer?.cancel();
                               currentActivity.timer = null;
                               currentActivity.isRunning = false;
                               currentActivity.progress = 0.0;
                               currentActivity.elapsedSeconds = 0;
                               currentActivity.completed = false;
                               currentActivity.isChecked =
                                   isNowTimed
                                       ? null
                                       : false; // Reset checkbox for non-timed
                             } else if (isNowTimed && currentActivity.completed) {
                               // If it was timed and completed, and duration didn't change, keep it completed
                               // No reset needed unless duration changed
                             } else if (!isNowTimed) {
                               // If it's now non-timed, ensure timer state is off and checkbox is managed
                               currentActivity.timer?.cancel();
                               currentActivity.timer = null;
                               currentActivity.isRunning = false;
                               currentActivity.progress = 0.0;
                               currentActivity.elapsedSeconds = 0;
                               currentActivity.completed = currentActivity.isChecked ?? false; // Completion based on checkbox
                             }


                            print(
                              "Edit modal save: Activity updated at index $index.",
                            ); // Debug print
                          });
                          _saveActivities();
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Update Activity"),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Reset flag when modal closes
      _isActionInProgress = false;
      print("Edit Modal: Modal closed, action flag reset."); // Debug print
    });
  }

  void _showAddActivityModal() {
    if (_isActionInProgress) {
      print("Add Modal: Action in progress, skipping."); // Debug print
      return; // Prevent opening during another action (like a swipe animation)
    }

    print("Add Modal: Showing modal."); // Debug print

    final titleController = TextEditingController();
    final durationController = TextEditingController();
    _selectedDate = null;
    _selectedTime = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Activity',
                      style: GoogleFonts.vazirmatn(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes, optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _selectedDate != null
                                  ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(_selectedDate!)
                                  : 'Select Date',
                            ),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2101),
                              );
                              if (pickedDate != null) {
                                setModalState(() {
                                  _selectedDate = pickedDate;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _selectedTime != null
                                  ? _selectedTime!.format(context)
                                  : 'Select Time',
                            ),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime ?? TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                setModalState(() {
                                  _selectedTime = pickedTime;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Add Button
                    ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isNotEmpty) {
                          _addActivity(
                            titleController.text,
                            durationController.text.isNotEmpty
                                ? durationController.text
                                : null,
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
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Add Activity"),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Reset flag when modal closes
      _isActionInProgress =
          false; // Keep this reset here as modal closing is an action completion
      print("Add Modal: Modal closed, action flag reset."); // Debug print
    });
  }

  // --- UI: Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Activities",
          style: GoogleFonts.vazirmatn(
            color:
                theme.appBarTheme.titleTextStyle?.color ??
                theme.colorScheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_round,
              color:
                  theme.appBarTheme.actionsIconTheme?.color ??
                  theme.colorScheme.onSurface,
            ),
            tooltip:
                widget.isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: _activities.isEmpty
          ? Center(
              child: Text(
                'No activities yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: GoogleFonts.vazirmatn(
                  fontSize: 16,
                  color: textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            )
          : AnimatedList(
              key: _listKey,
              initialItemCount: _activities.length,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              itemBuilder: (context, index, animation) {
                // IMPORTANT: Check index bounds *before* accessing _activities
                // If the index is out of bounds, it means the item has been removed
                // from the data list but AnimatedList is still building its exit animation.
                // In this case, we should not try to access _activities[index].
                // The removeItem builder handles passing the removed item's data.
                if (index < 0 || index >= _activities.length) {
                  // This case is handled by removeItem's builder which passes the removed item.
                  // If this builder is somehow called with an invalid index outside of removeItem,
                  // return an empty container to prevent errors.
                  print(
                    "Warning: AnimatedList itemBuilder called with invalid index ($index).",
                  ); // Debug print
                  return const SizedBox.shrink();
                }
                final activity = _activities[index];
                return _buildActivityItem(
                  context,
                  activity,
                  animation,
                  index: index,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddActivityModal,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        tooltip: 'Add Activity',
      ),
    );
  }

  // --- UI: Activity List Item ---
  Widget _buildActivityItem(
    BuildContext context,
    Activity activity,
    Animation<double> animation, {
    required int index,
  }) {
    // Determine if this builder call is for a removal animation.
    // The index passed to removeItem's builder is typically the original index,
    // but we use a placeholder (-1) to distinguish it here.
    // The 'activity' object passed to this builder is the one that was removed
    // when called from removeItem. Otherwise, we get it from the list using the index.
    final bool isRemoving = index < 0;
    // Use the provided activity if removing, otherwise get it from the list
    final Activity activityToShow = isRemoving ? activity : _activities[index];

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cardColor = theme.cardColor;
    final hintColor = theme.hintColor;

    // --- Build Trailing Widget ---
    // This widget will be on the RIGHT side of the ListTile.
    Widget? buildTrailingWidget() {
      // If timed and completed, show the Tick and Reset button on the RIGHT.
      if (activityToShow.isTimed && activityToShow.completed) {
        return Row(
          mainAxisSize: MainAxisSize.min, // Use minimum space
          children: [
            // Purple Tick (now first in the row)
            Icon(
              Icons.check_circle,
              color: Colors.deepPurple,
              size: 28,
            ),
            const SizedBox(width: 8), // Space between tick and reset button
            // Reset Button (now second in the row)
            IconButton(
              icon: const Icon(Icons.refresh),
              color: Colors.deepPurple, // Use deepPurple for the icon
              tooltip: 'Reset Task',
              // Only allow reset if not currently removing and index is valid
              onPressed: isRemoving ||
                      index < 0 ||
                      index >= _activities.length ||
                      _isActionInProgress
                  ? null
                  : () => _resetActivity(index),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
          ],
        );
      }

      // If timed and NOT completed, show Play/Pause and Progress on the RIGHT.
      if (activityToShow.isTimed) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                activityToShow.isRunning
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: Colors.deepPurple,
                size: 28,
              ),
              // Only allow toggle if not currently removing and index is valid
              onPressed: isRemoving ||
                      index < 0 ||
                      index >= _activities.length ||
                      _isActionInProgress
                  ? null
                  : () => _toggleTimer(index),
              tooltip: activityToShow.isRunning ? 'Pause' : 'Start',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              height: 32,
              child: ProgressCircle(
                progress: activityToShow.progress,
                completedColor: Colors.deepPurple.shade300,
                tickSize: 18,
                isCompleted: activityToShow.completed,
                onComplete: () {
                  // You can add logic here if needed when the progress circle completes
                  print(
                    "ProgressCircle completed for activity: ${activityToShow.title}",
                  ); // Debug print
                },
              ),
            ),
          ],
        );
      } else {
        // Non-timed Activity: Show Checkbox on the RIGHT.
        return Transform.scale(
          scale: 1.2,
          child: Checkbox(
            value: activityToShow.isChecked ?? false,
            // Only allow toggle if not currently removing and index is valid
            onChanged: isRemoving ||
                    index < 0 ||
                    index >= _activities.length ||
                    _isActionInProgress
                ? null
                : (bool? value) => _toggleCheckbox(index, value),
            shape: const CircleBorder(),
            checkColor: Colors.white,
            activeColor: Colors.deepPurple,
            side: BorderSide(color: hintColor.withOpacity(0.5), width: 1.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        );
      }
    }

    // --- Build Leading Widget ---
    // This widget will be on the LEFT side of the ListTile.
    Widget? buildLeadingWidget() {
      // No leading widget needed for timed activities with the new layout
      // All relevant icons for timed activities are now in the trailing widget.
      return null;
    }


    // Build the ListTile content
    Widget buildListTileContent() {
      // Use activityToShow here
      return ListTile(
        // Use the leading widget when applicable (will be null for timed activities)
        leading: buildLeadingWidget(),
        // Use the trailing widget when applicable
        trailing: buildTrailingWidget(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          activityToShow.title,
          style: GoogleFonts.vazirmatn(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: textTheme.titleMedium?.color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${activityToShow.date ?? ''}${activityToShow.date != null && activityToShow.time != null ? ' • ' : ''}${activityToShow.time ?? ''}${activityToShow.isTimed ? '\nDuration: ${activityToShow.duration} min' : ''}',
            style: TextStyle(color: hintColor, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    ActionPane buildStartActionPane(
      int index,
      bool isRemoving,
      bool _isActionInProgress,
      Function(int) _showEditActivityModal,
      List<dynamic> _activities,
    ) {
      return ActionPane(
        motion: const BehindMotion(), // Use BehindMotion for background effect
        extentRatio: 0.25, // Limit the swipe extent
        children: [
          // Custom Edit Action Button
          Expanded(
            // Use Expanded to make the button fill the available space in the ActionPane
            child: GestureDetector(
              // Use GestureDetector to handle taps
              onTap: () {
                // Your existing edit logic
                if (!isRemoving &&
                    index >= 0 &&
                    index < _activities.length &&
                    !_isActionInProgress) {
                  _showEditActivityModal(index);
                } else {
                  print(
                    "Edit button: Action aborted, widget removing, index invalid ($index), or action in progress.",
                  ); // Debug print
                }
              },
              child: Container(
                decoration: const BoxDecoration( // Added const
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    topLeft: Radius.circular(16),
                  ), // Rounded corners
                ), // Background color for the action area
                alignment: Alignment.center, // Center the icon
                child: Image.asset(
                  'assets/Icons/Edit_fill.png', // <-- REPLACE with the path to your white edit icon image
                  width: 28, // Adjust icon size as needed
                  height: 28, // Adjust icon size as needed
                  // If your image isn't pre-colored white, you might need to tint it:
                  // color: Colors.white,
                  // colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // End Action Pane (Delete) - Triggered by swiping from right to left
    ActionPane buildEndActionPane(
      int index,
      bool isRemoving,
      bool _isActionInProgress,
      Function(int) _handleDelete,
      List<dynamic> _activities,
    ) {
      return ActionPane(
        motion: const BehindMotion(), // Use BehindMotion for background effect
        extentRatio: 0.25, // Limit the swipe extent
        // Removed dismissible: DismissiblePane(...) to prevent full swipe dismissal
        children: [
          // Custom Delete Action Button
          Expanded(
            // Use Expanded to make the button fill the available space in the ActionPane
            child: GestureDetector(
              // Use GestureDetector to handle taps
              onTap: () {
                // Your existing delete logic
                if (!isRemoving &&
                    index >= 0 &&
                    index < _activities.length &&
                    !_isActionInProgress) {
                  _handleDelete(index);
                } else {
                  print(
                    "Delete button: Action aborted, widget removing, index invalid ($index), or action in progress.",
                  ); // Debug print
                  // Optionally, show a message to the user here
                }
              },
              child: Container(
                decoration: const BoxDecoration( // Added const
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ), // Rounded corners
                ),
                alignment: Alignment.center, // Center the icon
                child: Image.asset(
                  'assets/Icons/delete.png', // <-- REPLACE with the path to your white delete icon image
                  width: 28, // Adjust icon size as needed
                  height: 28, // Adjust icon size as needed
                  // If your image isn't pre-colored white, you might need to tint it:
                  // color: Colors.white,
                  // colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
        child: Slidable(
          // Use the activity's unique ID as the key
          key: ValueKey(activityToShow.id),
          // Pass the index to the ActionPanes and other callbacks
          // Ensure index is valid before passing, although ActionPanes should handle null index gracefully
          startActionPane: buildStartActionPane(
            index,
            isRemoving,
            _isActionInProgress,
            _showEditActivityModal,
            _activities,
          ),
          endActionPane: buildEndActionPane(
            index,
            isRemoving,
            _isActionInProgress,
            _handleDelete,
            _activities,
          ),
          child: buildListTileContent(),
        ),
      ),
    );
  }
}
