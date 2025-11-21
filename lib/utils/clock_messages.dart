import '../i18n/i18n_service.dart';

class ClockMessages {
  // Status Codes Constants (Must match backend)
  static const String STATUS_USER_OR_TEAM_NOT_FOUND = 'USER_OR_TEAM_NOT_FOUND';
  static const String STATUS_NO_SCHEDULE = 'NO_SCHEDULE';
  static const String STATUS_NO_WORKDAY_TYPE = 'NO_WORKDAY_TYPE';
  static const String STATUS_RESUME_WORKDAY = 'RESUME_WORKDAY';
  static const String STATUS_WORKING = 'WORKING';
  static const String STATUS_CLOCK_OUT = 'CLOCK_OUT';
  static const String STATUS_OUTSIDE_SCHEDULE_CONFIRM = 'OUTSIDE_SCHEDULE_CONFIRM';
  static const String STATUS_CAN_CLOCK_IN = 'CAN_CLOCK_IN';
  static const String STATUS_CLOCK_IN_SUCCESS = 'CLOCK_IN_SUCCESS';
  static const String STATUS_CLOCK_OUT_SUCCESS = 'CLOCK_OUT_SUCCESS';
  static const String STATUS_PAUSE_SUCCESS = 'PAUSE_SUCCESS';
  static const String STATUS_RESUME_SUCCESS = 'RESUME_SUCCESS';
  static const String STATUS_EXCEPTIONAL_REQUEST_CREATED = 'EXCEPTIONAL_REQUEST_CREATED';
  static const String STATUS_ERROR = 'ERROR';

  static String getMessage(String? statusCode, {String? fallbackMessage}) {
    if (statusCode == null) return fallbackMessage ?? '';

    switch (statusCode) {
      case STATUS_USER_OR_TEAM_NOT_FOUND:
        return I18n.of('status.USER_OR_TEAM_NOT_FOUND');
      case STATUS_NO_SCHEDULE:
        return I18n.of('status.NO_SCHEDULE');
      case STATUS_NO_WORKDAY_TYPE:
        return I18n.of('status.NO_WORKDAY_TYPE');
      case STATUS_RESUME_WORKDAY:
        return I18n.of('status.RESUME_WORKDAY');
      case STATUS_WORKING:
        return I18n.of('status.WORKING');
      case STATUS_CLOCK_OUT:
        return I18n.of('status.CLOCK_OUT');
      case STATUS_OUTSIDE_SCHEDULE_CONFIRM:
        return I18n.of('status.OUTSIDE_SCHEDULE_CONFIRM');
      case STATUS_CAN_CLOCK_IN:
        return I18n.of('status.CAN_CLOCK_IN');
      case STATUS_CLOCK_IN_SUCCESS:
        return I18n.of('status.CLOCK_IN_SUCCESS');
      case STATUS_CLOCK_OUT_SUCCESS:
        return I18n.of('status.CLOCK_OUT_SUCCESS');
      case STATUS_PAUSE_SUCCESS:
        return I18n.of('status.PAUSE_SUCCESS');
      case STATUS_RESUME_SUCCESS:
        return I18n.of('status.RESUME_SUCCESS');
      case STATUS_EXCEPTIONAL_REQUEST_CREATED:
        return I18n.of('status.EXCEPTIONAL_REQUEST_CREATED');
      case STATUS_ERROR:
        return I18n.of('status.ERROR');
      default:
        return fallbackMessage ?? statusCode;
    }
  }
}
