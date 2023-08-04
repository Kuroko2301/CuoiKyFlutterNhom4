import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:chat_app/models/chat_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart';

import '../models/message.dart';

class APIs{
  // Dùng để xác thực trên Firebase
  static FirebaseAuth auth = FirebaseAuth.instance;

  static late ChatUser me;

  // Truy cập vào dữ liệu đám mây trên firebase
  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Truy cập bộ nhớ trên Firebase
  static FirebaseStorage storage = FirebaseStorage.instance;

  // Trả về user hiện tại
  static User get user => auth.currentUser!;

  // Truy cập nhắn tin trên firebase
  static FirebaseMessaging fMessaging = FirebaseMessaging.instance;

  // Nhận mã thông báo firebase
  static Future<void> getFirebaseMessagingToken() async {
    await fMessaging.requestPermission();

    await fMessaging.getToken().then((t) {
      if(t != null){
        me.pushToken = t;
        log('Push Token: $t');
      }
    });

    // Options foreground messages
    // Điều chỉnh thông báo trên điện thoại, thông báo icon hay khung tin nhắn
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Got a message whilst in the foreground');
      log('Message data: ${message.data}');

      if(message.notification != null){
        log('Message also contained a notification: ${message.notification}');
      }
    });
  }

  // Gửi thông báo đẩy
  static Future<void> sendPushNotification(ChatUser chatUser, String msg) async {
    try{
      final body = {
        "to": chatUser.pushToken,
        "notification": {
          "title": me.name,
          "body": msg,
          "android_channel_id": "chats",
        },
        "data": {
          "some_data": "User ID: ${me.id}",
        }
      };

      var res = await post(Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.authorizationHeader: 'key=AAAAatKwSbk:APA91bEHAT_hTSaHNc-Q_QQCYc-XbzX6dlZP_UsW33YDTkrFpuoZR44mGZ0ingsOWs13QaG8dkJ9qc4-BOEszKxeCol5iRwqonmOVaWq_m2FNHI6NyNrpdAh6fTpEs2Q_4xRolprLpKQ'
          },
          body: jsonEncode(body));
      log('Response status: ${res.statusCode}');
      log('Response body: ${res.body}');
    }
    catch(e){
      log('\nsendPushNotificationE: $e');
    }
  }

  // Kiểm tra user đã tồn tại hay chưa
  static Future<bool> userExist() async {
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  // Thêm người dùng để nhắn tin
  static Future<bool> addChatUser(String email) async {
    final data = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    log('data: ${data.docs}');

    if (data.docs.isNotEmpty && data.docs.first.id != user.uid) {

      log('user exists: ${data.docs.first.data()}');

      firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(data.docs.first.id)
          .set({});

      return true;
    } else {

      return false;
    }
  }

  // Lấy thông tin người dùng hiện tại
  static Future<void> getSelfInfo() async {
    await firestore.collection('users').doc(user.uid).get().then((user) async {
      if(user.exists){
        me = ChatUser.fromJson(user.data()!);
        await getFirebaseMessagingToken();
        APIs.updateActiveStatus(true);
        log('My Data: ${user.data()}');
      }else{
        await createUser().then((value) => getSelfInfo());
      }
    });
  }

  // Tạo user mới
  static Future<void> createUser() async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();

    final chatUser = ChatUser(
      id: user.uid,
      name: user.displayName.toString(),
      email: user.email.toString(),
      about: "Hello, ohayou gozaimasu!",
      image: user.photoURL.toString(),
      createdAt: time,
      isOnline: false,
      lastActive: time,
      pushToken: '',
    );
    return await firestore
        .collection('users')
        .doc(user.uid)
        .set(chatUser
        .toJson());
  }

  // Lấy id của người dùng đã biết từ cơ sở dữ liệu firestore
  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyUsersId() {
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('my_users')
        .snapshots();
  }

  // Lấy tất cả người dùng trên dữ liệu firebase
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers(
      List<String> userIds) {
    log('\nUserIds: $userIds');

    return firestore
        .collection('users')
        .where('id',
        whereIn: userIds.isEmpty
            ? ['']
            : userIds)
        .snapshots();
  }

  // Thêm người dùng vào người dùng của tôi khi gửi tin nhắn đầu tiên
  static Future<void> sendFirstMessage(ChatUser chatUser, String msg, Type type) async {
    await firestore
        .collection('users')
        .doc(chatUser.id)
        .collection('my_users')
        .doc(user.uid)
        .set({}).then((value) => sendMessage(chatUser, msg, type));
  }

  // Cập nhật thông tin người dùng
  static Future<void> updateUserInfo() async {
    await firestore.collection('users').doc(user.uid).update({
      'name' : me.name,
      'about' : me.about,
    });
  }

  // Nhận thông tin người dùng cụ thể
  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(ChatUser chatUser) {
    return firestore.collection('users').where('id', isEqualTo: chatUser.id).snapshots();
  }

  // Cập nhật trạng thái hoạt động
  static Future<void> updateActiveStatus(bool isOnline) async {
    firestore.collection('users').doc(user.uid).update({
      'is_online' : isOnline,
      'last_active' : DateTime.now().millisecondsSinceEpoch.toString(),
      'push_token' : me.pushToken
    });
  }

  // Cập nhật hình ảnh của người dùng
  static Future<void> updateProfilePicture(File file) async {
    final ext = file.path.split('.').last;
    log('Extension: $ext');
    final ref = storage.ref().child('profile_pictures/${user.uid}.$ext');
    await ref.putFile(file, SettableMetadata(contentType: 'image/$ext')).then((p0) {
      log('Data Transferred: ${p0.bytesTransferred / 1000} kb');
    });
    me.image = await ref.getDownloadURL();
    await firestore.collection('users').doc(user.uid).update({
      'image' : me.image,
    });
  }

  ///************** API liên quan đến màn hình nhắn tin **************
  // chats (collection) --> conversation_id (doc) --> messages (collection) --> message (doc)

  // Lấy id cuộc nói chuyện
  static String getConversationID(String id) => user.uid.hashCode <= id.hashCode
      ? '${user.uid}_$id'
      : '${id}_${user.uid}';

  // Nhận tất cả tin nhắn của một cuộc noi chuyện cụ thể từ cơ sở dữ liệu firestore
  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllMessages(ChatUser user) {
    return firestore
        .collection('chats/${getConversationID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  // Dùng để gửi tin nhắn
  static Future<void> sendMessage(ChatUser chatUser, String msg, Type type) async {

    final time = DateTime.now().millisecondsSinceEpoch.toString();

    final Message message = Message(
        toId: chatUser.id,
        msg: msg,
        read: '',
        type: type,
        fromId: user.uid,
        sent: time);

    final ref = firestore.collection('chats/${getConversationID(chatUser.id)}/messages/');
    await ref.doc(time).set(message.toJson()).then((value) => sendPushNotification(chatUser, type == Type.text ? msg : 'Hình ảnh'));
  }

  // Cập nhật trạng thái đã đọc hay chưa đọc tin nhắn
  static Future<void> updateMessageReadStatus(Message message) async {
    firestore
        .collection('chats/${getConversationID(message.fromId)}/messages/')
        .doc(message.sent)
        .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
  }

  // Lấy dòng tin nhắn để hiển thị trên màn hình Home
  static Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessage(ChatUser user){
    return firestore
        .collection('chats/${getConversationID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .limit(1)
        .snapshots();
  }

  // Gửi hình ảnh
  static Future<void> sendChatImage(ChatUser chatUser, File file) async {
    final ext = file.path.split('.').last;

    final ref = storage.ref().child(
        'images/${getConversationID(chatUser.id)}/${DateTime.now().millisecondsSinceEpoch}.$ext');

    await ref.putFile(file, SettableMetadata(contentType: 'image/$ext')).then((p0) {
      log('Data Transferred: ${p0.bytesTransferred / 1000} kb');
    });
    final imageUrl = await ref.getDownloadURL();
    await sendMessage(chatUser, imageUrl, Type.image);
  }

  // Xóa tin nhắn
  static Future<void> deleteMessage(Message message) async {
    await firestore
        .collection('chats/${getConversationID(message.toId)}/messages/')
        .doc(message.sent)
        .delete();

    if(message.type == Type.image){
      await storage.refFromURL(message.msg).delete();
    }
  }

  // Cập nhật (Chỉnh sửa) tin nhắn
  static Future<void> updateMessage(Message message, String updateMsg) async {
    await firestore
        .collection('chats/${getConversationID(message.toId)}/messages/')
        .doc(message.sent)
        .update({'msg': updateMsg});
    
  }
}