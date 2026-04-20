import 'package:flutter/material.dart';

class DateOfBirthPickerScreen extends StatefulWidget {
  final DateTime? initialDate;
  const DateOfBirthPickerScreen({super.key, this.initialDate});

  @override
  State<DateOfBirthPickerScreen> createState() => _DateOfBirthPickerScreenState();
}

class _DateOfBirthPickerScreenState extends State<DateOfBirthPickerScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now().subtract(const Duration(days: 365 * 18));
  }

  int _age(DateTime date) {
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final age = _age(_selectedDate);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Date of Birth'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedDate),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text('Selected age: $age', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (age < 13)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'You must be at least 13 years old to use TikiZaya.',
                style: TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              onDateChanged: (value) {
                setState(() {
                  _selectedDate = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
