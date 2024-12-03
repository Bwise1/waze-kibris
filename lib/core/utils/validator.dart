class Validator {
  const Validator._();

  static bool isEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        .hasMatch(email);
  }

  static bool isAllowedPassword(String password) {
    return password.length >= 6;
  }

  static bool isAllowedUsername(String username) {
    return RegExp(r"^[a-z0-9_]*$").hasMatch(username);
  }

  static bool isValidPhoneNumber(String phoneNumber) {
    return RegExp(r"^(?:[+0]9)?[0-9]{11}$").hasMatch(phoneNumber);
  }

  static bool isAllowedName(String name) {
    return RegExp(r"^[a-zA-Z ]*$").hasMatch(name);
  }
}
