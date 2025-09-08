import 'dart:developer' as developer;

class Logger {
  static const String _tag = 'CampusCrush';

  static void debug(String message, {String? tag}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 500, // DEBUG level
    );
  }

  static void info(String message, {String? tag}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 800, // INFO level
    );
  }

  static void warning(String message, {String? tag}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 900, // WARNING level
    );
  }

  static void error(String message,
      {String? tag, Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 1000, // ERROR level
      error: error,
      stackTrace: stackTrace,
    );
  }
}
