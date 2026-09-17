import 'package:flutter/material.dart';
import 'dashboard_enums.dart';
import 'dashboard_message.dart';
import 'message_trace.dart';

class DashboardOpportunity extends DashboardMessage {
  @override
  final String id;
  @override
  final String title;
  @override
  final String message;
  @override
  final IconData icon;
  @override
  final MessageTrace trace;
  final String expectedBenefit;
  final String actionDescription;
  final double? impactAmount;
  final int? impactDays;
  final String? relatedCategoryKey;
  final String? relatedGoalId;
  final String? relatedBudgetId;

  DashboardOpportunity({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.trace,
    required this.expectedBenefit,
    required this.actionDescription,
    this.impactAmount,
    this.impactDays,
    this.relatedCategoryKey,
    this.relatedGoalId,
    this.relatedBudgetId,
  });

  @override
  MessageCategory get category => MessageCategory.opportunity;
}
