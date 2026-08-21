/// Application version information.
///
/// Keep in sync with `pubspec.yaml`. Runtime reads come from
/// `package_info_plus`; this is the compile-time constant.
class AppVersion {
  AppVersion._();

  static const String version = '2.0.0';
  static const String build = '1';
  static const String appName = 'TaskFlow';
}
