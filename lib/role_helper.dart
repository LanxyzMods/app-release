// role_helper.dart
import 'package:flutter/material.dart';

String _normalize(String role) {
  return role.toLowerCase().replaceAll('_', ' ');
}

/// Mendapatkan level/tingkatan dari sebuah role
int roleLevel(String role) {
  switch (_normalize(role)) {
    case 'developer': return 3;
    case 'partner': return 2;
    case 'reseller': return 1;
    case 'member': return 0;
    default: return -1;
  }
}

/// Label role untuk UI (huruf besar semua)
String roleLabel(String role) {
  switch (_normalize(role)) {
    case 'developer': return 'DEVELOPER';
    case 'partner': return 'partner';
    case 'reseller': return 'RESELLER';
    case 'member': return 'MEMBER';
    default: return role.toUpperCase();
  }
}

/// Role yang dapat dibuat oleh currentRole (dalam bentuk normal)
List<String> creatableRoles(String currentRole) {
  switch (_normalize(currentRole)) {
    case 'developer':
      return ['partner', 'reseller', 'member'];
    case 'partner':
      return ['reseller', 'member'];
    case 'reseller':
      return ['member'];
    default:
      return [];
  }
}

/// Cek apakah currentRole dapat membuat targetRole
bool canCreateRole(String currentRole, String targetRole) {
  final targetNorm = _normalize(targetRole);
  return creatableRoles(currentRole).contains(targetNorm);
}

/// Cek apakah currentRole dapat menghapus targetRole
bool canDeleteUser(String currentRole, String targetRole) {
  final currentLvl = roleLevel(currentRole);
  final targetLvl = roleLevel(targetRole);
  if (targetLvl >= currentLvl) return false;
  // Khusus dev: bisa hapus semua role selain dev sendiri
  if (_normalize(currentRole) == 'dev' && _normalize(targetRole) != 'dev') return true;
  return targetLvl < currentLvl;
}

/// Cek apakah currentRole dapat mengedit (extend durasi) targetRole
bool canEditUser(String currentRole, String targetRole) {
  return canDeleteUser(currentRole, targetRole);
}

/// Maksimal hari yang dapat diberikan oleh currentRole
int maxDays(String currentRole) {
  switch (_normalize(currentRole)) {
    case 'developer': return 9999;
    case 'partner': return 90;
    case 'reseller': return 30;
    default: return 0;
  }
}

/// Daftar semua role (untuk filter dropdown)
List<String> getAllRoles() {
  return ['developer', 'partner', 'reseller', 'member'];
}

/// Mendapatkan role yang lebih tinggi dari role tertentu
List<String> getHigherRoles(String role) {
  final currentLvl = roleLevel(role);
  return getAllRoles().where((r) => roleLevel(r) > currentLvl).toList();
}

/// Mendapatkan role yang lebih rendah dari role tertentu
List<String> getLowerRoles(String role) {
  final currentLvl = roleLevel(role);
  return getAllRoles().where((r) => roleLevel(r) < currentLvl).toList();
}

/// Cek apakah role valid
bool isValidRole(String role) {
  return getAllRoles().contains(_normalize(role));
}

/// Warna role untuk UI
Color getRoleColor(String role) {
  switch (_normalize(role)) {
    case 'developer': return const Color(0xFF9C27B0);
    case 'partner': return const Color(0xFFD4AF37);
    case 'reseller': return const Color(0xFFFF6B35);
    case 'member': return const Color(0xFF9E9E9E);
    default: return const Color(0xFF9E9E9E);
  }
}

/// Ikon role untuk UI
IconData getRoleIcon(String role) {
  switch (_normalize(role)) {
    case 'developer': return Icons.code;
    case 'partner': return Icons.workspace_premium;
    case 'reseller': return Icons.storefront;
    default: return Icons.person;
  }
}

/// Deskripsi role
String getRoleDescription(String role) {
  switch (_normalize(role)) {
    case 'dev': return 'Developer - Akses penuh ke semua fitur';
    case 'partner': return 'Partner - Bisa membuat Admin ke bawah';
    case 'reseller': return 'Reseller - Bisa membuat Member';
    case 'member': return 'Member - Tidak bisa membuat akun';
    default: return 'Role tidak dikenal';
  }
}