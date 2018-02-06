import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:hello_flutter/constants.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:math';
import 'dart:io';
import 'dart:async';

import 'package:hello_flutter/themes.dart';

final googleSignIn = new GoogleSignIn();
final analytics = new FirebaseAnalytics();
final auth = FirebaseAuth.instance;

void main() {
  runApp(new FriendlyChatApp());
}

class FriendlyChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: Constants.APP_NAME,
        theme: defaultTargetPlatform == TargetPlatform.iOS
            ? Themes.kIOSTheme
            : Themes.kDefaultTheme,
        home: new ChatScreen());
  }
}

class ChatScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => new ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = new TextEditingController();
  final reference =
      FirebaseDatabase.instance.reference().child(Constants.MESSAGES_TABLE);

  bool _isComposing = false;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        appBar: new AppBar(
            title: new Text(Constants.APP_NAME),
            elevation: Themes.getElevation(context)),
        body: new Container(
          child: new Column(
            children: <Widget>[
              new Flexible(
                child: buildFirebaseList(),
              ),
              new Divider(height: 1.0),
              new Container(
                decoration:
                    new BoxDecoration(color: Theme.of(context).cardColor),
                child: _buildTextComposer(),
              ),
            ],
          ),
          decoration: Themes.isiOS(context)
              ? new BoxDecoration(
                  border:
                      new Border(top: new BorderSide(color: Colors.grey[200])))
              : null,
        ));
  }

  FirebaseAnimatedList buildFirebaseList() {
    return new FirebaseAnimatedList(
        query: reference,
        sort: (a, b) => b.key.compareTo(a.key),
        padding: new EdgeInsets.all(8.0),
        reverse: true,
        itemBuilder: (_, DataSnapshot snapshot, Animation<double> animation) {
          return new ChatMessage(snapshot: snapshot, animation: animation);
        });
  }

  Widget _buildTextComposer() {
    return new IconTheme(
      data: new IconThemeData(color: Theme.of(context).accentColor),
      child: new Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: new Row(children: <Widget>[
            new Container(
              margin: new EdgeInsets.symmetric(horizontal: 4.0),
              child: buildTakePhotoButton(),
            ),
            new Flexible(
              child: buildSendTextField(),
            ),
            new Container(
              margin: new EdgeInsets.symmetric(horizontal: 4.0),
              child: buildSendButton(),
            ),
          ])),
    );
  }

  Widget buildTakePhotoButton() {
    return new IconButton(
        icon: new Icon(Icons.photo_camera),
        onPressed: onTakePhotoButtonPressed);
  }

  TextField buildSendTextField() {
    return new TextField(
      controller: _textController,
      onSubmitted: _isComposing ? _onSendMessageButtonPressed : null,
      onChanged: _handleChanged,
      decoration: new InputDecoration.collapsed(hintText: "Send a message"),
    );
  }

  Widget buildSendButton() {
    return Themes.isiOS(context)
        ? new CupertinoButton(
            child: new Text("Send"),
            onPressed: () => _onSendMessageButtonPressed(_textController.text))
        : new IconButton(
            icon: new Icon(Icons.send),
            onPressed: () => _onSendMessageButtonPressed(_textController.text));
  }

  Future onTakePhotoButtonPressed() async {
    await _ensureLoggedIn();
    File imageFile = await ImagePicker.pickImage();
    String imageFileName = createImageFileName();
    Uri downloadUrl = await uploadPhoto(imageFileName, imageFile);
    _sendMessage(imageUrl: downloadUrl.toString());
  }

  Future<Uri> uploadPhoto(String imageFileName, File imageFile) async {
    StorageReference reference =
        FirebaseStorage.instance.ref().child(imageFileName);
    StorageUploadTask uploadTask = reference.put(imageFile);
    Uri downloadUrl = (await uploadTask.future).downloadUrl;
    return downloadUrl;
  }

  Future<Null> _onSendMessageButtonPressed(String text) async {
    if (_isComposing) {
      _textController.clear();
      setState(() {
        _isComposing = false;
      });
      await _ensureLoggedIn();
      _sendMessage(text: text);
    }
  }

  void _sendMessage({String text, String imageUrl}) {
    reference.push().set({
      'text': text,
      'imageUrl': imageUrl,
      'senderName': googleSignIn.currentUser.displayName,
      'senderPhotoUrl': googleSignIn.currentUser.photoUrl
    });
    analytics.logEvent(name: "send_message");
  }

  void _handleChanged(String text) {
    setState(() {
      _isComposing = text.length > 0;
    });
  }

  Future<Null> _ensureLoggedIn() async {
    GoogleSignInAccount user = googleSignIn.currentUser;
    if (user == null) {
      user = await googleSignIn.signInSilently();
    }
    if (user == null) {
      user = await googleSignIn.signIn();
      analytics.logLogin();
    }

    if (await auth.currentUser() == null) {
      GoogleSignInAuthentication credentials =
          await googleSignIn.currentUser.authentication;
      await auth.signInWithGoogle(
          idToken: credentials.idToken, accessToken: credentials.accessToken);
    }
  }

  String createImageFileName() {
    int random = new Random().nextInt(100000);
    return "image_$random.jpg";
  }
}

class ChatMessage extends StatelessWidget {
  final DataSnapshot snapshot;
  final Animation animation;

  ChatMessage({this.snapshot, this.animation});

  @override
  Widget build(BuildContext context) {
    return new SizeTransition(
        sizeFactor:
            new CurvedAnimation(parent: animation, curve: Curves.easeOut),
        axisAlignment: 0.0,
        child: new Container(
          margin: const EdgeInsets.symmetric(vertical: 10.0),
          child: buildMessageRow(context),
        ));
  }

  Row buildMessageRow(BuildContext context) {
    return new Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        new Container(
          margin: const EdgeInsets.only(right: 16.0),
          child: buildAvatar(),
        ),
        new Expanded(
          child: new Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              buildSenderNameText(context),
              buildMessageBody()
            ],
          ),
        )
      ],
    );
  }

  CircleAvatar buildAvatar() {
    return new CircleAvatar(
      backgroundImage: new NetworkImage(snapshot.value['senderPhotoUrl']),
    );
  }

  Text buildSenderNameText(BuildContext context) {
    return new Text(snapshot.value['senderName'],
        style: Theme.of(context).textTheme.subhead);
  }

  Container buildMessageBody() {
    return new Container(
      margin: const EdgeInsets.only(top: 5.0),
      child: snapshot.value['imageUrl'] != null
          ? buildMessagePhoto()
          : buildMessageText(),
    );
  }

  Text buildMessageText() => new Text(snapshot.value['text']);

  Widget buildMessagePhoto() =>
      new Image.network(snapshot.value['imageUrl'], width: 250.0);
}
