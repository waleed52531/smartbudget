// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $CategoryNodesTable extends CategoryNodes
    with TableInfo<$CategoryNodesTable, CategoryNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => _uuid.v4(),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK(type IN (\'category\',\'subcategory\'))',
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    parentId,
    archived,
    sortOrder,
    icon,
    color,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryNode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, parentId},
  ];
  @override
  CategoryNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryNode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
    );
  }

  @override
  $CategoryNodesTable createAlias(String alias) {
    return $CategoryNodesTable(attachedDatabase, alias);
  }
}

class CategoryNode extends DataClass implements Insertable<CategoryNode> {
  final String id;
  final String name;

  /// 'category' | 'subcategory'
  final String type;

  /// Null for category, required for subcategory
  final String? parentId;
  final bool archived;
  final int sortOrder;
  final String? icon;
  final int? color;
  const CategoryNode({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    required this.archived,
    required this.sortOrder,
    this.icon,
    this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['archived'] = Variable<bool>(archived);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    return map;
  }

  CategoryNodesCompanion toCompanion(bool nullToAbsent) {
    return CategoryNodesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      archived: Value(archived),
      sortOrder: Value(sortOrder),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
    );
  }

  factory CategoryNode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryNode(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      archived: serializer.fromJson<bool>(json['archived']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<int?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'parentId': serializer.toJson<String?>(parentId),
      'archived': serializer.toJson<bool>(archived),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<int?>(color),
    };
  }

