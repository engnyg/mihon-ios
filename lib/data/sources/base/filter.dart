/// Mirrors Mihon's Filter hierarchy for source-specific search filters.

sealed class Filter<T> {
  Filter({required this.name, required this.state});
  final String name;
  T state;
}

class TextFilter extends Filter<String> {
  TextFilter({required super.name}) : super(state: '');
}

class SelectFilter extends Filter<int> {
  SelectFilter({required super.name, required this.values}) : super(state: 0);
  final List<String> values;
  String get selected => values[state];
}

class TriStateFilter extends Filter<int> {
  TriStateFilter({required super.name}) : super(state: 0);
  // 0 = ignore, 1 = include, 2 = exclude
  bool get isIncluded => state == 1;
  bool get isExcluded => state == 2;
}

class CheckBoxFilter extends Filter<bool> {
  CheckBoxFilter({required super.name}) : super(state: false);
}

class GroupFilter extends Filter<List<Filter<dynamic>>> {
  GroupFilter({required super.name, required List<Filter<dynamic>> filters})
      : super(state: filters);
}

class FilterList {
  const FilterList(this.filters);
  final List<Filter<dynamic>> filters;
  bool get isEmpty => filters.isEmpty;
}
