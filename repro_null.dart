void main() {
  try {
    print('Testing Map.from(null)...');
    Map.from(null as dynamic);
  } catch (e) {
    print('Caught error: $e');
  }

  try {
    print('Testing Map<String, dynamic>.from(null)...');
    Map<String, dynamic>.from(null as dynamic);
  } catch (e) {
    print('Caught error: $e');
  }

  try {
    print('Testing cast on null...');
    (null as dynamic).cast<String, dynamic>();
  } catch (e) {
    print('Caught error: $e');
  }
}
