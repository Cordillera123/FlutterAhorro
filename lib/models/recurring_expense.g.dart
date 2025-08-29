// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecurringExpense _$RecurringExpenseFromJson(Map<String, dynamic> json) =>
    RecurringExpense(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: $enumDecode(_$ExpenseCategoryEnumMap, json['category']),
      frequency: $enumDecode(_$RecurrenceFrequencyEnumMap, json['frequency']),
      customDays: (json['customDays'] as num?)?.toInt(),
      weekDays: (json['weekDays'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$WeekDayEnumMap, e))
          .toList(),
      monthlyDay: (json['monthlyDay'] as num?)?.toInt(),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastProcessed: json['lastProcessed'] == null
          ? null
          : DateTime.parse(json['lastProcessed'] as String),
    );

Map<String, dynamic> _$RecurringExpenseToJson(RecurringExpense instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'amount': instance.amount,
      'category': _$ExpenseCategoryEnumMap[instance.category]!,
      'frequency': _$RecurrenceFrequencyEnumMap[instance.frequency]!,
      'customDays': instance.customDays,
      'weekDays': instance.weekDays?.map((e) => _$WeekDayEnumMap[e]!).toList(),
      'monthlyDay': instance.monthlyDay,
      'startDate': instance.startDate.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastProcessed': instance.lastProcessed?.toIso8601String(),
    };

const _$ExpenseCategoryEnumMap = {
  ExpenseCategory.transport: 'transport',
  ExpenseCategory.shopping: 'shopping',
  ExpenseCategory.food: 'food',
  ExpenseCategory.entertainment: 'entertainment',
  ExpenseCategory.other: 'other',
};

const _$RecurrenceFrequencyEnumMap = {
  RecurrenceFrequency.daily: 'daily',
  RecurrenceFrequency.weekly: 'weekly',
  RecurrenceFrequency.monthly: 'monthly',
  RecurrenceFrequency.custom: 'custom',
};

const _$WeekDayEnumMap = {
  WeekDay.monday: 'monday',
  WeekDay.tuesday: 'tuesday',
  WeekDay.wednesday: 'wednesday',
  WeekDay.thursday: 'thursday',
  WeekDay.friday: 'friday',
  WeekDay.saturday: 'saturday',
  WeekDay.sunday: 'sunday',
};
