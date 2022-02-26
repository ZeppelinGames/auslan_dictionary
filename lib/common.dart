import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:collection/collection.dart' show IterableExtension;
import 'package:edit_distance/edit_distance.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'globals.dart';
import 'types.dart';
import 'word_page.dart';

const String APP_NAME = "Auslan Dictionary";

const Color MAIN_COLOR = Colors.blue;
const Color SETTINGS_COLOR = Color(0xFFEFEFF4);

const String KEY_SHOULD_CACHE = "shouldCache";

const String KEY_FAVOURITES_WORDS = "favourites_words";
const String KEY_LAST_DICTIONARY_DATA_CHECK_TIME = "last_data_check_time";
const String KEY_DICTIONARY_DATA_CURRENT_VERSION = "current_data_version";
const String KEY_HIDE_FLASHCARDS_FEATURE = "hide_flashcards_feature";
const String KEY_FLASHCARD_REGIONS = "flashcard_regions";

const int DATA_CHECK_INTERVAL = 60 * 60 * 24 * 7; // 1 week.

Future<List<Word>> loadWords() async {
  String data;
  try {
    // First try to read from the file we downloaded from the internet.
    final path = await _dictionaryDataFilePath;
    data = await path.readAsString();
    print("Loaded data from local storage downloaded from the internet");
    return loadWordsInner(data);
  } catch (e) {
    // That failed, it probably wasn't there or it was invalid, use data bundled in.
    print(
        "Failed to use data from internet, using local bundled data instead: $e");
    data = await rootBundle.loadString("assets/data/words_latest.json");
    return loadWordsInner(data);
  }
}

List<Word> loadWordsInner(String data) {
  dynamic wordsJson = json.decode(data);
  List<Word> words = [];
  for (MapEntry e in wordsJson.entries) {
    words.add(Word.fromJson(e.key, e.value));
  }
  print("Loaded ${words.length} words");
  return words;
}

Future<void> navigateToWordPage(BuildContext context, Word word) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => WordPage(word: word)),
  );
}

// Search a list of words and return top matching items.
List<Word> searchList(
    String searchTerm, List<Word> words, List<Word> fallback) {
  final SplayTreeMap<double, List<Word>> st =
      SplayTreeMap<double, List<Word>>();
  if (searchTerm == "") {
    return List.from(fallback);
  }
  searchTerm = searchTerm.toLowerCase();
  JaroWinkler d = new JaroWinkler();
  RegExp noParenthesesRegExp = new RegExp(
    r"^[^ (]*",
    caseSensitive: false,
    multiLine: false,
  );
  for (Word w in words) {
    String noPunctuation = w.word.replaceAll(" ", "").replaceAll(",", "");
    String lowerCase = noPunctuation.toLowerCase();
    String noParenthesesContent = noParenthesesRegExp.stringMatch(lowerCase)!;
    String normalisedWord = noParenthesesContent;
    double difference = d.normalizedDistance(normalisedWord, searchTerm);
    if (difference == 1.0) {
      continue;
    }
    st.putIfAbsent(difference, () => []).add(w);
  }
  List<Word> out = [];
  for (List<Word> words in st.values) {
    out.addAll(words);
    if (out.length > 10) {
      break;
    }
  }
  return out;
}

// Run this at startup.
Future<void> bootstrapFavourites() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  try {
    prefs.getStringList(KEY_FAVOURITES_WORDS);
  } catch (e) {
    // The key didn't exist in the favourites list yet.
    prefs.setStringList(KEY_FAVOURITES_WORDS, ["love"]);
    print("Bootstrapped favourites");
  }
}

// Run this at startup.
// Downloads new dictionary data if available.
// First it checks how recently it attempted to do this, so we don't spam
// the dictionary data server.
// Returns true if new data was downloaded.
Future<bool> getNewData(bool forceCheck) async {
  // Determine whether it is time to check for new dictionary data.
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int? lastCheckTime = prefs.getInt(KEY_LAST_DICTIONARY_DATA_CHECK_TIME);
  int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (!(lastCheckTime == null ||
      now - DATA_CHECK_INTERVAL > lastCheckTime ||
      forceCheck)) {
    // No need to check again so soon.
    print("Not checking for new dictionary data, it hasn't been long enough");
    return false;
  }
  // Check for new dictionary data.
  int currentVersion = prefs.getInt(KEY_DICTIONARY_DATA_CURRENT_VERSION) ?? 0;
  int latestVersion = int.parse((await http.get(Uri.parse(
          'https://raw.githubusercontent.com/banool/auslan_dictionary/master/assets/data/latest_version')))
      .body);
  if (latestVersion <= currentVersion) {
    print(
        "Current version ($currentVersion) is >= latest version ($latestVersion), not downloading new data");
    // Record that we made this check so we don't check again too soon.
    prefs.setInt(KEY_LAST_DICTIONARY_DATA_CHECK_TIME, now);
    return false;
  }
  // At this point, we know we need to download the new data. Let's do that.
  String newData = (await http.get(Uri.parse(
          'https://raw.githubusercontent.com/banool/auslan_dictionary/master/assets/data/words_latest.json')))
      .body;
  // Assert that the data is valid. This will throw if it's not.
  loadWordsInner(newData);
  // Write the data to file.
  final path = await _dictionaryDataFilePath;
  await path.writeAsString(newData);
  // Now, record the new version that we downloaded.
  prefs.setInt(KEY_DICTIONARY_DATA_CURRENT_VERSION, latestVersion);
  print(
      "Set KEY_LAST_DICTIONARY_DATA_CHECK_TIME to $now and KEY_DICTIONARY_DATA_CURRENT_VERSION to $latestVersion. Done!");
  return true;
}

