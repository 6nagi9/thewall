import 'package:flutter/material.dart';
import 'theme.dart';

class BadgeDef {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  const BadgeDef({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const kBadges = <BadgeDef>[
  BadgeDef(
    id: 'wall_claimed',
    label: 'Wall Owner',
    description: 'Claimed your Wall — your space to grow.',
    icon: Icons.home_outlined,
    color: AppTheme.clay,
  ),
  BadgeDef(
    id: 'first_feedback',
    label: 'First Voice',
    description: 'Gave your first piece of feedback to someone.',
    icon: Icons.rate_review_outlined,
    color: AppTheme.sage,
  ),
  BadgeDef(
    id: 'giver_5',
    label: 'Community Builder',
    description: 'Gave feedback to 5 different people.',
    icon: Icons.people_outline,
    color: AppTheme.clay,
  ),
  BadgeDef(
    id: 'giver_10',
    label: 'Pillar',
    description: 'Gave feedback to 10 different people.',
    icon: Icons.emoji_events_outlined,
    color: AppTheme.gold,
  ),
  BadgeDef(
    id: 'first_review',
    label: 'Getting Known',
    description: 'Received your first piece of feedback.',
    icon: Icons.mark_chat_read_outlined,
    color: AppTheme.sage,
  ),
  BadgeDef(
    id: 'five_reviews',
    label: 'Voice of Many',
    description: 'Received feedback from 5 different people.',
    icon: Icons.forum_outlined,
    color: AppTheme.gold,
  ),
  BadgeDef(
    id: 'open_book',
    label: 'Open Book',
    description: 'Achieved "Very Open" transparency status.',
    icon: Icons.visibility_outlined,
    color: AppTheme.clay,
  ),
  BadgeDef(
    id: 'streak_7',
    label: '7-Day Streak',
    description: 'Stayed active on The Wall 7 days in a row.',
    icon: Icons.local_fire_department_outlined,
    color: AppTheme.flame,
  ),
  BadgeDef(
    id: 'streak_30',
    label: 'Month Strong',
    description: 'Stayed active for 30 days in a row.',
    icon: Icons.whatshot,
    color: AppTheme.flame,
  ),
  BadgeDef(
    id: 'campaign_launched',
    label: 'Growth Seeker',
    description: 'Launched a targeted feedback campaign.',
    icon: Icons.campaign_outlined,
    color: AppTheme.clay,
  ),
];
