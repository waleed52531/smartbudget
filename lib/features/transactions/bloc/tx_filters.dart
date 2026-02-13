import 'package:equatable/equatable.dart';

enum TxTypeFilter { all, expense, income }
enum TxSort { newest, oldest, amountHigh, amountLow }

class TxFilters extends Equatable {
  const TxFilters({
    this.type = TxTypeFilter.all,
    this.sort = TxSort.newest,
    this.search = '',
    this.categoryId,
    this.subcategoryId,
    this.categorySubcategoryIds,
    this.fromMillis,
    this.toMillis,
    this.minMinor,
    this.maxMinor,
  });

  static const empty = TxFilters();

  final TxTypeFilter type;
  final TxSort sort;

  final String search;

  /// Selected category (optional)
  final String? categoryId;

  /// Selected subcategory (optional)
  final String? subcategoryId;

  /// If a category is selected but subcategory isn't, you can pass all subIds here
  final List<String>? categorySubcategoryIds;

  final int? fromMillis;
  final int? toMillis;

  final int? minMinor;
  final int? maxMinor;

  bool get hasAny =>
      type != TxTypeFilter.all ||
          sort != TxSort.newest ||
          search.trim().isNotEmpty ||
          categoryId != null ||
          subcategoryId != null ||
          (categorySubcategoryIds != null && categorySubcategoryIds!.isNotEmpty) ||
          fromMillis != null ||
          toMillis != null ||
          minMinor != null ||
          maxMinor != null;

  TxFilters copyWith({
    TxTypeFilter? type,
    TxSort? sort,
    String? search,
    String? categoryId,
    String? subcategoryId,
    List<String>? categorySubcategoryIds,
    int? fromMillis,
    int? toMillis,
    int? minMinor,
    int? maxMinor,
    bool clearCategory = false,
    bool clearSubcategory = false,
    bool clearDates = false,
    bool clearAmountRange = false,
  }) {
    return TxFilters(
      type: type ?? this.type,
      sort: sort ?? this.sort,
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      subcategoryId: clearSubcategory ? null : (subcategoryId ?? this.subcategoryId),
      categorySubcategoryIds: categorySubcategoryIds ?? this.categorySubcategoryIds,
      fromMillis: clearDates ? null : (fromMillis ?? this.fromMillis),
      toMillis: clearDates ? null : (toMillis ?? this.toMillis),
      minMinor: clearAmountRange ? null : (minMinor ?? this.minMinor),
      maxMinor: clearAmountRange ? null : (maxMinor ?? this.maxMinor),
    );
  }

  @override
  List<Object?> get props => [
    type,
    sort,
    search,
    categoryId,
    subcategoryId,
    categorySubcategoryIds,
    fromMillis,
    toMillis,
    minMinor,
    maxMinor,
  ];
}
