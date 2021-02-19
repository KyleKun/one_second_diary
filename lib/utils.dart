class Utils {
  static String getToday() {
    var now = new DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }
}
