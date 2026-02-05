
import 'package:equatable/equatable.dart';

import '../../../core/db/app_db.dart';

enum TxStatus { initial, loading, loaded, failure }

class TransactionState extends Equatable {
  const TransactionState({
    required this.status,
    required this.monthId,
    required this.items,
    required this.error,
  });

  const TransactionState.initial()
      : status = TxStatus.initial,
        monthId = '',
        items = const [],
        error = '';

  final TxStatus status;
  final String monthId;
  final List<Transaction> items;
  final String error;

  TransactionState copyWith({
    TxStatus? status,
    String? monthId,
    List<Transaction>? items,
    String? error,
  }) {
    return TransactionState(
      status: status ?? this.status,
      monthId: monthId ?? this.monthId,
      items: items ?? this.items,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, monthId, items, error];
}
