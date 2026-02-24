// We will create a "new list" based on the current list provided. A special function will be used inside to format the current list

Map<String, dynamic> formatList(
  List<dynamic> list,
  String format, {
  int itemPerPage = 10,
  int page = 1,
}) {
  final startIndex = (page - 1) * itemPerPage;
  final endIndex = startIndex + itemPerPage;
  final paginatedList = list.sublist(
    startIndex,
    endIndex > list.length ? list.length : endIndex,
  );

  final computedList =
      paginatedList.map((item) {
        if (format.isEmpty) {
          return item.toString();
        }

        return format.replaceAll('{{item}}', item.toString());
      }).toList();

  return {
    'page': page.toString(),
    'totalPages': (list.length / itemPerPage).ceil().toString(),
    'computedList': computedList,
  };
}