// Returns the local path where we store the dictionary data we download.
Future<File> get _dictionaryDataFilePath async {
  final path = (await getApplicationDocumentsDirectory()).path;
  return File('$path/word_dictionary.json');
}

// Load up favourites.
Future<List<Word>> loadFavourites(BuildContext context) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<Word> favourites = [];
  // Load up the Words for the favourites (inefficiently).
  List<String> favouritesRaw = prefs.getStringList(KEY_FAVOURITES_WORDS) ?? [];
  print("Loaded favourites: $favouritesRaw");
  for (String s in favouritesRaw) {
    Word? matchingWord =
        wordsGlobal.firstWhereOrNull((element) => element.word == s);
    if (matchingWord != null) {
      favourites.add(matchingWord);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Your favourite "$s" is no longer in the dictionary'),
          backgroundColor: MAIN_COLOR));
    }
  }
  // Write back the favourites, without the missing entries.
  List<String> newFavourites = [];
  for (Word w in favourites) {
    newFavourites.add(w.word);
  }
  prefs.setStringList(KEY_FAVOURITES_WORDS, newFavourites);
  return favourites;
}

// Write favourites to prefs.
void writeFavourites(List<Word?> favourites, SharedPreferences prefs) {
  List<String> newFavourites = [];
  for (Word? w in favourites) {
    newFavourites.add(w!.word);
  }
  prefs.setStringList(KEY_FAVOURITES_WORDS, newFavourites);
}

// Add to favourites.
Future<void> addToFavourites(Word favouriteToAdd, BuildContext context) async {
  List<Word> favourites = await loadFavourites(context);
  favourites.add(favouriteToAdd);
  SharedPreferences prefs = await SharedPreferences.getInstance();
  writeFavourites(favourites, prefs);
}

// Remove from favourites.
Future<void> removeFromFavourites(
    Word favouriteToRemove, BuildContext context) async {
  List<Word> favourites = await loadFavourites(context);
  favourites.removeWhere((element) => element.word == favouriteToRemove.word);
  SharedPreferences prefs = await SharedPreferences.getInstance();
  writeFavourites(favourites, prefs);
}

bool getShouldUseHorizontalLayout(BuildContext context) {
  var screenSize = MediaQuery.of(context).size;
  var shouldUseHorizontalDisplay = screenSize.width > screenSize.height * 1.2;
  return shouldUseHorizontalDisplay;
}

Future<bool> readKnob(String key, bool fallback) async {
  try {
    String url =
        'https://raw.githubusercontent.com/banool/auslan_dictionary/master/knobs/$key';
    var result = await http.get(Uri.parse(url));
    String raw = result.body.replaceAll("\n", "");
    bool out;
    if (raw == "true") {
      out = true;
    } else if (raw == "false") {
      out = false;
    } else {
      throw "Failed to check knob at $url, using fallback value: $fallback, due to ${result.body}";
    }
    print("Value of knob $key is $out");
    return out;
  } catch (e) {
    print("$e");
    return fallback;
  }
}

bool getShowFlashcards() {
  if (!enableFlashcardsKnob) {
    return false;
  }
  return !(sharedPreferences.getBool(KEY_HIDE_FLASHCARDS_FEATURE) ?? false);
}

Future<bool> confirmAlert(
    BuildContext context, String title, String content) async {
  bool confirmed = false;
  Widget cancelButton = FlatButton(
    child: Text("Cancel"),
    onPressed: () {
      Navigator.of(context).pop();
    },
  );
  Widget continueButton = FlatButton(
    child: Text("Confirm"),
    onPressed: () {
      Navigator.of(context).pop();
      confirmed = true;
    },
  );
  AlertDialog alert = AlertDialog(
    title: Text("Careful!"),
    content: Text(content),
    actions: [
      cancelButton,
      continueButton,
    ],
  );
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
  return confirmed;
}
