class Word implements Comparable<Word> {
  Word({required this.word, required this.subWords});

  late String word;
  late List<SubWord> subWords;

  Word.fromJson(String word, dynamic wordJson) {
    this.word = word;

    List<SubWord> subWords = [];
    wordJson.forEach((subJson) {
      SubWord subWord = SubWord.fromJson(subJson);
      subWord.keywords.remove(word);
      subWords.add(subWord);
    });

    this.subWords = subWords;
  }

  @override
  int compareTo(Word other) {
    return this.word.compareTo(other.word);
  }

  @override
  String toString() {
    return this.word;
  }
}

class SubWord {
  SubWord(
      {required this.keywords,
      required this.videoLinks,
      required this.definitions,
      required this.regions});

  late List<String> keywords;
  late List<String> videoLinks;
  late List<Definition> definitions;
  late List<Region> regions;

  SubWord.fromJson(dynamic wordJson) {
    this.keywords = wordJson["keywords"].cast<String>();

    this.videoLinks = wordJson["video_links"].cast<String>();

    List<Definition> definitions = [];
    wordJson["definitions"].forEach((heading, value) {
      List<String>? subdefinitions = value.cast<String>();
      definitions
          .add(Definition(heading: heading, subdefinitions: subdefinitions));
    });
    this.definitions = definitions;

    List<int> regionInts = wordJson["regions"].cast<int>();
    List<Region> regions = regionInts.map((i) => Region.values[i]).toList();

    this.regions = regions;
  }

  String getRegionsString() {
    if (this.regions.length == 0) {
      return "Regional information unknown";
    }
    if (this.regions.contains(Region.EVERYWHERE)) {
      return Region.EVERYWHERE.pretty;
    }
    return this.regions.map((r) => r.pretty).join(", ");
  }
}

class Definition {
  Definition({this.heading, this.subdefinitions});

  final String? heading;
  final List<String>? subdefinitions;
}

// IMPORTANT:
// Keep this in sync with Region in scripts/scrape_signbank.py, the order is important.
enum Region {
  EVERYWHERE,
  SOUTHERN,
  NORTHERN,
  WA,
  NT,
  SA,
  QLD,
  NSW,
  ACT,
  VIC,
  TAS,
}

extension PrintRegion on Region {
  String get pretty {
    switch (this) {
      case Region.EVERYWHERE:
        return "All states of Australia";
      case Region.SOUTHERN:
        return "Southern";
      case Region.NORTHERN:
        return "Northern";
      case Region.WA:
        return "WA";
      case Region.NT:
        return "NT";
      case Region.SA:
        return "SA";
      case Region.QLD:
        return "QLD";
      case Region.NSW:
        return "NSW";
      case Region.ACT:
        return "ACT";
      case Region.VIC:
        return "VIC";
      case Region.TAS:
        return "TAS";
    }
  }
}
