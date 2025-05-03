import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:takar/widgets/progress_circle.dart';

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
  final List<Map<String, dynamic>> _activities = [];

  void _addActivity(String title, String duration) {
    setState(() {
      _activities.add({
        'title': title,
        'duration': duration,
        'time': TimeOfDay.now().format(context),
        'progress': 0.0,
        'completed': false,
        'isRunning': false,
      });
    });
  }

  void _updateProgress(int index) {
    Future.delayed(const Duration(seconds: 6), () {
      setState(() {
        if (_activities[index]['isRunning'] == true &&
            _activities[index]['progress'] < 1.0) {
          _activities[index]['progress'] += 0.1;
          if (_activities[index]['progress'] >= 1.0) {
            _activities[index]['progress'] = 1.0;
            _activities[index]['completed'] = true;
            _activities[index]['isRunning'] = false;
          } else {
            _updateProgress(index);
          }
        }
      });
    });
  }

  void _openAddActivityModal() {
    final titleController = TextEditingController();
    final durationController = TextEditingController();
    final inputFormatter = FilteringTextInputFormatter.digitsOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                  labelText: 'Duration (minutes)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [inputFormatter],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.isNotEmpty &&
                      durationController.text.isNotEmpty) {
                    _addActivity(titleController.text, durationController.text);
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
                  return Card(
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
                        "Duration: ${activity['duration']} min, Time: ${activity['time']}",
                        style: TextStyle(
                          color: themeColor.withAlpha((0.7 * 255).toInt()),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                              completedColor: const Color.fromARGB(
                                157,
                                243,
                                231,
                                141,
                              ),
                              tickSize: 12.0,
                              isCompleted: activity['completed'] ?? false,
                            ),
                          ),
                        ],
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
