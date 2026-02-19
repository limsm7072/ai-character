import 'package:flutter/material.dart';

class RoutinePreset {
  final String name;
  final IconData icon;
  final int startH, startM, endH, endM;
  final bool isAllDay;

  const RoutinePreset(this.name, this.icon, this.startH, this.startM, this.endH, this.endM)
      : isAllDay = false;

  const RoutinePreset.free(this.name, this.icon)
      : startH = 0, startM = 0, endH = 23, endM = 59, isAllDay = true;
}

const routinePresets = <RoutinePreset>[
  // Timed
  RoutinePreset('기상', Icons.wb_sunny_outlined, 7, 0, 7, 30),
  RoutinePreset('아침 운동', Icons.fitness_center, 7, 30, 8, 30),
  RoutinePreset('출근 준비', Icons.work_outline, 8, 0, 8, 30),
  RoutinePreset('오전 집중', Icons.laptop_mac, 9, 0, 12, 0),
  RoutinePreset('점심 식사', Icons.restaurant, 12, 0, 13, 0),
  RoutinePreset('오후 집중', Icons.edit_note, 14, 0, 17, 0),
  RoutinePreset('저녁 운동', Icons.directions_run, 18, 0, 19, 0),
  RoutinePreset('독서', Icons.menu_book, 21, 0, 22, 0),
  RoutinePreset('취침 준비', Icons.bedtime_outlined, 23, 0, 23, 30),
  // Free (allDay)
  RoutinePreset.free('물 마시기', Icons.water_drop_outlined),
  RoutinePreset.free('스트레칭', Icons.self_improvement),
  RoutinePreset.free('비타민 먹기', Icons.medication_outlined),
  RoutinePreset.free('감사일기', Icons.auto_stories),
  RoutinePreset.free('방 정리', Icons.cleaning_services_outlined),
];
