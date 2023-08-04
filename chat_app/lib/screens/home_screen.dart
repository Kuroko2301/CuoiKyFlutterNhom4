import 'dart:developer';

import 'package:chat_app/helper/dialogs.dart';
import 'package:chat_app/models/chat_user.dart';
import 'package:chat_app/screens/profile_screen.dart';
import 'package:chat_app/widgets/chat_user_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/apis.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  List<ChatUser> _list = [];

  final List<ChatUser> _searchList = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    APIs.getSelfInfo();



    SystemChannels.lifecycle.setMessageHandler((message) {
      log('Message: $message');

      if(APIs.auth.currentUser != null) {
        if(message.toString().contains('resume')){
          APIs.updateActiveStatus(true);
        }
        if(message.toString().contains('pause')) {
          APIs.updateActiveStatus(false);
        }
      }


      return Future.value(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: WillPopScope(
        onWillPop: () {
          if(_isSearching){
            setState(() {
              _isSearching = !_isSearching;

            });
            return Future.value(false);
          }else{
            return Future.value(true);
          }

        },
        child: Scaffold(
          // Thanh ứng dụng
          appBar: AppBar(
            leading: Icon(CupertinoIcons.home),
            title: _isSearching ? TextField(
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Tìm kiếm Tên hoặc Email ...',
              ), autofocus: true,
              style: TextStyle(fontSize: 17, letterSpacing: 0.5),
              onChanged: (val) {
                _searchList.clear();

                for(var i in _list){
                  if(i.name.toLowerCase().contains(val.toLowerCase()) || i.email.toLowerCase().contains(val.toLowerCase())){
                    _searchList.add(i);
                  }
                  setState(() {
                    _searchList;
                  });
                }
              },
            ) : Text('Nhắn Tin'),
            actions: [
              // Nút tìm kiếm
              IconButton(onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                });
              }, icon: Icon(_isSearching ? CupertinoIcons.clear_circled_solid : Icons.search)),
              // Nút các tính năng khác
              IconButton(onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(user: APIs.me,)));
              }, icon: const Icon(Icons.more_vert))
            ],

          ),

          // Nút nổi để thêm người dùng nhắn tin
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FloatingActionButton(
              onPressed: () {
                _addChatUserDialog();
              }, child: const Icon(Icons.add_comment_rounded),),
            ),

          body: StreamBuilder(
            stream: APIs.getMyUsersId(),
              builder: (context, snapshot) {
                switch (snapshot.connectionState){
                  case ConnectionState.waiting:
                  case ConnectionState.none:
                    return const Center(child: CircularProgressIndicator(),);
                  case ConnectionState.active:
                  case ConnectionState.done:
              return StreamBuilder(
                stream: APIs.getAllUsers(snapshot.data?.docs.map((e) => e.id).toList() ?? []),
                builder: (context, snapshot) {

                  switch (snapshot.connectionState){
                    case ConnectionState.waiting:
                    case ConnectionState.none:
                      return const Center(child: CircularProgressIndicator(),);
                    case ConnectionState.active:
                    case ConnectionState.done:


                      final data = snapshot.data?.docs;
                      _list = data?.map((e) => ChatUser.fromJson(e.data())).toList() ?? [];

                      if(_list.isNotEmpty){
                        return ListView.builder(
                            itemCount: _isSearching ? _searchList.length : _list.length,
                            padding: EdgeInsets.only(top: mq.height * .01),
                            physics: BouncingScrollPhysics(),
                            itemBuilder: (context, index){
                              return ChatUserCard(user: _isSearching ? _searchList[index] : _list[index],);
                              // return Text('Name: ${list[index]}');
                            });
                      }else{
                        return const Center(child: Text('Không thấy kết nối nào!', style: TextStyle(fontSize: 20),),);
                      }
                  }
                },

              );
            }

          })

        ),
      ),
    );
  }

  void _addChatUserDialog(){
    String email = '';

    showDialog(context: context, builder: (_) => AlertDialog(
      contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(
            Icons.person_add,
            color: Colors.blue,
            size: 28,
          ),
          Text(' Thêm người dùng')
        ],),

      content: TextFormField(

        maxLines: null,
        onChanged: (value) => email = value,
        decoration: InputDecoration(
          hintText: 'Email ...',
            prefixIcon: const Icon(Icons.email, color: Colors.blue,),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
      ),
      actions: [
        MaterialButton(
          onPressed: (){
            Navigator.pop(context);
          },
          child: const Text(
            'Hủy', style: TextStyle(color: Colors.blue, fontSize: 16)
          ),),
        MaterialButton(
          onPressed: () async {
            Navigator.pop(context);
            if(email.isNotEmpty) {
              await APIs.addChatUser(email).then((value) {
                if(!value){
                  Dialogs.showSnackbar(context, 'Người dùng không tồn tại!');
                }
              });
            }

          },
          child: Text(
            'Thêm', style: TextStyle(color: Colors.blue, fontSize: 16),
          ),)
      ],
    ));
  }
}
