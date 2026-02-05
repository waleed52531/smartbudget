import 'package:flutter/material.dart';

Future<DateTime?> showMonthPickerSheet(BuildContext context, DateTime initial) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: false,
    builder: (_) => _MonthPickerSheet(initial: initial),
  );
}

class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.initial});
  final DateTime initial;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int year;

  @override
  void initState() {
    super.initState();
    year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return SafeArea(
      child: SizedBox(
        height: 360,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => year--),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$year',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => year++),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.3,
                  ),
                  itemBuilder: (_, i) {
                    final month = i + 1;
                    return OutlinedButton(
                      onPressed: () => Navigator.pop(context, DateTime(year, month, 1)),
                      child: Text(months[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
