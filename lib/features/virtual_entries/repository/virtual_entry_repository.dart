import 'dart:developer';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/service/local_db_service/local_db_service.dart';
import '../../../core/service/local_storage_service.dart';
import '../../../core/service/snackbar_service.dart';
import '../models/virtual_entry_model.dart';

class VirtualEntryRepository {
  final DatabaseHelper _dbService = DatabaseHelper.instance;

  int get _masterAccountId {
    final accountIdString = LocalStorageService.instance.accountId;
    return accountIdString;
  }

  Future<List<VirtualEntryModel>> getVirtualEntries() async {
    final accountId = _masterAccountId;
    if (accountId == -1) return [];

    try {
      final List<Map<String, dynamic>> maps = await _dbService
          .getVirtualEntries(accountId);
      return maps.map((e) => VirtualEntryModel.fromMap(e)).toList();
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('Error getting virtual entries: $e');
      SnackbarService.showError(
        title: 'Database Error',
        message: 'Failed to load virtual entries.',
      );
      return [];
    }
  }

  Future<bool> insertVirtualEntry(VirtualEntryModel entry) async {
    try {
      final accountId = _masterAccountId;
      if (accountId == -1) return false;

      final data = entry.toMap();
      data['account_id'] = accountId; // ensure scoping

      // Remove nullable PK before insert
      data.remove('virtual_entry_id');

      final id = await _dbService.insertVirtualEntry(data);
      return id > 0;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('Error inserting virtual entry: $e');
      SnackbarService.showError(
        title: 'Database Error',
        message: 'Failed to create virtual entry.',
      );
      return false;
    }
  }

  Future<bool> updateVirtualEntry(VirtualEntryModel entry) async {
    try {
      if (entry.virtualEntryId == null) return false;
      final data = entry.toMap();
      // Maintain account scope
      data['account_id'] = _masterAccountId;

      final result = await _dbService.updateVirtualEntry(
        data,
        entry.virtualEntryId!,
        _masterAccountId,
      );
      return result > 0;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('Error updating virtual entry: $e');
      SnackbarService.showError(
        title: 'Database Error',
        message: 'Failed to update virtual entry.',
      );
      return false;
    }
  }

  Future<bool> softDeleteVirtualEntry(int virtualEntryId) async {
    try {
      final result = await _dbService.softDeleteVirtualEntry(
        virtualEntryId,
        _masterAccountId,
      );
      return result > 0;
    } catch (e, stackTrace) {
      Sentry.captureException(e, stackTrace: stackTrace);
      log('Error deleting virtual entry: $e');
      SnackbarService.showError(
        title: 'Database Error',
        message: 'Failed to delete virtual entry.',
      );
      return false;
    }
  }
}