  CategoryNode copyWith({
    String? id,
    String? name,
    String? type,
    Value<String?> parentId = const Value.absent(),
    bool? archived,
    int? sortOrder,
    Value<String?> icon = const Value.absent(),
    Value<int?> color = const Value.absent(),
  }) => CategoryNode(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    parentId: parentId.present ? parentId.value : this.parentId,
    archived: archived ?? this.archived,
    sortOrder: sortOrder ?? this.sortOrder,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
  );
  CategoryNode copyWithCompanion(CategoryNodesCompanion data) {
    return CategoryNode(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      archived: data.archived.present ? data.archived.value : this.archived,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryNode(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('parentId: $parentId, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('icon: $icon, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, type, parentId, archived, sortOrder, icon, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryNode &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.parentId == this.parentId &&
          other.archived == this.archived &&
          other.sortOrder == this.sortOrder &&
          other.icon == this.icon &&
          other.color == this.color);
}

class CategoryNodesCompanion extends UpdateCompanion<CategoryNode> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> parentId;
  final Value<bool> archived;
  final Value<int> sortOrder;
  final Value<String?> icon;
  final Value<int?> color;
  final Value<int> rowid;
  const CategoryNodesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.parentId = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryNodesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String type,
    this.parentId = const Value.absent(),
    this.archived = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       type = Value(type);
  static Insertable<CategoryNode> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? parentId,
    Expression<bool>? archived,
    Expression<int>? sortOrder,
    Expression<String>? icon,
    Expression<int>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (parentId != null) 'parent_id': parentId,
      if (archived != null) 'archived': archived,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryNodesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? parentId,
    Value<bool>? archived,
    Value<int>? sortOrder,
    Value<String?>? icon,
    Value<int?>? color,
    Value<int>? rowid,
  }) {
    return CategoryNodesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryNodesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('parentId: $parentId, ')
          ..write('archived: $archived, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetMonthsTable extends BudgetMonths
    with TableInfo<$BudgetMonthsTable, BudgetMonth> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetMonthsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PKR'),
  );
  static const VerificationMeta _totalBudgetMinorMeta = const VerificationMeta(
    'totalBudgetMinor',
  );
  @override
  late final GeneratedColumn<int> totalBudgetMinor = GeneratedColumn<int>(
    'total_budget_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _savingTargetMinorMeta = const VerificationMeta(
    'savingTargetMinor',
  );
  @override
  late final GeneratedColumn<int> savingTargetMinor = GeneratedColumn<int>(
    'saving_target_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currency,
    totalBudgetMinor,
    savingTargetMinor,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget_months';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetMonth> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('total_budget_minor')) {
      context.handle(
        _totalBudgetMinorMeta,
        totalBudgetMinor.isAcceptableOrUnknown(
          data['total_budget_minor']!,
          _totalBudgetMinorMeta,
        ),
      );
    }
    if (data.containsKey('saving_target_minor')) {
      context.handle(
        _savingTargetMinorMeta,
        savingTargetMinor.isAcceptableOrUnknown(
          data['saving_target_minor']!,
          _savingTargetMinorMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetMonth map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetMonth(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      totalBudgetMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_budget_minor'],
      )!,
      savingTargetMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saving_target_minor'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BudgetMonthsTable createAlias(String alias) {
    return $BudgetMonthsTable(attachedDatabase, alias);
  }
}

class BudgetMonth extends DataClass implements Insertable<BudgetMonth> {
  /// e.g., '2026-01'
  final String id;

  /// Keep simple for now; you can replace with onboarding preference later
  final String currency;
  final int totalBudgetMinor;
  final int savingTargetMinor;
  final int createdAt;
  const BudgetMonth({
    required this.id,
    required this.currency,
    required this.totalBudgetMinor,
    required this.savingTargetMinor,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['currency'] = Variable<String>(currency);
    map['total_budget_minor'] = Variable<int>(totalBudgetMinor);
    map['saving_target_minor'] = Variable<int>(savingTargetMinor);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BudgetMonthsCompanion toCompanion(bool nullToAbsent) {
    return BudgetMonthsCompanion(
      id: Value(id),
      currency: Value(currency),
      totalBudgetMinor: Value(totalBudgetMinor),
      savingTargetMinor: Value(savingTargetMinor),
      createdAt: Value(createdAt),
    );
  }

  factory BudgetMonth.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetMonth(
      id: serializer.fromJson<String>(json['id']),
      currency: serializer.fromJson<String>(json['currency']),
      totalBudgetMinor: serializer.fromJson<int>(json['totalBudgetMinor']),
      savingTargetMinor: serializer.fromJson<int>(json['savingTargetMinor']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'currency': serializer.toJson<String>(currency),
      'totalBudgetMinor': serializer.toJson<int>(totalBudgetMinor),
      'savingTargetMinor': serializer.toJson<int>(savingTargetMinor),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  BudgetMonth copyWith({
    String? id,
    String? currency,
    int? totalBudgetMinor,
    int? savingTargetMinor,
    int? createdAt,
  }) => BudgetMonth(
    id: id ?? this.id,
    currency: currency ?? this.currency,
    totalBudgetMinor: totalBudgetMinor ?? this.totalBudgetMinor,
    savingTargetMinor: savingTargetMinor ?? this.savingTargetMinor,
    createdAt: createdAt ?? this.createdAt,
  );
  BudgetMonth copyWithCompanion(BudgetMonthsCompanion data) {
    return BudgetMonth(
      id: data.id.present ? data.id.value : this.id,
      currency: data.currency.present ? data.currency.value : this.currency,
      totalBudgetMinor: data.totalBudgetMinor.present
          ? data.totalBudgetMinor.value
          : this.totalBudgetMinor,
      savingTargetMinor: data.savingTargetMinor.present
          ? data.savingTargetMinor.value
          : this.savingTargetMinor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetMonth(')
          ..write('id: $id, ')
          ..write('currency: $currency, ')
          ..write('totalBudgetMinor: $totalBudgetMinor, ')
          ..write('savingTargetMinor: $savingTargetMinor, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, currency, totalBudgetMinor, savingTargetMinor, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetMonth &&
          other.id == this.id &&
          other.currency == this.currency &&
          other.totalBudgetMinor == this.totalBudgetMinor &&
          other.savingTargetMinor == this.savingTargetMinor &&
          other.createdAt == this.createdAt);
}

class BudgetMonthsCompanion extends UpdateCompanion<BudgetMonth> {
  final Value<String> id;
  final Value<String> currency;
  final Value<int> totalBudgetMinor;
  final Value<int> savingTargetMinor;
  final Value<int> createdAt;
  final Value<int> rowid;
  const BudgetMonthsCompanion({
    this.id = const Value.absent(),
    this.currency = const Value.absent(),
    this.totalBudgetMinor = const Value.absent(),
    this.savingTargetMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetMonthsCompanion.insert({
    required String id,
    this.currency = const Value.absent(),
    this.totalBudgetMinor = const Value.absent(),
    this.savingTargetMinor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<BudgetMonth> custom({
    Expression<String>? id,
    Expression<String>? currency,
    Expression<int>? totalBudgetMinor,
    Expression<int>? savingTargetMinor,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currency != null) 'currency': currency,
      if (totalBudgetMinor != null) 'total_budget_minor': totalBudgetMinor,
      if (savingTargetMinor != null) 'saving_target_minor': savingTargetMinor,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetMonthsCompanion copyWith({
    Value<String>? id,
    Value<String>? currency,
    Value<int>? totalBudgetMinor,
    Value<int>? savingTargetMinor,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return BudgetMonthsCompanion(
      id: id ?? this.id,
      currency: currency ?? this.currency,
      totalBudgetMinor: totalBudgetMinor ?? this.totalBudgetMinor,
      savingTargetMinor: savingTargetMinor ?? this.savingTargetMinor,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (totalBudgetMinor.present) {
      map['total_budget_minor'] = Variable<int>(totalBudgetMinor.value);
    }
    if (savingTargetMinor.present) {
      map['saving_target_minor'] = Variable<int>(savingTargetMinor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetMonthsCompanion(')
          ..write('id: $id, ')
          ..write('currency: $currency, ')
          ..write('totalBudgetMinor: $totalBudgetMinor, ')
          ..write('savingTargetMinor: $savingTargetMinor, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetLimitsTable extends BudgetLimits
    with TableInfo<$BudgetLimitsTable, BudgetLimit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetLimitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => _uuid.v4(),
  );
  static const VerificationMeta _budgetMonthIdMeta = const VerificationMeta(
    'budgetMonthId',
  );
  @override
  late final GeneratedColumn<String> budgetMonthId = GeneratedColumn<String>(
    'budget_month_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES budget_months (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES category_nodes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _limitMinorMeta = const VerificationMeta(
    'limitMinor',
  );
  @override
  late final GeneratedColumn<int> limitMinor = GeneratedColumn<int>(
    'limit_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, budgetMonthId, nodeId, limitMinor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget_limits';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetLimit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('budget_month_id')) {
      context.handle(
        _budgetMonthIdMeta,
        budgetMonthId.isAcceptableOrUnknown(
          data['budget_month_id']!,
          _budgetMonthIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_budgetMonthIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('limit_minor')) {
      context.handle(
        _limitMinorMeta,
        limitMinor.isAcceptableOrUnknown(data['limit_minor']!, _limitMinorMeta),
      );
    } else if (isInserting) {
      context.missing(_limitMinorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {budgetMonthId, nodeId},
  ];
  @override
  BudgetLimit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetLimit(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      budgetMonthId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_month_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      limitMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}limit_minor'],
      )!,
    );
  }

  @override
  $BudgetLimitsTable createAlias(String alias) {
    return $BudgetLimitsTable(attachedDatabase, alias);
  }
}

class BudgetLimit extends DataClass implements Insertable<BudgetLimit> {
  final String id;
  final String budgetMonthId;

  /// Option A: nodeId points to category rows only
  /// Option B (later): nodeId can point to category or subcategory
  final String nodeId;
  final int limitMinor;
  const BudgetLimit({
    required this.id,
    required this.budgetMonthId,
    required this.nodeId,
    required this.limitMinor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['budget_month_id'] = Variable<String>(budgetMonthId);
    map['node_id'] = Variable<String>(nodeId);
    map['limit_minor'] = Variable<int>(limitMinor);
    return map;
  }

  BudgetLimitsCompanion toCompanion(bool nullToAbsent) {
    return BudgetLimitsCompanion(
      id: Value(id),
      budgetMonthId: Value(budgetMonthId),
      nodeId: Value(nodeId),
      limitMinor: Value(limitMinor),
    );
  }

  factory BudgetLimit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetLimit(
      id: serializer.fromJson<String>(json['id']),
      budgetMonthId: serializer.fromJson<String>(json['budgetMonthId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      limitMinor: serializer.fromJson<int>(json['limitMinor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'budgetMonthId': serializer.toJson<String>(budgetMonthId),
      'nodeId': serializer.toJson<String>(nodeId),
      'limitMinor': serializer.toJson<int>(limitMinor),
    };
  }

  BudgetLimit copyWith({
    String? id,
    String? budgetMonthId,
    String? nodeId,
    int? limitMinor,
  }) => BudgetLimit(
    id: id ?? this.id,
    budgetMonthId: budgetMonthId ?? this.budgetMonthId,
    nodeId: nodeId ?? this.nodeId,
    limitMinor: limitMinor ?? this.limitMinor,
  );
  BudgetLimit copyWithCompanion(BudgetLimitsCompanion data) {
    return BudgetLimit(
      id: data.id.present ? data.id.value : this.id,
      budgetMonthId: data.budgetMonthId.present
          ? data.budgetMonthId.value
          : this.budgetMonthId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      limitMinor: data.limitMinor.present
          ? data.limitMinor.value
          : this.limitMinor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetLimit(')
          ..write('id: $id, ')
          ..write('budgetMonthId: $budgetMonthId, ')
          ..write('nodeId: $nodeId, ')
          ..write('limitMinor: $limitMinor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, budgetMonthId, nodeId, limitMinor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetLimit &&
          other.id == this.id &&
          other.budgetMonthId == this.budgetMonthId &&
          other.nodeId == this.nodeId &&
          other.limitMinor == this.limitMinor);
}

class BudgetLimitsCompanion extends UpdateCompanion<BudgetLimit> {
  final Value<String> id;
  final Value<String> budgetMonthId;
  final Value<String> nodeId;
  final Value<int> limitMinor;
  final Value<int> rowid;
  const BudgetLimitsCompanion({
    this.id = const Value.absent(),
    this.budgetMonthId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.limitMinor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetLimitsCompanion.insert({
    this.id = const Value.absent(),
    required String budgetMonthId,
    required String nodeId,
    required int limitMinor,
    this.rowid = const Value.absent(),
  }) : budgetMonthId = Value(budgetMonthId),
       nodeId = Value(nodeId),
       limitMinor = Value(limitMinor);
  static Insertable<BudgetLimit> custom({
    Expression<String>? id,
    Expression<String>? budgetMonthId,
    Expression<String>? nodeId,
    Expression<int>? limitMinor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (budgetMonthId != null) 'budget_month_id': budgetMonthId,
      if (nodeId != null) 'node_id': nodeId,
      if (limitMinor != null) 'limit_minor': limitMinor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetLimitsCompanion copyWith({
    Value<String>? id,
    Value<String>? budgetMonthId,
    Value<String>? nodeId,
    Value<int>? limitMinor,
    Value<int>? rowid,
  }) {
    return BudgetLimitsCompanion(
      id: id ?? this.id,
      budgetMonthId: budgetMonthId ?? this.budgetMonthId,
      nodeId: nodeId ?? this.nodeId,
      limitMinor: limitMinor ?? this.limitMinor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (budgetMonthId.present) {
      map['budget_month_id'] = Variable<String>(budgetMonthId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (limitMinor.present) {
      map['limit_minor'] = Variable<int>(limitMinor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetLimitsCompanion(')
          ..write('id: $id, ')
          ..write('budgetMonthId: $budgetMonthId, ')
          ..write('nodeId: $nodeId, ')
          ..write('limitMinor: $limitMinor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => _uuid.v4(),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK(type IN (\'income\',\'expense\'))',
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMillisMeta = const VerificationMeta(
    'dateMillis',
  );
  @override
  late final GeneratedColumn<int> dateMillis = GeneratedColumn<int>(
    'date_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthIdMeta = const VerificationMeta(
    'monthId',
  );
  @override
  late final GeneratedColumn<String> monthId = GeneratedColumn<String>(
    'month_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES category_nodes (id)',
    ),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now().millisecondsSinceEpoch,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    amountMinor,
    dateMillis,
    monthId,
    subcategoryId,
    note,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('date_millis')) {
      context.handle(
        _dateMillisMeta,
        dateMillis.isAcceptableOrUnknown(data['date_millis']!, _dateMillisMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMillisMeta);
    }
    if (data.containsKey('month_id')) {
      context.handle(
        _monthIdMeta,
        monthId.isAcceptableOrUnknown(data['month_id']!, _monthIdMeta),
      );
    } else if (isInserting) {
      context.missing(_monthIdMeta);
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      dateMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_millis'],
      )!,
      monthId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_id'],
      )!,
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;

  /// 'income' | 'expense'
  final String type;

  /// Money in minor units (paisa/cents)
  final int amountMinor;

  /// Epoch millis
  final int dateMillis;

  /// Stored at write-time (avoid timezone bugs and slow grouping)
  /// e.g., '2026-01'
  final String monthId;

  /// For expenses: must be NOT NULL (enforced by table constraint below)
  /// For income: must be NULL
  final String? subcategoryId;
  final String? note;
  final int createdAt;
  final int updatedAt;
  const Transaction({
    required this.id,
    required this.type,
    required this.amountMinor,
    required this.dateMillis,
    required this.monthId,
    this.subcategoryId,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['date_millis'] = Variable<int>(dateMillis);
    map['month_id'] = Variable<String>(monthId);
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      type: Value(type),
      amountMinor: Value(amountMinor),
      dateMillis: Value(dateMillis),
      monthId: Value(monthId),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      dateMillis: serializer.fromJson<int>(json['dateMillis']),
      monthId: serializer.fromJson<String>(json['monthId']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'dateMillis': serializer.toJson<int>(dateMillis),
      'monthId': serializer.toJson<String>(monthId),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Transaction copyWith({
    String? id,
    String? type,
    int? amountMinor,
    int? dateMillis,
    String? monthId,
    Value<String?> subcategoryId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => Transaction(
    id: id ?? this.id,
    type: type ?? this.type,
    amountMinor: amountMinor ?? this.amountMinor,
    dateMillis: dateMillis ?? this.dateMillis,
    monthId: monthId ?? this.monthId,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      dateMillis: data.dateMillis.present
          ? data.dateMillis.value
          : this.dateMillis,
      monthId: data.monthId.present ? data.monthId.value : this.monthId,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('dateMillis: $dateMillis, ')
          ..write('monthId: $monthId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amountMinor,
    dateMillis,
    monthId,
    subcategoryId,
    note,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.type == this.type &&
          other.amountMinor == this.amountMinor &&
          other.dateMillis == this.dateMillis &&
          other.monthId == this.monthId &&
          other.subcategoryId == this.subcategoryId &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<String> type;
  final Value<int> amountMinor;
  final Value<int> dateMillis;
  final Value<String> monthId;
  final Value<String?> subcategoryId;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.dateMillis = const Value.absent(),
    this.monthId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    required String type,
    required int amountMinor,
    required int dateMillis,
    required String monthId,
    this.subcategoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : type = Value(type),
       amountMinor = Value(amountMinor),
       dateMillis = Value(dateMillis),
       monthId = Value(monthId);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<int>? amountMinor,
    Expression<int>? dateMillis,
    Expression<String>? monthId,
    Expression<String>? subcategoryId,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (dateMillis != null) 'date_millis': dateMillis,
      if (monthId != null) 'month_id': monthId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<int>? amountMinor,
    Value<int>? dateMillis,
    Value<String>? monthId,
    Value<String?>? subcategoryId,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      dateMillis: dateMillis ?? this.dateMillis,
      monthId: monthId ?? this.monthId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (dateMillis.present) {
      map['date_millis'] = Variable<int>(dateMillis.value);
    }
    if (monthId.present) {
      map['month_id'] = Variable<String>(monthId.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('dateMillis: $dateMillis, ')
          ..write('monthId: $monthId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringTemplatesTable extends RecurringTemplates
    with TableInfo<$RecurringTemplatesTable, RecurringTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMinorMeta = const VerificationMeta(
    'amountMinor',
  );
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
    'amount_minor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK(type IN (\'income\',\'expense\'))',
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES category_nodes (id)',
    ),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dayOfMonthMeta = const VerificationMeta(
    'dayOfMonth',
  );
  @override
  late final GeneratedColumn<int> dayOfMonth = GeneratedColumn<int>(
    'day_of_month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMillisMeta = const VerificationMeta(
    'createdAtMillis',
  );
  @override
  late final GeneratedColumn<int> createdAtMillis = GeneratedColumn<int>(
    'created_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    amountMinor,
    type,
    subcategoryId,
    note,
    dayOfMonth,
    isActive,
    createdAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
        _amountMinorMeta,
        amountMinor.isAcceptableOrUnknown(
          data['amount_minor']!,
          _amountMinorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('day_of_month')) {
      context.handle(
        _dayOfMonthMeta,
        dayOfMonth.isAcceptableOrUnknown(
          data['day_of_month']!,
          _dayOfMonthMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at_millis')) {
      context.handle(
        _createdAtMillisMeta,
        createdAtMillis.isAcceptableOrUnknown(
          data['created_at_millis']!,
          _createdAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMillisMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      amountMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_minor'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      dayOfMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_of_month'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_millis'],
      )!,
    );
  }

  @override
  $RecurringTemplatesTable createAlias(String alias) {
    return $RecurringTemplatesTable(attachedDatabase, alias);
  }
}

class RecurringTemplate extends DataClass
    implements Insertable<RecurringTemplate> {
  final String id;
  final String title;
  final int amountMinor;
  final String type;

  /// Optional: for expenses you can store subcategoryId here (same as Transactions.subcategoryId)
  final String? subcategoryId;
  final String? note;

  /// 1..31 (clamp in repo when applying)
  final int dayOfMonth;
  final bool isActive;
  final int createdAtMillis;
  const RecurringTemplate({
    required this.id,
    required this.title,
    required this.amountMinor,
    required this.type,
    this.subcategoryId,
    this.note,
    required this.dayOfMonth,
    required this.isActive,
    required this.createdAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['day_of_month'] = Variable<int>(dayOfMonth);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at_millis'] = Variable<int>(createdAtMillis);
    return map;
  }

  RecurringTemplatesCompanion toCompanion(bool nullToAbsent) {
    return RecurringTemplatesCompanion(
      id: Value(id),
      title: Value(title),
      amountMinor: Value(amountMinor),
      type: Value(type),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      dayOfMonth: Value(dayOfMonth),
      isActive: Value(isActive),
      createdAtMillis: Value(createdAtMillis),
    );
  }

  factory RecurringTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringTemplate(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      type: serializer.fromJson<String>(json['type']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      note: serializer.fromJson<String?>(json['note']),
      dayOfMonth: serializer.fromJson<int>(json['dayOfMonth']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAtMillis: serializer.fromJson<int>(json['createdAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'type': serializer.toJson<String>(type),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'note': serializer.toJson<String?>(note),
      'dayOfMonth': serializer.toJson<int>(dayOfMonth),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAtMillis': serializer.toJson<int>(createdAtMillis),
    };
  }

  RecurringTemplate copyWith({
    String? id,
    String? title,
    int? amountMinor,
    String? type,
    Value<String?> subcategoryId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? dayOfMonth,
    bool? isActive,
    int? createdAtMillis,
  }) => RecurringTemplate(
    id: id ?? this.id,
    title: title ?? this.title,
    amountMinor: amountMinor ?? this.amountMinor,
    type: type ?? this.type,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    note: note.present ? note.value : this.note,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    isActive: isActive ?? this.isActive,
    createdAtMillis: createdAtMillis ?? this.createdAtMillis,
  );
  RecurringTemplate copyWithCompanion(RecurringTemplatesCompanion data) {
    return RecurringTemplate(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      amountMinor: data.amountMinor.present
          ? data.amountMinor.value
          : this.amountMinor,
      type: data.type.present ? data.type.value : this.type,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      note: data.note.present ? data.note.value : this.note,
      dayOfMonth: data.dayOfMonth.present
          ? data.dayOfMonth.value
          : this.dayOfMonth,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAtMillis: data.createdAtMillis.present
          ? data.createdAtMillis.value
          : this.createdAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTemplate(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('type: $type, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('note: $note, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtMillis: $createdAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    amountMinor,
    type,
    subcategoryId,
    note,
    dayOfMonth,
    isActive,
    createdAtMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringTemplate &&
          other.id == this.id &&
          other.title == this.title &&
          other.amountMinor == this.amountMinor &&
          other.type == this.type &&
          other.subcategoryId == this.subcategoryId &&
          other.note == this.note &&
          other.dayOfMonth == this.dayOfMonth &&
          other.isActive == this.isActive &&
          other.createdAtMillis == this.createdAtMillis);
}

class RecurringTemplatesCompanion extends UpdateCompanion<RecurringTemplate> {
  final Value<String> id;
  final Value<String> title;
  final Value<int> amountMinor;
  final Value<String> type;
  final Value<String?> subcategoryId;
  final Value<String?> note;
  final Value<int> dayOfMonth;
  final Value<bool> isActive;
  final Value<int> createdAtMillis;
  final Value<int> rowid;
  const RecurringTemplatesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.type = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAtMillis = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringTemplatesCompanion.insert({
    required String id,
    required String title,
    required int amountMinor,
    required String type,
    this.subcategoryId = const Value.absent(),
    this.note = const Value.absent(),
    this.dayOfMonth = const Value.absent(),
    this.isActive = const Value.absent(),
    required int createdAtMillis,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       amountMinor = Value(amountMinor),
       type = Value(type),
       createdAtMillis = Value(createdAtMillis);
  static Insertable<RecurringTemplate> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? amountMinor,
    Expression<String>? type,
    Expression<String>? subcategoryId,
    Expression<String>? note,
    Expression<int>? dayOfMonth,
    Expression<bool>? isActive,
    Expression<int>? createdAtMillis,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (type != null) 'type': type,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (note != null) 'note': note,
      if (dayOfMonth != null) 'day_of_month': dayOfMonth,
      if (isActive != null) 'is_active': isActive,
      if (createdAtMillis != null) 'created_at_millis': createdAtMillis,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<int>? amountMinor,
    Value<String>? type,
    Value<String?>? subcategoryId,
    Value<String?>? note,
    Value<int>? dayOfMonth,
    Value<bool>? isActive,
    Value<int>? createdAtMillis,
    Value<int>? rowid,
  }) {
    return RecurringTemplatesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      amountMinor: amountMinor ?? this.amountMinor,
      type: type ?? this.type,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      note: note ?? this.note,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      isActive: isActive ?? this.isActive,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (dayOfMonth.present) {
      map['day_of_month'] = Variable<int>(dayOfMonth.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAtMillis.present) {
      map['created_at_millis'] = Variable<int>(createdAtMillis.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('type: $type, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('note: $note, ')
          ..write('dayOfMonth: $dayOfMonth, ')
          ..write('isActive: $isActive, ')
          ..write('createdAtMillis: $createdAtMillis, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringAppliedTable extends RecurringApplied
    with TableInfo<$RecurringAppliedTable, RecurringAppliedRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringAppliedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _templateIdMeta = const VerificationMeta(
    'templateId',
  );
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
    'template_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recurring_templates (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _monthIdMeta = const VerificationMeta(
    'monthId',
  );
  @override
  late final GeneratedColumn<String> monthId = GeneratedColumn<String>(
    'month_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appliedAtMillisMeta = const VerificationMeta(
    'appliedAtMillis',
  );
  @override
  late final GeneratedColumn<int> appliedAtMillis = GeneratedColumn<int>(
    'applied_at_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    templateId,
    monthId,
    appliedAtMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_applied';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringAppliedRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('template_id')) {
      context.handle(
        _templateIdMeta,
        templateId.isAcceptableOrUnknown(data['template_id']!, _templateIdMeta),
      );
    } else if (isInserting) {
      context.missing(_templateIdMeta);
    }
    if (data.containsKey('month_id')) {
      context.handle(
        _monthIdMeta,
        monthId.isAcceptableOrUnknown(data['month_id']!, _monthIdMeta),
      );
    } else if (isInserting) {
      context.missing(_monthIdMeta);
    }
    if (data.containsKey('applied_at_millis')) {
      context.handle(
        _appliedAtMillisMeta,
        appliedAtMillis.isAcceptableOrUnknown(
          data['applied_at_millis']!,
          _appliedAtMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_appliedAtMillisMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringAppliedRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringAppliedRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      templateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_id'],
      )!,
      monthId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_id'],
      )!,
      appliedAtMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}applied_at_millis'],
      )!,
    );
  }

  @override
  $RecurringAppliedTable createAlias(String alias) {
    return $RecurringAppliedTable(attachedDatabase, alias);
  }
}

class RecurringAppliedRow extends DataClass
    implements Insertable<RecurringAppliedRow> {
  final int id;
  final String templateId;
  final String monthId;
  final int appliedAtMillis;
  const RecurringAppliedRow({
    required this.id,
    required this.templateId,
    required this.monthId,
    required this.appliedAtMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['template_id'] = Variable<String>(templateId);
    map['month_id'] = Variable<String>(monthId);
    map['applied_at_millis'] = Variable<int>(appliedAtMillis);
    return map;
  }

  RecurringAppliedCompanion toCompanion(bool nullToAbsent) {
    return RecurringAppliedCompanion(
      id: Value(id),
      templateId: Value(templateId),
      monthId: Value(monthId),
      appliedAtMillis: Value(appliedAtMillis),
    );
  }

  factory RecurringAppliedRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringAppliedRow(
      id: serializer.fromJson<int>(json['id']),
      templateId: serializer.fromJson<String>(json['templateId']),
      monthId: serializer.fromJson<String>(json['monthId']),
      appliedAtMillis: serializer.fromJson<int>(json['appliedAtMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'templateId': serializer.toJson<String>(templateId),
      'monthId': serializer.toJson<String>(monthId),
      'appliedAtMillis': serializer.toJson<int>(appliedAtMillis),
    };
  }

  RecurringAppliedRow copyWith({
    int? id,
    String? templateId,
    String? monthId,
    int? appliedAtMillis,
  }) => RecurringAppliedRow(
    id: id ?? this.id,
    templateId: templateId ?? this.templateId,
    monthId: monthId ?? this.monthId,
    appliedAtMillis: appliedAtMillis ?? this.appliedAtMillis,
  );
  RecurringAppliedRow copyWithCompanion(RecurringAppliedCompanion data) {
    return RecurringAppliedRow(
      id: data.id.present ? data.id.value : this.id,
      templateId: data.templateId.present
          ? data.templateId.value
          : this.templateId,
      monthId: data.monthId.present ? data.monthId.value : this.monthId,
      appliedAtMillis: data.appliedAtMillis.present
          ? data.appliedAtMillis.value
          : this.appliedAtMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringAppliedRow(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('monthId: $monthId, ')
          ..write('appliedAtMillis: $appliedAtMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, templateId, monthId, appliedAtMillis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringAppliedRow &&
          other.id == this.id &&
          other.templateId == this.templateId &&
          other.monthId == this.monthId &&
          other.appliedAtMillis == this.appliedAtMillis);
}

class RecurringAppliedCompanion extends UpdateCompanion<RecurringAppliedRow> {
  final Value<int> id;
  final Value<String> templateId;
  final Value<String> monthId;
  final Value<int> appliedAtMillis;
  const RecurringAppliedCompanion({
    this.id = const Value.absent(),
    this.templateId = const Value.absent(),
    this.monthId = const Value.absent(),
    this.appliedAtMillis = const Value.absent(),
  });
  RecurringAppliedCompanion.insert({
    this.id = const Value.absent(),
    required String templateId,
    required String monthId,
    required int appliedAtMillis,
  }) : templateId = Value(templateId),
       monthId = Value(monthId),
       appliedAtMillis = Value(appliedAtMillis);
  static Insertable<RecurringAppliedRow> custom({
    Expression<int>? id,
    Expression<String>? templateId,
    Expression<String>? monthId,
    Expression<int>? appliedAtMillis,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (templateId != null) 'template_id': templateId,
      if (monthId != null) 'month_id': monthId,
      if (appliedAtMillis != null) 'applied_at_millis': appliedAtMillis,
    });
  }

  RecurringAppliedCompanion copyWith({
    Value<int>? id,
    Value<String>? templateId,
    Value<String>? monthId,
    Value<int>? appliedAtMillis,
  }) {
    return RecurringAppliedCompanion(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      monthId: monthId ?? this.monthId,
      appliedAtMillis: appliedAtMillis ?? this.appliedAtMillis,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (monthId.present) {
      map['month_id'] = Variable<String>(monthId.value);
    }
    if (appliedAtMillis.present) {
      map['applied_at_millis'] = Variable<int>(appliedAtMillis.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringAppliedCompanion(')
          ..write('id: $id, ')
          ..write('templateId: $templateId, ')
          ..write('monthId: $monthId, ')
          ..write('appliedAtMillis: $appliedAtMillis')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoryNodesTable categoryNodes = $CategoryNodesTable(this);
  late final $BudgetMonthsTable budgetMonths = $BudgetMonthsTable(this);
  late final $BudgetLimitsTable budgetLimits = $BudgetLimitsTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $RecurringTemplatesTable recurringTemplates =
      $RecurringTemplatesTable(this);
  late final $RecurringAppliedTable recurringApplied = $RecurringAppliedTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categoryNodes,
    budgetMonths,
    budgetLimits,
    transactions,
    recurringTemplates,
    recurringApplied,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'budget_months',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('budget_limits', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'category_nodes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('budget_limits', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recurring_templates',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recurring_applied', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CategoryNodesTableCreateCompanionBuilder =
    CategoryNodesCompanion Function({
      Value<String> id,
      required String name,
      required String type,
      Value<String?> parentId,
      Value<bool> archived,
      Value<int> sortOrder,
      Value<String?> icon,
      Value<int?> color,
      Value<int> rowid,
    });
typedef $$CategoryNodesTableUpdateCompanionBuilder =
    CategoryNodesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String?> parentId,
      Value<bool> archived,
      Value<int> sortOrder,
      Value<String?> icon,
      Value<int?> color,
      Value<int> rowid,
    });

final class $$CategoryNodesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoryNodesTable, CategoryNode> {
  $$CategoryNodesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$BudgetLimitsTable, List<BudgetLimit>>
  _budgetLimitsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.budgetLimits,
    aliasName: $_aliasNameGenerator(
      db.categoryNodes.id,
      db.budgetLimits.nodeId,
    ),
  );

  $$BudgetLimitsTableProcessedTableManager get budgetLimitsRefs {
    final manager = $$BudgetLimitsTableTableManager(
      $_db,
      $_db.budgetLimits,
    ).filter((f) => f.nodeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetLimitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionsTable, List<Transaction>>
  _transactionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactions,
    aliasName: $_aliasNameGenerator(
      db.categoryNodes.id,
      db.transactions.subcategoryId,
    ),
  );

  $$TransactionsTableProcessedTableManager get transactionsRefs {
    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.subcategoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_transactionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecurringTemplatesTable, List<RecurringTemplate>>
  _recurringTemplatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recurringTemplates,
        aliasName: $_aliasNameGenerator(
          db.categoryNodes.id,
          db.recurringTemplates.subcategoryId,
        ),
      );

  $$RecurringTemplatesTableProcessedTableManager get recurringTemplatesRefs {
    final manager = $$RecurringTemplatesTableTableManager(
      $_db,
      $_db.recurringTemplates,
    ).filter((f) => f.subcategoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recurringTemplatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoryNodesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryNodesTable> {
  $$CategoryNodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> budgetLimitsRefs(
    Expression<bool> Function($$BudgetLimitsTableFilterComposer f) f,
  ) {
    final $$BudgetLimitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetLimits,
      getReferencedColumn: (t) => t.nodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetLimitsTableFilterComposer(
            $db: $db,
            $table: $db.budgetLimits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionsRefs(
    Expression<bool> Function($$TransactionsTableFilterComposer f) f,
  ) {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.subcategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recurringTemplatesRefs(
    Expression<bool> Function($$RecurringTemplatesTableFilterComposer f) f,
  ) {
    final $$RecurringTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringTemplates,
      getReferencedColumn: (t) => t.subcategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.recurringTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoryNodesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryNodesTable> {
  $$CategoryNodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoryNodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryNodesTable> {
  $$CategoryNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  Expression<T> budgetLimitsRefs<T extends Object>(
    Expression<T> Function($$BudgetLimitsTableAnnotationComposer a) f,
  ) {
    final $$BudgetLimitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetLimits,
      getReferencedColumn: (t) => t.nodeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetLimitsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgetLimits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionsRefs<T extends Object>(
    Expression<T> Function($$TransactionsTableAnnotationComposer a) f,
  ) {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.subcategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recurringTemplatesRefs<T extends Object>(
    Expression<T> Function($$RecurringTemplatesTableAnnotationComposer a) f,
  ) {
    final $$RecurringTemplatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.recurringTemplates,
          getReferencedColumn: (t) => t.subcategoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringTemplatesTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoryNodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryNodesTable,
          CategoryNode,
          $$CategoryNodesTableFilterComposer,
          $$CategoryNodesTableOrderingComposer,
          $$CategoryNodesTableAnnotationComposer,
          $$CategoryNodesTableCreateCompanionBuilder,
          $$CategoryNodesTableUpdateCompanionBuilder,
          (CategoryNode, $$CategoryNodesTableReferences),
          CategoryNode,
          PrefetchHooks Function({
            bool budgetLimitsRefs,
            bool transactionsRefs,
            bool recurringTemplatesRefs,
          })
        > {
  $$CategoryNodesTableTableManager(_$AppDatabase db, $CategoryNodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryNodesCompanion(
                id: id,
                name: name,
                type: type,
                parentId: parentId,
                archived: archived,
                sortOrder: sortOrder,
                icon: icon,
                color: color,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                required String type,
                Value<String?> parentId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryNodesCompanion.insert(
                id: id,
                name: name,
                type: type,
                parentId: parentId,
                archived: archived,
                sortOrder: sortOrder,
                icon: icon,
                color: color,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoryNodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                budgetLimitsRefs = false,
                transactionsRefs = false,
                recurringTemplatesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (budgetLimitsRefs) db.budgetLimits,
                    if (transactionsRefs) db.transactions,
                    if (recurringTemplatesRefs) db.recurringTemplates,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (budgetLimitsRefs)
                        await $_getPrefetchedData<
                          CategoryNode,
                          $CategoryNodesTable,
                          BudgetLimit
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryNodesTableReferences
                              ._budgetLimitsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryNodesTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetLimitsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.nodeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionsRefs)
                        await $_getPrefetchedData<
                          CategoryNode,
                          $CategoryNodesTable,
                          Transaction
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryNodesTableReferences
                              ._transactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryNodesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subcategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recurringTemplatesRefs)
                        await $_getPrefetchedData<
                          CategoryNode,
                          $CategoryNodesTable,
                          RecurringTemplate
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryNodesTableReferences
                              ._recurringTemplatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryNodesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringTemplatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subcategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoryNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryNodesTable,
      CategoryNode,
      $$CategoryNodesTableFilterComposer,
      $$CategoryNodesTableOrderingComposer,
      $$CategoryNodesTableAnnotationComposer,
      $$CategoryNodesTableCreateCompanionBuilder,
      $$CategoryNodesTableUpdateCompanionBuilder,
      (CategoryNode, $$CategoryNodesTableReferences),
      CategoryNode,
      PrefetchHooks Function({
        bool budgetLimitsRefs,
        bool transactionsRefs,
        bool recurringTemplatesRefs,
      })
    >;
typedef $$BudgetMonthsTableCreateCompanionBuilder =
    BudgetMonthsCompanion Function({
      required String id,
      Value<String> currency,
      Value<int> totalBudgetMinor,
      Value<int> savingTargetMinor,
      Value<int> createdAt,
      Value<int> rowid,
    });
typedef $$BudgetMonthsTableUpdateCompanionBuilder =
    BudgetMonthsCompanion Function({
      Value<String> id,
      Value<String> currency,
      Value<int> totalBudgetMinor,
      Value<int> savingTargetMinor,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$BudgetMonthsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetMonthsTable, BudgetMonth> {
  $$BudgetMonthsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BudgetLimitsTable, List<BudgetLimit>>
  _budgetLimitsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.budgetLimits,
    aliasName: $_aliasNameGenerator(
      db.budgetMonths.id,
      db.budgetLimits.budgetMonthId,
    ),
  );

  $$BudgetLimitsTableProcessedTableManager get budgetLimitsRefs {
    final manager = $$BudgetLimitsTableTableManager(
      $_db,
      $_db.budgetLimits,
    ).filter((f) => f.budgetMonthId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetLimitsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BudgetMonthsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetMonthsTable> {
  $$BudgetMonthsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBudgetMinor => $composableBuilder(
    column: $table.totalBudgetMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savingTargetMinor => $composableBuilder(
    column: $table.savingTargetMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> budgetLimitsRefs(
    Expression<bool> Function($$BudgetLimitsTableFilterComposer f) f,
  ) {
    final $$BudgetLimitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetLimits,
      getReferencedColumn: (t) => t.budgetMonthId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetLimitsTableFilterComposer(
            $db: $db,
            $table: $db.budgetLimits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BudgetMonthsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetMonthsTable> {
  $$BudgetMonthsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBudgetMinor => $composableBuilder(
    column: $table.totalBudgetMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savingTargetMinor => $composableBuilder(
    column: $table.savingTargetMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetMonthsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetMonthsTable> {
  $$BudgetMonthsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get totalBudgetMinor => $composableBuilder(
    column: $table.totalBudgetMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get savingTargetMinor => $composableBuilder(
    column: $table.savingTargetMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> budgetLimitsRefs<T extends Object>(
    Expression<T> Function($$BudgetLimitsTableAnnotationComposer a) f,
  ) {
    final $$BudgetLimitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetLimits,
      getReferencedColumn: (t) => t.budgetMonthId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetLimitsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgetLimits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BudgetMonthsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetMonthsTable,
          BudgetMonth,
          $$BudgetMonthsTableFilterComposer,
          $$BudgetMonthsTableOrderingComposer,
          $$BudgetMonthsTableAnnotationComposer,
          $$BudgetMonthsTableCreateCompanionBuilder,
          $$BudgetMonthsTableUpdateCompanionBuilder,
          (BudgetMonth, $$BudgetMonthsTableReferences),
          BudgetMonth,
          PrefetchHooks Function({bool budgetLimitsRefs})
        > {
  $$BudgetMonthsTableTableManager(_$AppDatabase db, $BudgetMonthsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetMonthsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetMonthsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetMonthsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> totalBudgetMinor = const Value.absent(),
                Value<int> savingTargetMinor = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetMonthsCompanion(
                id: id,
                currency: currency,
                totalBudgetMinor: totalBudgetMinor,
                savingTargetMinor: savingTargetMinor,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> currency = const Value.absent(),
                Value<int> totalBudgetMinor = const Value.absent(),
                Value<int> savingTargetMinor = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetMonthsCompanion.insert(
                id: id,
                currency: currency,
                totalBudgetMinor: totalBudgetMinor,
                savingTargetMinor: savingTargetMinor,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BudgetMonthsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({budgetLimitsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (budgetLimitsRefs) db.budgetLimits],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (budgetLimitsRefs)
                    await $_getPrefetchedData<
                      BudgetMonth,
                      $BudgetMonthsTable,
                      BudgetLimit
                    >(
                      currentTable: table,
                      referencedTable: $$BudgetMonthsTableReferences
                          ._budgetLimitsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BudgetMonthsTableReferences(
                            db,
                            table,
                            p0,
                          ).budgetLimitsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.budgetMonthId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BudgetMonthsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetMonthsTable,
      BudgetMonth,
      $$BudgetMonthsTableFilterComposer,
      $$BudgetMonthsTableOrderingComposer,
      $$BudgetMonthsTableAnnotationComposer,
      $$BudgetMonthsTableCreateCompanionBuilder,
      $$BudgetMonthsTableUpdateCompanionBuilder,
      (BudgetMonth, $$BudgetMonthsTableReferences),
      BudgetMonth,
      PrefetchHooks Function({bool budgetLimitsRefs})
    >;
typedef $$BudgetLimitsTableCreateCompanionBuilder =
    BudgetLimitsCompanion Function({
      Value<String> id,
      required String budgetMonthId,
      required String nodeId,
      required int limitMinor,
      Value<int> rowid,
    });
typedef $$BudgetLimitsTableUpdateCompanionBuilder =
    BudgetLimitsCompanion Function({
      Value<String> id,
      Value<String> budgetMonthId,
      Value<String> nodeId,
      Value<int> limitMinor,
      Value<int> rowid,
    });

final class $$BudgetLimitsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetLimitsTable, BudgetLimit> {
  $$BudgetLimitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BudgetMonthsTable _budgetMonthIdTable(_$AppDatabase db) =>
      db.budgetMonths.createAlias(
        $_aliasNameGenerator(db.budgetLimits.budgetMonthId, db.budgetMonths.id),
      );

  $$BudgetMonthsTableProcessedTableManager get budgetMonthId {
    final $_column = $_itemColumn<String>('budget_month_id')!;

    final manager = $$BudgetMonthsTableTableManager(
      $_db,
      $_db.budgetMonths,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_budgetMonthIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoryNodesTable _nodeIdTable(_$AppDatabase db) =>
      db.categoryNodes.createAlias(
        $_aliasNameGenerator(db.budgetLimits.nodeId, db.categoryNodes.id),
      );

  $$CategoryNodesTableProcessedTableManager get nodeId {
    final $_column = $_itemColumn<String>('node_id')!;

    final manager = $$CategoryNodesTableTableManager(
      $_db,
      $_db.categoryNodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_nodeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetLimitsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetLimitsTable> {
  $$BudgetLimitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get limitMinor => $composableBuilder(
    column: $table.limitMinor,
    builder: (column) => ColumnFilters(column),
  );

  $$BudgetMonthsTableFilterComposer get budgetMonthId {
    final $$BudgetMonthsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetMonthId,
      referencedTable: $db.budgetMonths,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetMonthsTableFilterComposer(
            $db: $db,
            $table: $db.budgetMonths,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryNodesTableFilterComposer get nodeId {
    final $$CategoryNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableFilterComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetLimitsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetLimitsTable> {
  $$BudgetLimitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get limitMinor => $composableBuilder(
    column: $table.limitMinor,
    builder: (column) => ColumnOrderings(column),
  );

  $$BudgetMonthsTableOrderingComposer get budgetMonthId {
    final $$BudgetMonthsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetMonthId,
      referencedTable: $db.budgetMonths,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetMonthsTableOrderingComposer(
            $db: $db,
            $table: $db.budgetMonths,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryNodesTableOrderingComposer get nodeId {
    final $$CategoryNodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetLimitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetLimitsTable> {
  $$BudgetLimitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get limitMinor => $composableBuilder(
    column: $table.limitMinor,
    builder: (column) => column,
  );

  $$BudgetMonthsTableAnnotationComposer get budgetMonthId {
    final $$BudgetMonthsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetMonthId,
      referencedTable: $db.budgetMonths,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetMonthsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgetMonths,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryNodesTableAnnotationComposer get nodeId {
    final $$CategoryNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.nodeId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetLimitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetLimitsTable,
          BudgetLimit,
          $$BudgetLimitsTableFilterComposer,
          $$BudgetLimitsTableOrderingComposer,
          $$BudgetLimitsTableAnnotationComposer,
          $$BudgetLimitsTableCreateCompanionBuilder,
          $$BudgetLimitsTableUpdateCompanionBuilder,
          (BudgetLimit, $$BudgetLimitsTableReferences),
          BudgetLimit,
          PrefetchHooks Function({bool budgetMonthId, bool nodeId})
        > {
  $$BudgetLimitsTableTableManager(_$AppDatabase db, $BudgetLimitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetLimitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetLimitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetLimitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> budgetMonthId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<int> limitMinor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetLimitsCompanion(
                id: id,
                budgetMonthId: budgetMonthId,
                nodeId: nodeId,
                limitMinor: limitMinor,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String budgetMonthId,
                required String nodeId,
                required int limitMinor,
                Value<int> rowid = const Value.absent(),
              }) => BudgetLimitsCompanion.insert(
                id: id,
                budgetMonthId: budgetMonthId,
                nodeId: nodeId,
                limitMinor: limitMinor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BudgetLimitsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({budgetMonthId = false, nodeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (budgetMonthId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.budgetMonthId,
                                referencedTable: $$BudgetLimitsTableReferences
                                    ._budgetMonthIdTable(db),
                                referencedColumn: $$BudgetLimitsTableReferences
                                    ._budgetMonthIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (nodeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.nodeId,
                                referencedTable: $$BudgetLimitsTableReferences
                                    ._nodeIdTable(db),
                                referencedColumn: $$BudgetLimitsTableReferences
                                    ._nodeIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BudgetLimitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetLimitsTable,
      BudgetLimit,
      $$BudgetLimitsTableFilterComposer,
      $$BudgetLimitsTableOrderingComposer,
      $$BudgetLimitsTableAnnotationComposer,
      $$BudgetLimitsTableCreateCompanionBuilder,
      $$BudgetLimitsTableUpdateCompanionBuilder,
      (BudgetLimit, $$BudgetLimitsTableReferences),
      BudgetLimit,
      PrefetchHooks Function({bool budgetMonthId, bool nodeId})
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      required String type,
      required int amountMinor,
      required int dateMillis,
      required String monthId,
      Value<String?> subcategoryId,
      Value<String?> note,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<int> amountMinor,
      Value<int> dateMillis,
      Value<String> monthId,
      Value<String?> subcategoryId,
      Value<String?> note,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CategoryNodesTable _subcategoryIdTable(_$AppDatabase db) =>
      db.categoryNodes.createAlias(
        $_aliasNameGenerator(
          db.transactions.subcategoryId,
          db.categoryNodes.id,
        ),
      );

  $$CategoryNodesTableProcessedTableManager? get subcategoryId {
    final $_column = $_itemColumn<String>('subcategory_id');
    if ($_column == null) return null;
    final manager = $$CategoryNodesTableTableManager(
      $_db,
      $_db.categoryNodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subcategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateMillis => $composableBuilder(
    column: $table.dateMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthId => $composableBuilder(
    column: $table.monthId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryNodesTableFilterComposer get subcategoryId {
    final $$CategoryNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableFilterComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateMillis => $composableBuilder(
    column: $table.dateMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthId => $composableBuilder(
    column: $table.monthId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryNodesTableOrderingComposer get subcategoryId {
    final $$CategoryNodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dateMillis => $composableBuilder(
    column: $table.dateMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get monthId =>
      $composableBuilder(column: $table.monthId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CategoryNodesTableAnnotationComposer get subcategoryId {
    final $$CategoryNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({bool subcategoryId})
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<int> dateMillis = const Value.absent(),
                Value<String> monthId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                type: type,
                amountMinor: amountMinor,
                dateMillis: dateMillis,
                monthId: monthId,
                subcategoryId: subcategoryId,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String type,
                required int amountMinor,
                required int dateMillis,
                required String monthId,
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                type: type,
                amountMinor: amountMinor,
                dateMillis: dateMillis,
                monthId: monthId,
                subcategoryId: subcategoryId,
                note: note,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({subcategoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (subcategoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.subcategoryId,
                                referencedTable: $$TransactionsTableReferences
                                    ._subcategoryIdTable(db),
                                referencedColumn: $$TransactionsTableReferences
                                    ._subcategoryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({bool subcategoryId})
    >;
typedef $$RecurringTemplatesTableCreateCompanionBuilder =
    RecurringTemplatesCompanion Function({
      required String id,
      required String title,
      required int amountMinor,
      required String type,
      Value<String?> subcategoryId,
      Value<String?> note,
      Value<int> dayOfMonth,
      Value<bool> isActive,
      required int createdAtMillis,
      Value<int> rowid,
    });
typedef $$RecurringTemplatesTableUpdateCompanionBuilder =
    RecurringTemplatesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<int> amountMinor,
      Value<String> type,
      Value<String?> subcategoryId,
      Value<String?> note,
      Value<int> dayOfMonth,
      Value<bool> isActive,
      Value<int> createdAtMillis,
      Value<int> rowid,
    });

final class $$RecurringTemplatesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RecurringTemplatesTable,
          RecurringTemplate
        > {
  $$RecurringTemplatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoryNodesTable _subcategoryIdTable(_$AppDatabase db) =>
      db.categoryNodes.createAlias(
        $_aliasNameGenerator(
          db.recurringTemplates.subcategoryId,
          db.categoryNodes.id,
        ),
      );

  $$CategoryNodesTableProcessedTableManager? get subcategoryId {
    final $_column = $_itemColumn<String>('subcategory_id');
    if ($_column == null) return null;
    final manager = $$CategoryNodesTableTableManager(
      $_db,
      $_db.categoryNodes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subcategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RecurringAppliedTable, List<RecurringAppliedRow>>
  _recurringAppliedRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recurringApplied,
    aliasName: $_aliasNameGenerator(
      db.recurringTemplates.id,
      db.recurringApplied.templateId,
    ),
  );

  $$RecurringAppliedTableProcessedTableManager get recurringAppliedRefs {
    final manager = $$RecurringAppliedTableTableManager(
      $_db,
      $_db.recurringApplied,
    ).filter((f) => f.templateId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recurringAppliedRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecurringTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringTemplatesTable> {
  $$RecurringTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryNodesTableFilterComposer get subcategoryId {
    final $$CategoryNodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableFilterComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> recurringAppliedRefs(
    Expression<bool> Function($$RecurringAppliedTableFilterComposer f) f,
  ) {
    final $$RecurringAppliedTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringApplied,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringAppliedTableFilterComposer(
            $db: $db,
            $table: $db.recurringApplied,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecurringTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringTemplatesTable> {
  $$RecurringTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryNodesTableOrderingComposer get subcategoryId {
    final $$CategoryNodesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringTemplatesTable> {
  $$RecurringTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
    column: $table.amountMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get dayOfMonth => $composableBuilder(
    column: $table.dayOfMonth,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAtMillis => $composableBuilder(
    column: $table.createdAtMillis,
    builder: (column) => column,
  );

  $$CategoryNodesTableAnnotationComposer get subcategoryId {
    final $$CategoryNodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryNodes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryNodesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryNodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> recurringAppliedRefs<T extends Object>(
    Expression<T> Function($$RecurringAppliedTableAnnotationComposer a) f,
  ) {
    final $$RecurringAppliedTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recurringApplied,
      getReferencedColumn: (t) => t.templateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringAppliedTableAnnotationComposer(
            $db: $db,
            $table: $db.recurringApplied,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecurringTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringTemplatesTable,
          RecurringTemplate,
          $$RecurringTemplatesTableFilterComposer,
          $$RecurringTemplatesTableOrderingComposer,
          $$RecurringTemplatesTableAnnotationComposer,
          $$RecurringTemplatesTableCreateCompanionBuilder,
          $$RecurringTemplatesTableUpdateCompanionBuilder,
          (RecurringTemplate, $$RecurringTemplatesTableReferences),
          RecurringTemplate,
          PrefetchHooks Function({
            bool subcategoryId,
            bool recurringAppliedRefs,
          })
        > {
  $$RecurringTemplatesTableTableManager(
    _$AppDatabase db,
    $RecurringTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> amountMinor = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> dayOfMonth = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAtMillis = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringTemplatesCompanion(
                id: id,
                title: title,
                amountMinor: amountMinor,
                type: type,
                subcategoryId: subcategoryId,
                note: note,
                dayOfMonth: dayOfMonth,
                isActive: isActive,
                createdAtMillis: createdAtMillis,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required int amountMinor,
                required String type,
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> dayOfMonth = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required int createdAtMillis,
                Value<int> rowid = const Value.absent(),
              }) => RecurringTemplatesCompanion.insert(
                id: id,
                title: title,
                amountMinor: amountMinor,
                type: type,
                subcategoryId: subcategoryId,
                note: note,
                dayOfMonth: dayOfMonth,
                isActive: isActive,
                createdAtMillis: createdAtMillis,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecurringTemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({subcategoryId = false, recurringAppliedRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recurringAppliedRefs) db.recurringApplied,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (subcategoryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.subcategoryId,
                                    referencedTable:
                                        $$RecurringTemplatesTableReferences
                                            ._subcategoryIdTable(db),
                                    referencedColumn:
                                        $$RecurringTemplatesTableReferences
                                            ._subcategoryIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recurringAppliedRefs)
                        await $_getPrefetchedData<
                          RecurringTemplate,
                          $RecurringTemplatesTable,
                          RecurringAppliedRow
                        >(
                          currentTable: table,
                          referencedTable: $$RecurringTemplatesTableReferences
                              ._recurringAppliedRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecurringTemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).recurringAppliedRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.templateId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecurringTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringTemplatesTable,
      RecurringTemplate,
      $$RecurringTemplatesTableFilterComposer,
      $$RecurringTemplatesTableOrderingComposer,
      $$RecurringTemplatesTableAnnotationComposer,
      $$RecurringTemplatesTableCreateCompanionBuilder,
      $$RecurringTemplatesTableUpdateCompanionBuilder,
      (RecurringTemplate, $$RecurringTemplatesTableReferences),
      RecurringTemplate,
      PrefetchHooks Function({bool subcategoryId, bool recurringAppliedRefs})
    >;
typedef $$RecurringAppliedTableCreateCompanionBuilder =
    RecurringAppliedCompanion Function({
      Value<int> id,
      required String templateId,
      required String monthId,
      required int appliedAtMillis,
    });
typedef $$RecurringAppliedTableUpdateCompanionBuilder =
    RecurringAppliedCompanion Function({
      Value<int> id,
      Value<String> templateId,
      Value<String> monthId,
      Value<int> appliedAtMillis,
    });

final class $$RecurringAppliedTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RecurringAppliedTable,
          RecurringAppliedRow
        > {
  $$RecurringAppliedTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RecurringTemplatesTable _templateIdTable(_$AppDatabase db) =>
      db.recurringTemplates.createAlias(
        $_aliasNameGenerator(
          db.recurringApplied.templateId,
          db.recurringTemplates.id,
        ),
      );

  $$RecurringTemplatesTableProcessedTableManager get templateId {
    final $_column = $_itemColumn<String>('template_id')!;

    final manager = $$RecurringTemplatesTableTableManager(
      $_db,
      $_db.recurringTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecurringAppliedTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringAppliedTable> {
  $$RecurringAppliedTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthId => $composableBuilder(
    column: $table.monthId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get appliedAtMillis => $composableBuilder(
    column: $table.appliedAtMillis,
    builder: (column) => ColumnFilters(column),
  );

  $$RecurringTemplatesTableFilterComposer get templateId {
    final $$RecurringTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.recurringTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.recurringTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringAppliedTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringAppliedTable> {
  $$RecurringAppliedTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthId => $composableBuilder(
    column: $table.monthId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get appliedAtMillis => $composableBuilder(
    column: $table.appliedAtMillis,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecurringTemplatesTableOrderingComposer get templateId {
    final $$RecurringTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateId,
      referencedTable: $db.recurringTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurringTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.recurringTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecurringAppliedTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringAppliedTable> {
  $$RecurringAppliedTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get monthId =>
      $composableBuilder(column: $table.monthId, builder: (column) => column);

  GeneratedColumn<int> get appliedAtMillis => $composableBuilder(
    column: $table.appliedAtMillis,
    builder: (column) => column,
  );

  $$RecurringTemplatesTableAnnotationComposer get templateId {
    final $$RecurringTemplatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.templateId,
          referencedTable: $db.recurringTemplates,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecurringTemplatesTableAnnotationComposer(
                $db: $db,
                $table: $db.recurringTemplates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$RecurringAppliedTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringAppliedTable,
          RecurringAppliedRow,
          $$RecurringAppliedTableFilterComposer,
          $$RecurringAppliedTableOrderingComposer,
          $$RecurringAppliedTableAnnotationComposer,
          $$RecurringAppliedTableCreateCompanionBuilder,
          $$RecurringAppliedTableUpdateCompanionBuilder,
          (RecurringAppliedRow, $$RecurringAppliedTableReferences),
          RecurringAppliedRow,
          PrefetchHooks Function({bool templateId})
        > {
  $$RecurringAppliedTableTableManager(
    _$AppDatabase db,
    $RecurringAppliedTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringAppliedTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringAppliedTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurringAppliedTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> templateId = const Value.absent(),
                Value<String> monthId = const Value.absent(),
                Value<int> appliedAtMillis = const Value.absent(),
              }) => RecurringAppliedCompanion(
                id: id,
                templateId: templateId,
                monthId: monthId,
                appliedAtMillis: appliedAtMillis,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String templateId,
                required String monthId,
                required int appliedAtMillis,
              }) => RecurringAppliedCompanion.insert(
                id: id,
                templateId: templateId,
                monthId: monthId,
                appliedAtMillis: appliedAtMillis,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecurringAppliedTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({templateId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (templateId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.templateId,
                                referencedTable:
                                    $$RecurringAppliedTableReferences
                                        ._templateIdTable(db),
                                referencedColumn:
                                    $$RecurringAppliedTableReferences
                                        ._templateIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecurringAppliedTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringAppliedTable,
      RecurringAppliedRow,
      $$RecurringAppliedTableFilterComposer,
      $$RecurringAppliedTableOrderingComposer,
      $$RecurringAppliedTableAnnotationComposer,
      $$RecurringAppliedTableCreateCompanionBuilder,
      $$RecurringAppliedTableUpdateCompanionBuilder,
      (RecurringAppliedRow, $$RecurringAppliedTableReferences),
      RecurringAppliedRow,
      PrefetchHooks Function({bool templateId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoryNodesTableTableManager get categoryNodes =>
      $$CategoryNodesTableTableManager(_db, _db.categoryNodes);
  $$BudgetMonthsTableTableManager get budgetMonths =>
      $$BudgetMonthsTableTableManager(_db, _db.budgetMonths);
  $$BudgetLimitsTableTableManager get budgetLimits =>
      $$BudgetLimitsTableTableManager(_db, _db.budgetLimits);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$RecurringTemplatesTableTableManager get recurringTemplates =>
      $$RecurringTemplatesTableTableManager(_db, _db.recurringTemplates);
  $$RecurringAppliedTableTableManager get recurringApplied =>
      $$RecurringAppliedTableTableManager(_db, _db.recurringApplied);
}
