import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chips_input/flutter_chips_input.dart';

const String avatarPlaceholder = "https://upload.wikimedia.org/wikipedia/commons/7/7c/Profile_avatar_placeholder_large.png";

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chips Input',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // brightness: Brightness.dark,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  final _chipKey = GlobalKey<ChipsInputState>();

  @override
  Widget build(BuildContext context) {
    const mockResults = <AppProfile>[
      AppProfile('John Doe', 'jdoe@flutter.io', 'https://d2gg9evh47fn9z.cloudfront.net/800px_COLOURBOX4057996.jpg'),
      AppProfile('Paul', 'paul@google.com', avatarPlaceholder),
      AppProfile('Fred', 'fred@google.com', avatarPlaceholder),
      AppProfile('Brian', 'brian@flutter.io', avatarPlaceholder),
      AppProfile('John', 'john@flutter.io', avatarPlaceholder),
      AppProfile('Thomas', 'thomas@flutter.io', avatarPlaceholder),
      AppProfile('Nelly', 'nelly@flutter.io', avatarPlaceholder),
      AppProfile('Marie', 'marie@flutter.io', avatarPlaceholder),
      AppProfile('Charlie', 'charlie@flutter.io', avatarPlaceholder),
      AppProfile('Diana', 'diana@flutter.io', avatarPlaceholder),
      AppProfile('Ernie', 'ernie@flutter.io', avatarPlaceholder),
      AppProfile('Gina', 'fred@flutter.io', avatarPlaceholder),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Chips Input Example')),
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              ChipsInput<AppProfile>(
                key: _chipKey,
                /*initialValue: [
                  AppProfile('John Doe', 'jdoe@flutter.io',
                      'https://d2gg9evh47fn9z.cloudfront.net/800px_COLOURBOX4057996.jpg'),
                ],*/
                // autofocus: true,
                // allowChipEditing: true,
                keyboardAppearance: Brightness.dark,
                textCapitalization: TextCapitalization.words,
                submitKeys: const [LogicalKeyboardKey.tab],
                // enabled: false,
                // maxChips: 5,
                textStyle: const TextStyle(height: 1.5, fontFamily: 'Roboto', fontSize: 16),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  // hintText: formControl.hint,
                  labelText: 'Select People',
                  enabled: false,
                  // errorText: field.errorText,
                  border: OutlineInputBorder(),
                ),
                findSuggestions: (query) {
                  // print("Query: '$query'");
                  if (query.isNotEmpty) {
                    var lowercaseQuery = query.toLowerCase();
                    return mockResults.where((profile) {
                      return profile.name.toLowerCase().contains(query.toLowerCase()) || profile.email.toLowerCase().contains(query.toLowerCase());
                    }).toList(growable: false)
                      ..sort((a, b) => a.name.toLowerCase().indexOf(lowercaseQuery).compareTo(b.name.toLowerCase().indexOf(lowercaseQuery)));
                  }
                  // return <AppProfile>[];
                  return mockResults;
                },
                onChanged: (data) {
                  // print(data);
                },
                chipBuilder: (context, state, index, profile) {
                  return InputChip(
                    key: ObjectKey(profile),
                    label: Text(profile.name),
                    avatar: CircleAvatar(backgroundImage: NetworkImage(profile.imageUrl)),
                    onDeleted: () => state.deleteChip(index),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
                suggestionBuilder: (context, state, index, profile) {
                  return InputChip(
                    key: ObjectKey(profile),
                    label: Text(profile.name),
                    avatar: CircleAvatar(backgroundImage: NetworkImage(profile.imageUrl)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () => state.selectSuggestion(profile),
                  );
                },
                onSubmit: (txt) {
                  if (txt.isEmpty) return null;
                  return mockResults.firstWhere(
                        (profile) => profile.name == txt,
                    orElse: () => AppProfile(txt, "", "https://upload.wikimedia.org/wikipedia/commons/7/7c/Profile_avatar_placeholder_large.png"),
                  );
                },
              ),
              const TextField(),
              ChipsInput(
                initialValue: const [
                  AppProfile('John Doe', 'jdoe@flutter.io', 'https://d2gg9evh47fn9z.cloudfront.net/800px_COLOURBOX4057996.jpg'),
                ],
                enabled: true,
                maxChips: 10,
                textStyle: const TextStyle(height: 1.5, fontFamily: "Roboto", fontSize: 16),
                decoration: const InputDecoration(
                  // prefixIcon: Icon(Icons.search),
                  // hintText: formControl.hint,
                  labelText: "Select People",
                  // enabled: false,
                  // errorText: field.errorText,
                ),
                findSuggestions: (String query) {
                  if (query.isNotEmpty) {
                    var lowercaseQuery = query.toLowerCase();
                    return mockResults.where((profile) {
                      return profile.name.toLowerCase().contains(query.toLowerCase()) || profile.email.toLowerCase().contains(query.toLowerCase());
                    }).toList(growable: false)
                      ..sort((a, b) => a.name.toLowerCase().indexOf(lowercaseQuery).compareTo(b.name.toLowerCase().indexOf(lowercaseQuery)));
                  } else {
                    return mockResults;
                  }
                },
                onChanged: (data) {
                  print(data);
                },
                chipBuilder: (context, state, index, profile) {
                  return InputChip(
                    key: ObjectKey(profile),
                    label: Text(profile.name),
                    avatar: CircleAvatar(backgroundImage: NetworkImage(profile.imageUrl)),
                    onDeleted: () => state.deleteChip(index),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
                suggestionBuilder: (context, state, index, profile) {
                  return ListTile(
                    key: ObjectKey(profile),
                    leading: CircleAvatar(backgroundImage: NetworkImage(profile.imageUrl)),
                    title: Text(profile.name),
                    subtitle: Text(profile.email),
                    onTap: () => state.selectSuggestion(profile),
                  );
                },
                onSubmit: (txt) {
                  if (txt.isEmpty) return null;
                  return mockResults.firstWhere(
                        (profile) => profile.name == txt,
                    orElse: () => AppProfile(txt, "", avatarPlaceholder),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () {
                  _chipKey.currentState!.selectSuggestion(const AppProfile('Gina', 'fred@flutter.io', avatarPlaceholder));
                },
                child: const Text('Add Chip'),
              ),
            ],
          ),
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class AppProfile {
  final String name;
  final String email;
  final String imageUrl;

  const AppProfile(this.name, this.email, this.imageUrl);

  @override
  bool operator ==(Object other) => identical(this, other) || other is AppProfile && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() {
    return name;
  }
}
