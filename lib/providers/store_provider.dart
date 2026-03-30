import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/locations_sheet.dart';

/// Manages the user's selected store. Persisted in SharedPreferences.
class StoreProvider extends ChangeNotifier {
  static const _keyId = 'selected_store_id';
  static const _keyName = 'selected_store_name';

  String? _selectedStoreId;
  String? _selectedStoreName;
  List<ToolorLocation> _stores = [];
  bool _isLoading = false;

  String? get selectedStoreId => _selectedStoreId;
  String? get selectedStoreName => _selectedStoreName;
  List<ToolorLocation> get stores => _stores;
  bool get isLoading => _isLoading;

  /// Initialize: load saved store, fetch stores from API, validate selection.
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _selectedStoreId = prefs.getString(_keyId);
    _selectedStoreName = prefs.getString(_keyName);

    await fetchStores();

    // Validate saved selection still exists
    if (_selectedStoreId != null && _stores.isNotEmpty) {
      final exists = _stores.any((s) => s.id == _selectedStoreId);
      if (!exists) {
        _selectFirst();
      }
    } else if (_stores.isNotEmpty && _selectedStoreId == null) {
      _selectFirst();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch store locations from API.
  Future<void> fetchStores() async {
    try {
      final response = await ApiService.dio.get('/api/v1/locations');
      final data = response.data;
      final List<dynamic> items =
          data is List ? data : (data['items'] as List? ?? data as List);
      _stores = items
          .map((json) => ToolorLocation.fromJson(json as Map<String, dynamic>))
          .where((loc) => loc.type == LocationType.store && loc.id != null)
          .toList();
    } catch (e) {
      debugPrint('[StoreProvider] fetchStores error: $e');
    }
  }

  /// Select a store. Persists to SharedPreferences and notifies listeners.
  Future<void> selectStore(ToolorLocation store) async {
    if (store.id == null) return;
    _selectedStoreId = store.id;
    _selectedStoreName = store.name;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyId, store.id!);
    await prefs.setString(_keyName, store.name);
  }

  void _selectFirst() {
    if (_stores.isNotEmpty) {
      final first = _stores.first;
      _selectedStoreId = first.id;
      _selectedStoreName = first.name;
      _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedStoreId != null) {
      await prefs.setString(_keyId, _selectedStoreId!);
    }
    if (_selectedStoreName != null) {
      await prefs.setString(_keyName, _selectedStoreName!);
    }
  }
}
