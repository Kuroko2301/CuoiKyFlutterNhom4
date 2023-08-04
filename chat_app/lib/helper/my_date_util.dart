import 'package:flutter/material.dart';

class MyDayUtil{

  // Để nhận thời gian được định dạng từ chuỗi milliSecondsSinceEpochs
  static String getFormattedTime({required BuildContext context, required String time}){
    final date = DateTime.fromMillisecondsSinceEpoch(int.parse(time));
    return TimeOfDay.fromDateTime(date).format(context);
  }

  // Để nhận định dạng thời gian gửi và đọc
  static String getMessageTime({required BuildContext context, required String time}){
    final DateTime sent = DateTime.fromMillisecondsSinceEpoch(int.parse(time));
    final DateTime now = DateTime.now();

    final formattedTime = TimeOfDay.fromDateTime(sent).format(context);
    if(now.day == sent.day && now.month == sent.month && now.year == sent.year){
      return formattedTime;
    }

    return now.year == sent.year
        ? '$formattedTime - ${sent.day} ${_getMonth(sent)}'
        : '$formattedTime - ${sent.day} ${_getMonth(sent)} ${sent.year}';
  }

  // Lấy thời gian nhắn tin cuối cùng (được sử dụng trong thẻ người dùng trò chuyện)
  static String getLastMessageTime({required BuildContext context, required String time, bool showYear = false}){
    final DateTime sent = DateTime.fromMillisecondsSinceEpoch(int.parse(time));
    final DateTime now = DateTime.now();

    if(now.day == sent.day && now.month == sent.month && now.year == sent.year){
      return TimeOfDay.fromDateTime(sent).format(context);
    }

    return showYear
        ? '${sent.day} ${_getMonth(sent)} ${sent.year}'
        : '${sent.day} ${_getMonth(sent)}';
  }

  // Lấy định dạng thời gian hoạt động cuối cùng của người dùng trong màn hình trò chuyện
  static String getLastActiveTime({required BuildContext context, required String lastActive}) {
    final int i = int.tryParse(lastActive) ?? -1;

    if(i == -1) return 'Không thấy hoạt động';

    DateTime time = DateTime.fromMillisecondsSinceEpoch(i);
    DateTime now = DateTime.now();

    String formattedTime = TimeOfDay.fromDateTime(time).format(context);
    if(time.day == now.day && time.month == now.month && time.year == now.year){
      return 'Hôm nay đã hoạt động vào $formattedTime';
    }

    if((now.difference(time).inHours / 24).round() == 1){
      return 'Hôm qua đã hoạt động vào $formattedTime';
    }

    String month = _getMonth(time);
    return 'Đã hoạt động vào ${time.day} $month lúc $formattedTime';
  }

  // Lấy tên tháng từ số tháng. hoặc chỉ mục
  static String _getMonth(DateTime date){
    switch (date.month) {
      case 1:
        //return 'Jan';
        return 'thg 1';
      case 2:
        //return 'Feb';
        return 'thg 2';
      case 3:
        //return 'Mar';
        return 'thg 3';
      case 4:
        //return 'Apr';
        return 'thg 4';
      case 5:
        //return 'May';
        return 'thg 5';
      case 6:
        //return 'Jun';
        return 'thg 6';
      case 7:
        //return 'Jul';
        return 'thg 7';
      case 8:
        //return 'Aug';
        return 'thg 8';
      case 9:
        //return 'Sept';
        return 'thg 9';
      case 10:
        //return 'Oct';
        return 'thg 10';
      case 11:
        //return 'Nov';
        return 'thg 11';
      case 12:
        //return 'Dec';
        return 'thg 12';
    }
    return 'N/A';
  }
}