import 'package:auslan_dictionary/common.dart';
import 'package:auslan_dictionary/globals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'word_list_logic.dart';

class WordListsOverviewController {
  bool inEditMode = false;

  void toggleEditMode() {
    inEditMode = !inEditMode;
  }
}

class WordListsOverviewPage extends StatefulWidget {
  final WordListsOverviewController controller;

  WordListsOverviewPage({Key? key, required this.controller}) : super(key: key);

  @override
  _WordListsOverviewPageState createState() =>
      _WordListsOverviewPageState(controller: controller);
}

class _WordListsOverviewPageState extends State<WordListsOverviewPage> {
  WordListsOverviewController controller;

  _WordListsOverviewPageState({required this.controller});

  @override
  Widget build(BuildContext context) {
    List<Widget> tiles = [];
    for (MapEntry<String, WordList> e in wordListManager.wordLists.entries) {
      WordList wl = e.value;
      Widget? trailing;
      if (controller.inEditMode && wl.canBeDeleted()) {
        trailing = IconButton(
            icon: Icon(
              Icons.remove_circle,
              color: Colors.red,
            ),
            onPressed: () async {
              bool deleted = await confirmAlert(
                  context, Text("Are you sure you want to delete this list?"));
              if (deleted) {
                setState(() {});
              }
            });
      }
      tiles.add(Card(
        child: ListTile(
          leading: wl.getLeadingIcon(),
          trailing: trailing,
          minLeadingWidth: 10,
          title: Text(
            wl.getName(),
            textAlign: TextAlign.start,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ));
    }
    return ListView(
      children: tiles,
    );
  }
}

// Returns true if a new list was created.
Future<bool> applyCreateListDialog(BuildContext context) async {
  TextEditingController controller = TextEditingController();
  Widget body = TextField(
    controller: controller,
    decoration: InputDecoration(
      hintText: 'Enter new list name',
    ),
    autofocus: true,
    inputFormatters: [
      FilteringTextInputFormatter.allow(WordList.validNameCharacters),
    ],
    textInputAction: TextInputAction.send,
    keyboardType: TextInputType.visiblePassword,
  );
  bool confirmed = await confirmAlert(context, body);
  if (confirmed) {
    String name = controller.text;
    String key = WordList.getKeyFromName(name);
    await wordListManager.createWordList(key);
  }
  return confirmed;
}
