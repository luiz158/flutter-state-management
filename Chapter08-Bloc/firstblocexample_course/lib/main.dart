import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'dart:developer' as devtools show log;

import 'package:http/http.dart' as http;

extension Log on Object {
  void log() => devtools.log(toString());
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material App',
      home: BlocProvider(
        create: (_) => PersonsBloc(),
        child: const HomePage(),
      ),
    );
  }
}

@immutable
abstract class LoadAction {
  const LoadAction();
}

class LoadPersonAction extends LoadAction {
  final PersonUrl url;
  const LoadPersonAction({
    required this.url,
  });
}

enum PersonUrl {
  person1,
  person2,
}

extension UrlString on PersonUrl {
  String get urlString {
    switch (this) {
      case PersonUrl.person1:
        return 'http://192.168.1.7:5500/api/person1.json';
      case PersonUrl.person2:
        return 'http://192.168.1.7:5500/api/person2.json';
    }
  }
}

@immutable
class Person {
  final String name;
  final int age;
  const Person({
    required this.name,
    required this.age,
  });

  Person.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        age = json['age'] as int;
}

Future<Iterable<Person>> getPersons(String url) => HttpClient()
    .getUrl(Uri.parse(url))
    .then((req) => req.close())
    .then((res) => res.transform(utf8.decoder).join())
    .then((str) => jsonDecode(str) as List<dynamic>)
    .then((list) => list.map((e) => Person.fromJson(e)));

// https://dart.dev/tutorials/server/fetch-data#convert-the-response-to-an-object-of-your-structured-class
Future<Iterable<Person>> fetchPersons(String url) async {
  final uri = Uri.parse(url);
  final res = await http.get(uri);

  // If the request didn't succeed, throw an exception
  if (res.statusCode != 200) throw Exception('fetch json failed');

  final personList = json.decode(res.body) as List<dynamic>;
  return personList.map((e) => Person.fromJson(e)).toList();
}

@immutable
class FetchResult {
  final Iterable<Person> persons;
  final bool isRetrievedFromCache;
  const FetchResult({
    required this.persons,
    required this.isRetrievedFromCache,
  });

  @override
  String toString() =>
      'FetchResult(persons: $persons, isRetrievedFromCache: $isRetrievedFromCache)';
}

class PersonsBloc extends Bloc<LoadAction, FetchResult?> {
  final Map<PersonUrl, Iterable<Person>> _cache = {};
  PersonsBloc() : super(null) {
    on<LoadPersonAction>((event, emit) async {
      final url = event.url;
      if (_cache.containsKey(url)) {
        final cachedPersons = _cache[url]!;
        final result = FetchResult(
          persons: cachedPersons,
          isRetrievedFromCache: true,
        );
        emit(result);
      } else {
        final persons = await getPersons(url.urlString);
        _cache[url] = persons;
        final result = FetchResult(
          persons: persons,
          isRetrievedFromCache: false,
        );
        emit(result);
      }
    });
  }
}

extension Subscript<T> on Iterable<T> {
  T? operator [](int index) => length > index ? elementAt(index) : null;
}

class HomePage extends StatefulWidget {
  const HomePage({
    Key? key,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('First Bloc Example'),
      ),
      body: Column(
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () {
                  context.read<PersonsBloc>().add(
                        const LoadPersonAction(
                          url: PersonUrl.person1,
                        ),
                      );
                },
                child: const Text('Load json #1'),
              ),
              TextButton(
                onPressed: () {
                  context.read<PersonsBloc>().add(
                        const LoadPersonAction(
                          url: PersonUrl.person2,
                        ),
                      );
                },
                child: const Text('Load json #2'),
              ),
            ],
          ),
          BlocBuilder<PersonsBloc, FetchResult?>(
            buildWhen: (previous, current) {
              return previous?.persons != current?.persons;
            },
            builder: (context, state) {
              state?.log();
              final persons = state?.persons;
              return persons == null
                  ? const Text('Need to Load')
                  : Expanded(
                      child: ListView.separated(
                        itemCount: persons.length,
                        itemBuilder: ((context, index) {
                          final person = persons[index]!;
                          return ListTile(
                            title: Text(person.name),
                          );
                        }),
                        separatorBuilder: (BuildContext context, int index) {
                          return const Divider(
                            color: Colors.black54,
                            indent: 8,
                            endIndent: 8,
                          );
                        },
                      ),
                    );
            },
          ),
        ],
      ),
    );
  }
}
