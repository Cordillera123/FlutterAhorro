// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transaction _$TransactionFromJson(Map<String, dynamic> json) => Transaction(
  id: json['id'] as String,
  amount: (json['amount'] as num).toDouble(),
  type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
  description: json['description'] as String,
  date: DateTime.parse(json['date'] as String),
  expenseCategory: $enumDecodeNullable(
    _$ExpenseCategoryEnumMap,
    json['expenseCategory'],
  ),
  incomeCategory: $enumDecodeNullable(
    _$IncomeCategoryEnumMap,
    json['incomeCategory'],
  ),
);

Map<String, dynamic> _$TransactionToJson(Transaction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'amount': instance.amount,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'description': instance.description,
      'date': instance.date.toIso8601String(),
      'expenseCategory': _$ExpenseCategoryEnumMap[instance.expenseCategory],
      'incomeCategory': _$IncomeCategoryEnumMap[instance.incomeCategory],
    };

const _$TransactionTypeEnumMap = {
  TransactionType.income: 'income',
  TransactionType.expense: 'expense',
};

const _$ExpenseCategoryEnumMap = {
  ExpenseCategory.transport: 'transport',
  ExpenseCategory.food: 'food',
  ExpenseCategory.utilities: 'utilities',
  ExpenseCategory.health: 'health',
  ExpenseCategory.education: 'education',
  ExpenseCategory.entertainment: 'entertainment',
  ExpenseCategory.clothing: 'clothing',
  ExpenseCategory.home: 'home',
  ExpenseCategory.technology: 'technology',
  ExpenseCategory.savings: 'savings',
  ExpenseCategory.gifts: 'gifts',
  ExpenseCategory.other: 'other',
};

const _$IncomeCategoryEnumMap = {
  IncomeCategory.salary: 'salary',
  IncomeCategory.extra: 'extra',
  IncomeCategory.gift: 'gift',
  IncomeCategory.other: 'other',
};
