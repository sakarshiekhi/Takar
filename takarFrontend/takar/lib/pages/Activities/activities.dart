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
  String? duration; // Effective duration (can be calculated from sub-tasks)
  String? initialDuration; // Original duration set by the user for parent tasks
  String? time;
  String? date;
  double progress;
  int elapsedSeconds;
  bool completed;
  bool isRunning;
  bool? isChecked;
  String? description; // Added description field
  List<Activity>? subTasks; // Added subTasks list
  String? parentId; // Added parentId to link sub-tasks to parent tasks

  // Transient state (not saved)
  Timer? timer;
  bool isExpanded; // Added transient state for sub-task section expansion

  Activity({
    required this.id,
    required this.title,
    this.duration,
    this.initialDuration, // Initialize initialDuration
    this.time,
    this.date,
    this.progress = 0.0,
    this.elapsedSeconds = 0,
    this.completed = false,
    this.isRunning = false, // Transient state, saved to indicate if it *should* be running
    this.isChecked,
    this.description, // Initialize description
    this.subTasks, // Initialize subTasks
    this.parentId, // Initialize parentId
    this.timer, // Timer is not serialized
    this.isExpanded = false, // Initialize isExpanded (transient)
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    // Decode subTasks if they exist
    var subTasksList = json['subTasks'] as List?;
    List<Activity>? decodedSubTasks = subTasksList
        ?.map((item) => Activity.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return Activity(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] ?? 'Untitled',
      duration: json['duration'],
      initialDuration: json['initialDuration'], // Decode initialDuration
      time: json['time'],
      date: json['date'],
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      elapsedSeconds: json['elapsedSeconds'] ?? 0,
      completed: json['completed'] ?? false,
      isRunning: json['isRunning'] ?? false, // Load the saved running state
      isChecked: json['isChecked'],
      description: json['description'], // Decode description
      subTasks: decodedSubTasks, // Assign decoded subTasks
      parentId: json['parentId'], // Decode parentId
       // Timer and isExpanded are not loaded from JSON
    );
  }

  Map<String, dynamic> toJson() {
    // Encode subTasks if they exist
    var subTasksJsonList = subTasks?.map((task) => task.toJson()).toList();

    return {
      'id': id,
      'title': title,
      'duration': duration,
      'initialDuration': initialDuration, // Encode initialDuration
      'time': time,
      'date': date,
      'progress': progress,
      'elapsedSeconds': elapsedSeconds,
      'completed': completed,
      'isRunning': isRunning, // Save the running state
      'isChecked': isChecked,
      'description': description, // Encode description
      'subTasks': subTasksJsonList, // Encode subTasks
      'parentId': parentId, // Encode parentId
    };
  }

  bool get isTimed => duration != null && duration!.isNotEmpty;

  int get totalDurationSeconds {
    if (!isTimed) {
      // If the parent is not timed, calculate duration from timed sub-tasks
      final calculated = calculatedDurationSeconds;
      return calculated > 0 ? calculated : 0;
    }
    // If the parent is timed, use its own duration, but compare with calculated
    final initialMinutes = int.tryParse(duration!) ?? 0;
    final initialSeconds = initialMinutes * 60;
    final calculated = calculatedDurationSeconds;

    // If calculated duration is greater than initial, use calculated
    return calculated > initialSeconds ? calculated : initialSeconds;
  }

  // Calculate the total duration from timed sub-tasks
  int get calculatedDurationSeconds {
      if (subTasks == null || subTasks!.isEmpty) return 0;
      int total = 0;
      for (var subTask in subTasks!) {
          if (subTask.isTimed) {
              total += subTask.totalDurationSeconds;
          }
      }
      return total;
  }


  // Helper to check if all direct subtasks are completed
  bool get areAllDirectSubTasksCompleted {
    if (subTasks == null || subTasks!.isEmpty) {
      return false; // A task with no subtasks isn't completed by subtasks
    }
    return subTasks!.every((subTask) => subTask.completed);
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

  // Controllers for the inline sub-task input fields
  final TextEditingController _subTaskTitleController = TextEditingController();
  final TextEditingController _subTaskDurationController = TextEditingController();
  final TextEditingController _subTaskDescriptionController = TextEditingController(); // Controller for inline description

  // State for inline sub-task input visibility
  bool _isAddingTimedSubTask = false;
  bool _isAddingDescribedSubTask = false;


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
      // Recursively cancel timers in subtasks
      if (activity.subTasks != null) {
        for (var subTask in activity.subTasks!) {
          subTask.timer?.cancel();
        }
      }
    }
    // Dispose controllers
    _subTaskTitleController.dispose();
    _subTaskDurationController.dispose();
    _subTaskDescriptionController.dispose();
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
        activity.isExpanded = false; // Reset expanded state on load
        // Note: isRunning is loaded from saved state, so we don't reset it here.
        // Also reset timers for subtasks recursively
        if (activity.subTasks != null) {
           for (var subTask in activity.subTasks!) {
             subTask.timer?.cancel();
             subTask.timer = null;
             subTask.isExpanded = false; // Reset expanded state for subtasks
             // subTask.isRunning state will be loaded from JSON
           }
        }
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
          }
          // Add logic here to resume subtask timers if implemented later
          // This would require finding the subtask within the main list structure
          // and calling _startTimer on it.
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
          // Don't save the transient 'timer' or 'isExpanded' objects themselves
          // The toJson method now handles subtasks and parentId
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
  void _addActivity(String title, [String? duration, String? description, String? parentId]) {
    print("Add Activity: Starting add process."); // Debug print

    final now = DateTime.now();
    final newActivity = Activity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      duration: duration,
      initialDuration: duration, // Set initial duration on creation
      time: _selectedTime?.format(context) ?? TimeOfDay.now().format(context),
      date: _selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
          : DateFormat('yyyy-MM-dd').format(now),
      isChecked: duration == null || duration.isEmpty ? false : null,
      isRunning: false, // New activities are not running initially
      completed: false, // New activities are not completed initially
      progress: 0.0,
      elapsedSeconds: 0,
      description: description, // Assign description
      subTasks: parentId == null ? [] : null, // Initialize subTasks list for parent, null for subtask
      parentId: parentId, // Assign parentId
      isExpanded: false, // New activities are not expanded initially
    );

    _selectedDate = null;
    _selectedTime = null;

    setState(() {
      if (parentId == null) {
        // Add as a top-level activity
        _activities.insert(0, newActivity);
         if (_listKey.currentState != null) {
            _listKey.currentState!.insertItem(
              0,
              duration: const Duration(milliseconds: 300),
            );
          }
        print(
          "Add Activity: Top-level item added. List size: ${_activities.length}",
        ); // Debug print
      } else {
        // Find the parent and add as a sub-task
        final parentIndex = _activities.indexWhere((activity) => activity.id == parentId);
        if (parentIndex != -1) {
          // Ensure subTasks list exists for the parent
          _activities[parentIndex].subTasks ??= [];
          _activities[parentIndex].subTasks!.add(newActivity);

          // Update parent duration based on new timed sub-task
          if (newActivity.isTimed) {
              _updateParentDuration(_activities[parentIndex]);
          }

           // Note: AnimatedList doesn't directly support nested inserts,
           // so sub-tasks won't have animated insertion without more complex logic.
          print(
            "Add Activity: Sub-task added to parent at index $parentIndex. Sub-task count: ${_activities[parentIndex].subTasks!.length}",
          ); // Debug print
        } else {
          print("Add Activity: Parent with ID $parentId not found. Adding as top-level.");
          _activities.insert(0, newActivity);
           if (_listKey.currentState != null) {
              _listKey.currentState!.insertItem(
                0,
                duration: const Duration(milliseconds: 300),
              );
            }
        }
      }
    });

    _saveActivities();

    Future.delayed(const Duration(milliseconds: 400), () {
      _isActionInProgress = false;
      print("Add Activity: Action flag reset."); // Debug print
    });
  }

   // Helper to find an activity (including sub-tasks) by ID
   Activity? _findActivityById(String id, List<Activity> activitiesList) {
     for (var activity in activitiesList) {
       if (activity.id == id) {
         return activity;
       }
       if (activity.subTasks != null) {
         final foundSubTask = _findActivityById(id, activity.subTasks!);
         if (foundSubTask != null) {
           return foundSubTask;
         }
       }
     }
     return null;
   }

    // Helper to find the index of an activity (top-level only for AnimatedList)
   int _findActivityIndex(String id) {
     return _activities.indexWhere((activity) => activity.id == id);
   }

   // Update parent's duration based on its sub-tasks
   void _updateParentDuration(Activity parent) {
       if (parent.subTasks == null) return;

       final int calculatedTotalSeconds = parent.calculatedDurationSeconds;
       final int initialTotalSeconds = (int.tryParse(parent.initialDuration ?? '') ?? 0) * 60;

       setState(() {
           if (calculatedTotalSeconds > 0) {
               // If there are timed sub-tasks, the parent becomes timed
               // Use the greater of the initial duration or the calculated duration
               final effectiveSeconds = calculatedTotalSeconds > initialTotalSeconds
                   ? calculatedTotalSeconds
                   : initialTotalSeconds;
               parent.duration = (effectiveSeconds ~/ 60).toString();

               // Notify user if calculated duration exceeds initial duration
               if (calculatedTotalSeconds > initialTotalSeconds && initialTotalSeconds > 0) {
                   // Show a subtle notification
                   ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(
                           content: Text('${parent.title} duration updated to ${parent.duration} min based on sub-tasks.'),
                           duration: const Duration(seconds: 2),
                       ),
                   );
               }
           } else if (initialTotalSeconds > 0) {
               // If no timed sub-tasks but had an initial duration, revert to initial
               parent.duration = (initialTotalSeconds ~/ 60).toString();
           } else {
               // If no timed sub-tasks and no initial duration, parent is not timed
               parent.duration = null;
           }
       });
       _saveActivities();
   }


  // --- Modified Delete Logic (integrated into swipe and button tap) ---
  void _handleDelete(String activityId) {
    if (_isActionInProgress) {
      print("Delete: Action in progress, skipping."); // Debug print
      return; // Prevent concurrent actions
    }

    _isActionInProgress = true; // Mark action as started
    print("Delete: Starting delete process for activity ID $activityId."); // Debug print

    // Find the activity to be removed
    Activity? activityToRemove;
    int topLevelIndex = -1;
    Activity? parentActivity;

    // Check top-level activities first
    topLevelIndex = _activities.indexWhere((activity) => activity.id == activityId);
    if (topLevelIndex != -1) {
      activityToRemove = _activities[topLevelIndex];
    } else {
      // Check sub-tasks
      for (var activity in _activities) {
        if (activity.subTasks != null) {
           final subTaskIndex = activity.subTasks!.indexWhere((sub) => sub.id == activityId);
           if (subTaskIndex != -1) {
             activityToRemove = activity.subTasks![subTaskIndex];
             parentActivity = activity; // Found the parent
             break; // Found the sub-task, no need to continue searching
           }
        }
      }
    }


    if (activityToRemove == null) {
      print("Delete: Activity with ID $activityId not found. Aborting."); // Debug print
      _isActionInProgress = false;
      return; // Activity not found
    }

    activityToRemove.timer?.cancel(); // Cancel timer first
    // Recursively cancel timers in subtasks if implemented later
    if (activityToRemove.subTasks != null) {
      for (var subTask in activityToRemove.subTasks!) {
        subTask.timer?.cancel();
      }
    }


    setState(() {
      if (parentActivity != null) {
        // Remove sub-task from parent's subTasks list
        parentActivity.subTasks!.removeWhere((sub) => sub.id == activityId);
        print(
          "Delete: Sub-task removed from parent ${parentActivity.title}. Remaining sub-task count: ${parentActivity.subTasks!.length}",
        ); // Debug print

        // Update parent duration if the deleted task was timed
        if (activityToRemove != null && activityToRemove.isTimed) {
            _updateParentDuration(parentActivity);
        }

        // Check if parent is now completed after removing a sub-task (if it was a sub-task completing the parent)
         _checkAndCompleteParent(parentActivity.id);

      } else if (topLevelIndex != -1) {
        // Remove top-level activity from the main list
        _activities.removeAt(topLevelIndex);
        print(
          "Delete: Top-level item removed from _activities list. List size: ${_activities.length}",
        ); // Debug print

        // Trigger AnimatedList removal animation for top-level items
         _listKey.currentState?.removeItem(
            topLevelIndex,
            (context, animation) => _buildActivityItem(
              context,
              activityToRemove!, // Pass the removed item for animation
              animation,
              index: -1, // Indicate this is for a removed item animation
            ),
            duration: const Duration(milliseconds: 300),
          );
         print(
           "Delete: AnimatedList removeItem called for index $topLevelIndex.",
         ); // Debug print
      }
    });

    // 3. Save the updated list
    _saveActivities();
    _isActionInProgress = false; // Reset flag after saving

    // 4. Show Undo Snackbar (only for top-level removals for now due to complexity with sub-tasks)
    if (parentActivity == null) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('${activityToRemove.title} deleted'),
           action: SnackBarAction(
             label: 'Undo',
             onPressed: () {
               _undoDelete(topLevelIndex, activityToRemove!);
             },
           ),
           duration: const Duration(seconds: 4), // Slightly longer for undo
         ),
       );
    }

     print("Delete: Action flag reset."); // Debug print
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
    activity.isExpanded = false; // Reset expanded state on undo
    // Reset timers for subtasks recursively if implemented later
    if (activity.subTasks != null) {
      for (var subTask in activity.subTasks!) {
        subTask.timer?.cancel();
        subTask.timer = null;
        subTask.isExpanded = false; // Reset expanded state for subtasks on undo
      }
    }


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

  void _toggleTimer(String activityId) {
    // Removed _isActionInProgress check
     final activity = _findActivityById(activityId, _activities);

    if (activity == null || !activity.isTimed || activity.completed) {
       print("Toggle Timer: Activity ID $activityId not found, not timed, or completed. Aborting.");
       return;
    }


    setState(() {
      activity.isRunning = !activity.isRunning;
      if (activity.isRunning) {
        // Need to find the actual index to start the timer correctly if it's a top-level task
        // For sub-tasks, timer management needs to be handled within the sub-task context.
        final topLevelIndex = _findActivityIndex(activityId);
        if (topLevelIndex != -1) {
           _startTimer(topLevelIndex);
           print("Toggle Timer: Timer started for top-level index $topLevelIndex."); // Debug print
        } else {
           // Handle starting timer for sub-tasks if implemented later
           print("Toggle Timer: Attempted to start timer for sub-task ID $activityId. Sub-task timer not fully implemented.");
        }
      } else {
         activity.timer?.cancel();
         activity.timer = null;
        print("Toggle Timer: Timer paused for activity ID $activityId."); // Debug print
      }
    });
    _saveActivities(); // Save state change
  }

  // Note: _startTimer currently only works for top-level activities due to AnimatedList index dependency.
  // Implementing for sub-tasks requires finding the sub-task within the nested structure.
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
          // Check if completing this task completes a parent task
          if (currentActivity.parentId != null) {
             _checkAndCompleteParent(currentActivity.parentId!);
          } else {
             // If a parent task completes via timer, complete its sub-tasks
             _completeSubTasks(currentActivity);
          }
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

  // Helper function to check if a parent task should be completed
  void _checkAndCompleteParent(String parentId) {
      final parentActivity = _findActivityById(parentId, _activities);
      if (parentActivity != null && parentActivity.subTasks != null) {
          if (parentActivity.areAllDirectSubTasksCompleted && !parentActivity.completed) {
              setState(() {
                  parentActivity.completed = true;
                  // If the parent is non-timed, also check its checkbox
                  if (!parentActivity.isTimed) {
                      parentActivity.isChecked = true;
                  }
                  print("Parent task ${parentActivity.title} automatically completed.");
              });
              _saveActivities();
              // Recursively check if completing this parent completes its parent
              if (parentActivity.parentId != null) {
                  _checkAndCompleteParent(parentActivity.parentId!);
              }
          }
      }
  }

  // Helper function to complete all direct sub-tasks of a parent
  void _completeSubTasks(Activity parent) {
    if (parent.subTasks == null) return;
    setState(() {
      for (var subTask in parent.subTasks!) {
        if (!subTask.completed) {
          subTask.completed = true;
          subTask.isRunning = false;
          subTask.timer?.cancel();
          subTask.timer = null;
          subTask.progress = 1.0;
          if (!subTask.isTimed) {
            subTask.isChecked = true;
          }
          print("Sub-task ${subTask.title} completed by parent.");
        }
      }
    });
    _saveActivities();
  }

  // Helper function to complete all direct sub-tasks of a parent with animation
  void _animateSubTaskCompletion(Activity parent) async {
      if (parent.subTasks == null || parent.subTasks!.isEmpty) return;

      // Set action in progress to prevent other actions during animation
      _isActionInProgress = true;
      print("Starting sub-task completion animation for parent: ${parent.title}");

      for (int i = 0; i < parent.subTasks!.length; i++) {
          final subTask = parent.subTasks![i];
          // Add a delay for the animation effect
          await Future.delayed(const Duration(milliseconds: 100));

          // Check if the parent is still completed and the sub-task is not already completed
          // This handles cases where the parent might be unchecked during the animation
          if (parent.completed && !subTask.completed) {
               setState(() {
                   subTask.completed = true;
                   subTask.isRunning = false; // Stop timer if running
                   subTask.timer?.cancel();
                   subTask.timer = null;
                   subTask.progress = 1.0; // Mark progress as complete for timed
                   if (!subTask.isTimed) {
                       subTask.isChecked = true; // Check checkbox for non-timed
                   }
                   print("Sub-task ${subTask.title} animated completion.");
               });
               _saveActivities(); // Save state after each step
          }
      }

      // Reset action in progress after the animation completes
      _isActionInProgress = false;
      print("Sub-task completion animation finished.");
  }


  void _pauseTimer(String activityId) {
     final activity = _findActivityById(activityId, _activities);
     if (activity == null) {
       print("Pause Timer: Activity ID $activityId not found. Aborting.");
       return;
     }
    activity.timer?.cancel();
    activity.timer = null;
    // isRunning is set to false in _toggleTimer
    print("Pause Timer: Timer paused for activity ID $activityId."); // Debug print
    _saveActivities(); // Save paused state
  }

  void _toggleCheckbox(String activityId, bool? value) {
    if (_isActionInProgress) {
      print("Toggle Checkbox: Action in progress, skipping."); // Debug print
      return; // Prevent concurrent actions
    }

    final activity = _findActivityById(activityId, _activities);

    if (activity == null || activity.isTimed) {
       print("Toggle Checkbox: Activity ID $activityId not found or is timed. Aborting.");
       return; // Only for non-timed activities
    }

    setState(() {
      activity.isChecked = value ?? false;
      activity.completed =
          value ?? false; // Checkbox state determines completion
      print(
        "Toggle Checkbox: Checkbox toggled for activity ID $activityId. Value: ${activity.isChecked}",
      ); // Debug print

      // Check if completing this task completes a parent task
      if (activity.parentId != null) {
         _checkAndCompleteParent(activity.parentId!);
      } else {
         // If a parent task is checked, complete its sub-tasks with animation
         if (activity.completed) {
             _animateSubTaskCompletion(activity); // Call the animation function
         } else {
             // If a parent task is unchecked, un-complete its sub-tasks immediately
             _uncompleteSubTasks(activity);
         }
      }
    });
    _saveActivities(); // Save state change
  }

  // Helper function to un-complete all direct sub-tasks of a parent
  void _uncompleteSubTasks(Activity parent) {
      if (parent.subTasks == null) return;
      setState(() {
          for (var subTask in parent.subTasks!) {
              if (subTask.completed) {
                  subTask.completed = false;
                  subTask.isRunning = false; // Ensure timer is off
                  subTask.timer?.cancel();
                  subTask.timer = null;
                  subTask.progress = 0.0; // Reset progress for timed
                  if (!subTask.isTimed) {
                      subTask.isChecked = false; // Uncheck checkbox for non-timed
                  }
                  print("Sub-task ${subTask.title} un-completed by parent.");
              }
          }
      });
      _saveActivities();
  }


  void _resetActivity(String activityId) {
    // Removed _isActionInProgress check
    final activity = _findActivityById(activityId, _activities);

    if (activity == null || !activity.isTimed) {
       print("Reset Activity: Activity ID $activityId not found or is not timed. Aborting.");
       return; // Only for timed activities
    }

    print(
      "Reset Activity: Starting reset process for activity ID $activityId.",
    ); // Debug print

    activity.timer?.cancel(); // Cancel any running timer

    setState(() {
      activity.completed = false; // Mark as not completed
      activity.isRunning = false; // Mark as not running
      activity.progress = 0.0; // Reset progress
      activity.elapsedSeconds = 0; // Reset elapsed time
      activity.timer = null; // Clear the timer object
      // If this was a sub-task, un-complete its parent and update parent duration
      if (activity.parentId != null) {
          _uncompleteParent(activity.parentId!);
          final parent = _findActivityById(activity.parentId!, _activities);
          if (parent != null) {
              _updateParentDuration(parent);
          }
      } else {
          // If a parent task is reset, un-complete its sub-tasks
          _uncompleteSubTasks(activity);
          // Recalculate parent duration based on sub-tasks after reset
          _updateParentDuration(activity);
      }
      print("Reset Activity: State reset for activity ID $activityId."); // Debug print
    });
    _saveActivities(); // Save reset state

    // Removed Future.delayed and _isActionInProgress reset here
  }

   // Helper function to un-complete a parent task if a sub-task is reset
   void _uncompleteParent(String parentId) {
       final parentActivity = _findActivityById(parentId, _activities);
       if (parentActivity != null && parentActivity.completed) {
           setState(() {
               parentActivity.completed = false;
               if (!parentActivity.isTimed) {
                   parentActivity.isChecked = false;
               }
               print("Parent task ${parentActivity.title} un-completed due to sub-task reset.");
           });
           _saveActivities();
           // Recursively un-complete parent's parent if needed
           if (parentActivity.parentId != null) {
               _uncompleteParent(parentActivity.parentId!);
           }
       }
   }


  // --- UI: Modals ---
  void _showEditActivityModal(String activityId) {
    if (_isActionInProgress) {
      print("Edit Modal: Action in progress, skipping."); // Debug print
      return; // Prevent opening modal during another action
    }

    _isActionInProgress = true; // Mark action as started
    print("Edit Modal: Showing modal for activity ID $activityId."); // Debug print

    final activity = _findActivityById(activityId, _activities);

    if (activity == null) {
       print("Edit Modal: Activity with ID $activityId not found. Aborting.");
       _isActionInProgress = false;
       return;
    }

    final titleController = TextEditingController(text: activity.title);
    final durationController = TextEditingController(
      text: activity.duration ?? '',
    );
    final descriptionController = TextEditingController( // Controller for description
      text: activity.description ?? '',
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
                     const SizedBox(height: 12), // Added space
                    TextField( // Added description field
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3, // Allow multiple lines for description
                      keyboardType: TextInputType.multiline,
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
                     // Removed "Add Sub-task" button from here

                    // Update Button
                    ElevatedButton(
                      onPressed: () {
                        // Re-check index validity on press just in case
                         // Find the activity again as it might have been modified in the list
                        final currentActivity = _findActivityById(activityId, _activities);
                        if (currentActivity == null) {
                           print("Edit modal save: Activity with ID $activityId not found. Aborting.");
                           Navigator.pop(context);
                           return;
                        }

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
                          final newDescription = descriptionController.text.isNotEmpty
                              ? descriptionController.text
                              : null;

                          // Store the old duration to calculate the change for parent
                          final String? oldDuration = currentActivity.duration;


                          setState(() {
                            currentActivity.title = newTitle;
                            currentActivity.duration = updatedDuration;
                            // If it's a top-level task and duration is changed, update initialDuration
                            if (currentActivity.parentId == null) {
                                currentActivity.initialDuration = updatedDuration;
                            }
                            currentActivity.date = newDate;
                            currentActivity.time = newTime;
                            currentActivity.description = newDescription; // Update description

                            // Reset timer/progress state if duration changes or timed status changes
                            // Check if the *parsed* total duration changes
                            final int oldTotalDuration = wasTimed ? (int.tryParse(oldDuration ?? '') ?? 0) * 60 : 0;
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

                             // If this is a sub-task and its duration changed, update the parent
                             if (currentActivity.parentId != null && (wasTimed != isNowTimed || oldTotalDuration != newTotalDuration)) {
                                 final parent = _findActivityById(currentActivity.parentId!, _activities);
                                 if (parent != null) {
                                     _updateParentDuration(parent);
                                 }
                             }


                            print(
                              "Edit modal save: Activity updated with ID ${currentActivity.id}.",
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
                  ]
                )
              )
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
    final descriptionController = TextEditingController(); // Controller for description
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
                    const SizedBox(height: 12), // Added space
                    TextField( // Added description field
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                       maxLines: 3, // Allow multiple lines for description
                       keyboardType: TextInputType.multiline,
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
                            descriptionController.text.isNotEmpty // Pass description
                                ? descriptionController.text
                                : null,
                            null, // This is a top-level activity, no parentId
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
                // Only build top-level items directly in the main list
                if (activity.parentId == null) {
                   return _buildActivityItem(
                     context,
                     activity,
                     animation,
                     index: index,
                   );
                } else {
                   // Sub-tasks are built within their parent's item builder
                   return const SizedBox.shrink(); // Return empty for sub-tasks here
                }
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
    required int index, // Index in the _activities list (only for top-level)
    int subTaskIndex = -1, // Index within the parent's subTasks list
  }) {
    // Determine if this builder call is for a removal animation.
    final bool isRemoving = index < 0; // Only top-level removals use index -1

    final activityToShow = activity; // Use the passed activity object

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final cardColor = theme.cardColor;
    final hintColor = theme.hintColor;

    // Determine indentation level for sub-tasks
    final double indentation = activityToShow.parentId != null ? 24.0 : 0.0;

    // Determine font sizes based on whether it's a sub-task
    final double titleFontSize = activityToShow.parentId != null ? 14.0 : 16.0;
    final double subtitleFontSize = activityToShow.parentId != null ? 11.0 : 13.0;


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
              size: activityToShow.parentId != null ? 20 : 28, // Smaller tick for sub-tasks
            ),
            const SizedBox(width: 8), // Space between tick and reset button
            // Reset Button (now second in the row)
            IconButton(
              icon: Icon(Icons.refresh, size: activityToShow.parentId != null ? 20 : 24), // Smaller icon for sub-tasks
              color: Colors.deepPurple, // Use deepPurple for the icon
              tooltip: 'Reset Task',
              // Only allow reset if not currently removing and action is in progress
              onPressed: isRemoving || _isActionInProgress
                  ? null
                  : () => _resetActivity(activityToShow.id), // Use activity ID
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
                size: activityToShow.parentId != null ? 20 : 28, // Smaller icon for sub-tasks
              ),
              // Only allow toggle if not currently removing and action is in progress
              onPressed: isRemoving || _isActionInProgress
                  ? null
                  : () => _toggleTimer(activityToShow.id), // Use activity ID
              tooltip: activityToShow.isRunning ? 'Pause' : 'Start',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: activityToShow.parentId != null ? 24 : 32, // Smaller progress circle for sub-tasks
              height: activityToShow.parentId != null ? 24 : 32,
              child: ProgressCircle(
                progress: activityToShow.progress,
                completedColor: Colors.deepPurple.shade300,
                tickSize: activityToShow.parentId != null ? 14 : 18, // Smaller tick inside progress circle
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
          scale: activityToShow.parentId != null ? 1.0 : 1.2, // Slightly smaller checkbox for sub-tasks
          child: Checkbox(
            value: activityToShow.isChecked ?? false,
            // Only allow toggle if not currently removing and action is in progress
            onChanged: isRemoving || _isActionInProgress
                ? null
                : (bool? value) => _toggleCheckbox(activityToShow.id, value), // Use activity ID
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0 + indentation, vertical: activityToShow.parentId != null ? 4.0 : 8.0), // Apply indentation and reduce vertical padding for sub-tasks
        title: Text(
          activityToShow.title,
          style: GoogleFonts.vazirmatn(
            fontWeight: FontWeight.w600,
            fontSize: titleFontSize, // Use dynamic font size
            color: textTheme.titleMedium?.color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Column( // Use a Column to stack subtitle details and description
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only show date/time/duration/description for top-level tasks
              if (activityToShow.parentId == null) ...[
                Text(
                  '${activityToShow.date ?? ''}${activityToShow.date != null && activityToShow.time != null ? ' • ' : ''}${activityToShow.time ?? ''}${activityToShow.isTimed ? '\nDuration: ${activityToShow.duration} min' : ''}',
                  style: TextStyle(color: hintColor, fontSize: subtitleFontSize), // Use dynamic font size
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activityToShow.description != null && activityToShow.description!.isNotEmpty) // Conditionally display description
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      activityToShow.description!,
                      style: TextStyle(color: hintColor.withOpacity(0.8), fontSize: subtitleFontSize), // Use dynamic font size
                      maxLines: 3, // Limit description lines
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              // Show duration only for timed sub-tasks
               if (activityToShow.parentId != null && activityToShow.isTimed)
                 Text(
                   'Duration: ${activityToShow.duration} min',
                   style: TextStyle(color: hintColor, fontSize: subtitleFontSize),
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                 ),
            ],
          ),
        ),
         onTap: () {
           // Handle tap based on whether it's a top-level task or a sub-task
            if (!isRemoving && !_isActionInProgress) {
               if (activityToShow.parentId == null) {
                  // If it's a top-level task, toggle expansion
                  setState(() {
                     activityToShow.isExpanded = !activityToShow.isExpanded;
                     // Reset inline add state when collapsing
                     if (!activityToShow.isExpanded) {
                         _isAddingTimedSubTask = false;
                         _isAddingDescribedSubTask = false;
                         _subTaskTitleController.clear();
                         _subTaskDurationController.clear();
                         _subTaskDescriptionController.clear();
                     }
                  });
               } else {
                  // If it's a sub-task, open the edit modal for that sub-task
                  _showEditActivityModal(activityToShow.id);
               }
            }
         },
      );
    }

    // Build the main activity item, potentially with nested sub-tasks and inline add form
    return SizeTransition(
      sizeFactor: animation,
      child: Card( // Keep Card for the main task for structure, remove for sub-tasks below
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
        child: Column( // Column to hold the main task Slidable and the sub-task section
          children: [
            Slidable(
              // Use the activity's unique ID as the key
              key: ValueKey(activityToShow.id),
              // Pass the activity ID to the ActionPanes
              startActionPane: buildStartActionPane(
                index, // Still needed for AnimatedList removeItem builder context
                isRemoving,
                _isActionInProgress,
                activityToShow.id, // Pass activity ID directly
              ),
              endActionPane: buildEndActionPane(
                index, // Still needed for AnimatedList removeItem builder context
                isRemoving,
                _isActionInProgress,
                activityToShow.id, // Pass activity ID directly
              ),
              child: buildListTileContent(),
            ),
            // Inline Sub-task Section (only for top-level tasks when expanded)
            if (activityToShow.parentId == null && activityToShow.isExpanded)
               Container(
                 decoration: BoxDecoration(
                   border: Border(
                     left: BorderSide(
                       color: theme.colorScheme.primary.withOpacity(0.7), // Purple vertical line
                       width: 3.0,
                     ),
                   ),
                   color: theme.colorScheme.primary.withOpacity(0.05), // Subtle purplish background
                 ),
                 padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0, top: 8.0),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      // Input field for new sub-task title
                      TextField(
                        controller: _subTaskTitleController,
                        decoration: InputDecoration(
                          hintText: 'Add a sub-task',
                          border: InputBorder.none, // Minimal border
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: Row(
                             mainAxisSize: MainAxisSize.min, // Use minimum space
                             children: [
                                // Add Basic Sub-task Icon (+)
                                 GestureDetector(
                                    onTap: _isActionInProgress ? null : () {
                                       if (_subTaskTitleController.text.isNotEmpty) {
                                          _addActivity(
                                             _subTaskTitleController.text,
                                             null, // No duration for basic
                                             null, // No description for basic
                                             activityToShow.id, // Pass parent ID
                                          );
                                          _subTaskTitleController.clear();
                                          // Reset inline add state
                                          setState(() {
                                             _isAddingTimedSubTask = false;
                                             _isAddingDescribedSubTask = false;
                                             _subTaskDurationController.clear();
                                             _subTaskDescriptionController.clear();
                                          });
                                       }
                                    },
                                    child: Container(
                                       padding: const EdgeInsets.all(4.0),
                                       decoration: BoxDecoration(
                                          color: Colors.deepPurple.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                       ),
                                       child: Icon(Icons.add, size: 18, color: Colors.deepPurple),
                                    ),
                                 ),
                                 const SizedBox(width: 8),
                                 // Add Timed Sub-task Icon (Clock)
                                 GestureDetector(
                                    onTap: _isActionInProgress ? null : () {
                                       setState(() {
                                          _isAddingTimedSubTask = !_isAddingTimedSubTask;
                                          _isAddingDescribedSubTask = false; // Close description if open
                                          _subTaskDurationController.clear(); // Clear duration field
                                          _subTaskDescriptionController.clear(); // Clear description field
                                       });
                                    },
                                    child: Container(
                                       padding: const EdgeInsets.all(4.0),
                                       decoration: BoxDecoration(
                                          color: Colors.deepPurple.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                       ),
                                       child: Icon(Icons.access_time, size: 18, color: Colors.deepPurple),
                                    ),
                                 ),
                                 const SizedBox(width: 8),
                                 // Add Described Sub-task Icon (Note)
                                 GestureDetector(
                                    onTap: _isActionInProgress ? null : () {
                                       setState(() {
                                          _isAddingDescribedSubTask = !_isAddingDescribedSubTask;
                                          _isAddingTimedSubTask = false; // Close timed if open
                                          _subTaskDurationController.clear(); // Clear duration field
                                          _subTaskDescriptionController.clear(); // Clear description field
                                       });
                                    },
                                    child: Container(
                                       padding: const EdgeInsets.all(4.0),
                                       decoration: BoxDecoration(
                                          color: Colors.deepPurple.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                       ),
                                       child: Icon(Icons.note_add_outlined, size: 18, color: Colors.deepPurple),
                                    ),
                                 ),
                             ],
                          ),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),
                      // Inline input for duration (appears when clock icon is tapped)
                      Visibility(
                         visible: _isAddingTimedSubTask,
                         child: Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Row(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Icon(Icons.access_time, size: 18, color: hintColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                     controller: _subTaskDurationController,
                                     decoration: InputDecoration(
                                        hintText: 'Duration (minutes)',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     ),
                                     keyboardType: TextInputType.number,
                                     inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                     style: TextStyle(fontSize: 14),
                                     onSubmitted: _isActionInProgress ? null : (value) {
                                         if (_subTaskTitleController.text.isNotEmpty) {
                                            _addActivity(
                                               _subTaskTitleController.text,
                                               value.isNotEmpty ? value : null,
                                               null, // No description for timed inline add
                                               activityToShow.id, // Pass parent ID
                                            );
                                            _subTaskTitleController.clear();
                                            _subTaskDurationController.clear();
                                            // Reset inline add state
                                            setState(() {
                                               _isAddingTimedSubTask = false;
                                               _isAddingDescribedSubTask = false;
                                            });
                                         }
                                     },
                                  ),
                                ),
                                 const SizedBox(width: 8),
                                 // Add Timed Sub-task Button (appears next to duration input)
                                 ElevatedButton(
                                    onPressed: _isActionInProgress ? null : () {
                                       if (_subTaskTitleController.text.isNotEmpty) {
                                          _addActivity(
                                             _subTaskTitleController.text,
                                             _subTaskDurationController.text.isNotEmpty
                                                 ? _subTaskDurationController.text
                                                 : null,
                                             null, // No description for timed inline add
                                             activityToShow.id, // Pass parent ID
                                          );
                                          _subTaskTitleController.clear();
                                          _subTaskDurationController.clear();
                                           // Reset inline add state
                                           setState(() {
                                              _isAddingTimedSubTask = false;
                                              _isAddingDescribedSubTask = false;
                                           });
                                       }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      textStyle: GoogleFonts.vazirmatn(fontSize: 14, fontWeight: FontWeight.w500),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text("Add"),
                                 ),
                             ],
                           ),
                         ),
                      ),
                       // Inline input for description (appears when note icon is tapped)
                      Visibility(
                         visible: _isAddingDescribedSubTask,
                         child: Padding(
                           padding: const EdgeInsets.only(top: 8.0),
                           child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Icon(Icons.note_add_outlined, size: 18, color: hintColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                     controller: _subTaskDescriptionController,
                                     decoration: InputDecoration(
                                        hintText: 'Description',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                     ),
                                     maxLines: 2, // Allow multiple lines
                                     keyboardType: TextInputType.multiline,
                                     style: TextStyle(fontSize: 14),
                                      onSubmitted: _isActionInProgress ? null : (value) {
                                         if (_subTaskTitleController.text.isNotEmpty) {
                                            _addActivity(
                                               _subTaskTitleController.text,
                                               null, // No duration for described inline add
                                               value.isNotEmpty ? value : null,
                                               activityToShow.id, // Pass parent ID
                                            );
                                            _subTaskTitleController.clear();
                                            _subTaskDescriptionController.clear();
                                            // Reset inline add state
                                            setState(() {
                                               _isAddingTimedSubTask = false;
                                               _isAddingDescribedSubTask = false;
                                            });
                                         }
                                      },
                                  ),
                                ),
                                  const SizedBox(width: 8),
                                 // Add Described Sub-task Button (appears next to description input)
                                 ElevatedButton(
                                    onPressed: _isActionInProgress ? null : () {
                                       if (_subTaskTitleController.text.isNotEmpty) {
                                          _addActivity(
                                             _subTaskTitleController.text,
                                             null, // No duration for described inline add
                                             _subTaskDescriptionController.text.isNotEmpty
                                                 ? _subTaskDescriptionController.text
                                                 : null,
                                             activityToShow.id, // Pass parent ID
                                          );
                                          _subTaskTitleController.clear();
                                          _subTaskDescriptionController.clear();
                                           // Reset inline add state
                                           setState(() {
                                              _isAddingTimedSubTask = false;
                                              _isAddingDescribedSubTask = false;
                                           });
                                       }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      textStyle: GoogleFonts.vazirmatn(fontSize: 14, fontWeight: FontWeight.w500),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text("Add"),
                                 ),
                             ],
                           ),
                         ),
                      ),

                      // Display existing sub-tasks
                      if (activityToShow.subTasks != null && activityToShow.subTasks!.isNotEmpty)
                         Column(
                           children: activityToShow.subTasks!.map((subTask) {
                              // Recursively build sub-task item
                              return _buildActivityItem(
                                 context,
                                 subTask,
                                 animation, // Use parent's animation
                                 index: -1, // Indicate it's a sub-task
                                 subTaskIndex: activityToShow.subTasks!.indexOf(subTask),
                              );
                           }).toList(),
                         ),
                   ],
                 ),
               ),
          ],
        ),
      ),
    );
  }

    // Action Pane for Edit - Triggered by swiping from left to right
    ActionPane buildStartActionPane(
      int index, // Keep for AnimatedList remove animation context
      bool isRemoving,
      bool _isActionInProgress,
      String activityId, // Accept activity ID directly
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
                if (!isRemoving && !_isActionInProgress) {
                   _showEditActivityModal(activityId); // Use the passed activity ID
                } else {
                  print(
                    "Edit button: Action aborted, widget removing or action in progress.",
                  ); // Debug print
                }
              },
              child: Container(
                decoration: BoxDecoration( // Added const
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
      int index, // Keep for AnimatedList remove animation context
      bool isRemoving,
      bool _isActionInProgress,
      String activityId, // Accept activity ID directly
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
                if (!isRemoving && !_isActionInProgress) {
                   _handleDelete(activityId); // Use the passed activity ID
                } else {
                  print(
                    "Delete button: Action aborted, widget removing or action in progress.",
                  ); // Debug print
                  // Optionally, show a message to the user here
                }
              },
              child: Container(
                decoration: BoxDecoration( // Added const
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
}
