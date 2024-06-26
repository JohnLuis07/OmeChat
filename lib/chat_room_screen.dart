// chat_room_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'loading_screen.dart';
import 'services/room_operations.dart';

Completer<void> _popCompleter = Completer<void>();

class ChatRoomScreen extends StatelessWidget {
  const ChatRoomScreen({
    Key? key,
    required this.roomId,
    required this.occupants,
    required this.currentUserId,
  }) : super(key: key);

  final String roomId;
  final List<String> occupants;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chat Room',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Color.fromRGBO(180, 74, 26, 1),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: () async {
                _popCompleter = Completer<void>();
                await deleteCurrentUserFromRoom(roomId, currentUserId);

                Navigator.pop(
                  context,
                );
                await _popCompleter.future;
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
              child: const Text('STOP'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: () async {
                _popCompleter = Completer<void>();
                await deleteCurrentUserFromRoom(roomId, currentUserId);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoadingScreen()),
                );
                await _popCompleter.future;
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green,
              ),
              child: const Text('NEXT'),
            ),
          ),
        ],
      ),
      backgroundColor: Color.fromRGBO(254, 243, 227, 1),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.png"), // Path to your image
            fit: BoxFit.cover,
          ),
        ),
        child: PopScope(
          canPop: true,
          onPopInvoked: (bool didPop) async {
            if (didPop) {
              await deleteCurrentUserFromRoom(roomId, currentUserId);
              _popCompleter.complete();
            }
          },
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .snapshots(),
            builder: (BuildContext context,
                AsyncSnapshot<DocumentSnapshot> snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Visibility(
                    visible: false, child: CircularProgressIndicator());
              }

              var roomData = snapshot.data!.data() as Map<String, dynamic>?;

              bool userInRoom = roomData != null &&
                  (roomData['occupant1'] == currentUserId ||
                      roomData['occupant2'] == currentUserId);

              bool connectionEstablished = userInRoom &&
                  roomData != null &&
                  (roomData['occupant1'] == occupants[0] &&
                      roomData['occupant2'] == occupants[1]);

              // if (connectionEstablished) {
              //   WidgetsBinding.instance!.addPostFrameCallback((_) {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       SnackBar(
              //         content: Text('Connection Established'),
              //       ),
              //     );
              //   });
              // }

              if (!connectionEstablished && userInRoom) {
                WidgetsBinding.instance!.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User left the room.'),
                    ),
                  );
                });
              }

              print(!connectionEstablished && userInRoom);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: StreamBuilder(
                      stream: FirebaseFirestore.instance
                          .collection('rooms')
                          .doc(roomId)
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (BuildContext context,
                          AsyncSnapshot<QuerySnapshot> snapshot) {
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Visibility(
                              visible: false,
                              child: CircularProgressIndicator());
                        }

                        return ListView(
                          reverse: true,
                          padding: const EdgeInsets.all(16.0),
                          children: snapshot.data!.docs
                              .map((DocumentSnapshot document) {
                            Map<String, dynamic> data =
                                document.data() as Map<String, dynamic>;
                            return _buildMessage(
                              context: context,
                              isCurrentUser: data['userId'] == currentUserId,
                              message: data['message'],
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                  Visibility(
                    visible: (connectionEstablished && userInRoom),
                    child: _buildMessageInputField(),
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessage({
    required BuildContext context, // Add BuildContext parameter here
    required bool isCurrentUser,
    required String message,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 100,
              ),
              padding: EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Color.fromARGB(255, 46, 46, 46)
                    // rgb(232, 95, 36)
                    : Color.fromARGB(255, 216, 216, 216),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message,
                style: TextStyle(
                    fontSize: 16.0,
                    color: isCurrentUser ? Colors.white : Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInputField() {
    TextEditingController _controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(180, 74, 26, 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 216, 216, 216), // Background color
                borderRadius: BorderRadius.circular(25.0), // Rounded corners
              ),
              child: TextField(
                minLines: 1,
                maxLines: 3,
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none, // Remove default border
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              String messageText = _controller.text.trim();

              if (messageText.isNotEmpty) {
                _controller.clear();
                FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(roomId)
                    .collection('messages')
                    .add({
                  'message': messageText,
                  'userId': currentUserId,
                  'timestamp': Timestamp.now(),
                }).catchError((error) {
                  print("Error sending message: $error");
                });
              }
            },
            icon: const Icon(Icons.send),
            // color: Color.fromRGBO(9, 193, 199, 1),
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}
