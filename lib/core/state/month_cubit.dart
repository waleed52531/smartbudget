import 'package:flutter_bloc/flutter_bloc.dart';

class MonthCubit extends Cubit<String> {
  MonthCubit(String initialMonthId) : super(initialMonthId);

  void setMonthId(String monthId) => emit(monthId);

  void setFromDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    emit('$y-$m');
  }

  static DateTime toDate(String monthId) {
    final y = int.parse(monthId.substring(0, 4));
    final m = int.parse(monthId.substring(5, 7));
    return DateTime(y, m, 1);
  }

  static String display(String monthId) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final y = monthId.substring(0, 4);
    final m = int.parse(monthId.substring(5, 7));
    return '${months[m - 1]} $y';
  }
}
