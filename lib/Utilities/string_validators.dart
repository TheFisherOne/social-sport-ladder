// this isn't even used yet
extension StringExtensions on String {
  bool isValidEmail() {
    return RegExp(
        r'^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$'
    ).hasMatch(this);
  }

  // bool isWhiteSpace() => trim().isEmpty;

  // bool isValidDouble() => double.tryParse(this) != null;

  // bool isValidInt()    =>    int.tryParse(this) != null;

  // bool isValidName()  {
  //   return RegExp('^[A-Z][a-z]*[A-Z]?[a-z]*\\s[A-Z][a-z]*[A-Z]?[a-z]*\$').hasMatch(this);
  // }
}