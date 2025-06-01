// We will create a "new list" based on the current list provided. A special function will be used inside to format the current list

Map<String, dynamic> formatList(
  List<dynamic> list,
  dynamic Function(dynamic item) callback,
  {
    int itemPerPage = 10,
    int page = 1,
  }
) {
  final startIndex = (page - 1) * itemPerPage;
  final endIndex = startIndex + itemPerPage;
  final paginatedList = list.sublist(startIndex, endIndex > list.length ? list.length : endIndex);

  return {
    'page': page.toString(),
    'totalPages': (list.length / itemPerPage).ceil().toString(),
    'computedList': paginatedList.map(callback)
  };
}

