// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#library('pub_tests');

#import('dart:io');

#import('test_pub.dart');
#import('../../../lib/unittest/unittest.dart');

final USAGE_STRING = """
    Pub is a package manager for Dart.

    Usage:

      pub command [arguments]

    The commands are:

      install   install the current package's dependencies
      list      print the contents of repositories
      update    update the current package's dependencies to the latest versions
      version   print Pub version

    Use "pub help [command]" for more information about a command.
    """;

final VERSION_STRING = '''
    Pub 0.0.0
    ''';

main() {
  test('running pub with no command displays usage', () =>
      runPub(args: [], output: USAGE_STRING));

  test('running pub with just --help displays usage', () =>
      runPub(args: ['--help'], output: USAGE_STRING));

  test('running pub with just -h displays usage', () =>
      runPub(args: ['-h'], output: USAGE_STRING));

  test('running pub with just --version displays version', () =>
      runPub(args: ['--version'], output: VERSION_STRING));

  group('an unknown command', () {
    test('displays an error message', () {
      runPub(args: ['quylthulg'],
          error: '''
          Unknown command "quylthulg".
          Run "pub help" to see available commands.
          ''',
          exitCode: 64);
    });
  });

  group('pub list', listCommand);
  group('pub install', installCommand);
  group('pub version', versionCommand);
}

listCommand() {
  // TODO(rnystrom): We don't currently have any sources that are cached, so
  // we can't test this right now.
  /*
  group('cache', () {
    test('treats an empty directory as a package', () {
      dir(cachePath, [
        dir('sdk', [
          dir('apple'),
          dir('banana'),
          dir('cherry')
        ])
      ]).scheduleCreate();

      runPub(args: ['list', 'cache'],
          output: '''
          From system cache:
            apple 0.0.0 (apple from sdk)
            banana 0.0.0 (banana from sdk)
            cherry 0.0.0 (cherry from sdk)
          ''');
    });
  });
  */
}

installCommand() {
  test('adds a dependent package', () {
    dir(sdkPath, [
      dir('lib', [
        dir('foo', [
          file('foo.dart', 'main() => "foo";')
        ])
      ])
    ]).scheduleCreate();

    dir(appPath, [
      file('pubspec.yaml', 'dependencies:\n  foo:')
    ]).scheduleCreate();

    schedulePub(args: ['install'],
        output: '''
        Dependencies installed!
        ''');

    dir(packagesPath, [
      dir('foo', [
        file('foo.dart', 'main() => "foo";')
      ])
    ]).scheduleValidate();

    run();
  });

  test('adds a transitively dependent package', () {
    dir(sdkPath, [
      dir('lib', [
        dir('foo', [
          file('foo.dart', 'main() => "foo";'),
          file('pubspec.yaml', 'dependencies:\n  bar:')
        ]),
        dir('bar', [
          file('bar.dart', 'main() => "bar";'),
        ])
      ])
    ]).scheduleCreate();

    dir(appPath, [
      file('pubspec.yaml', 'dependencies:\n  foo:')
    ]).scheduleCreate();

    schedulePub(args: ['install'],
        output: '''
        Dependencies installed!
        ''');

    dir(packagesPath, [
      dir('foo', [
        file('foo.dart', 'main() => "foo";')
      ]),
      dir('bar', [
        file('bar.dart', 'main() => "bar";'),
      ])
    ]).scheduleValidate();

    run();
  });

  test('checks out a package from Git', () {
    withGit(() {
      git('foo.git', [
        file('foo.dart', 'main() => "foo";')
      ]).scheduleCreate();

      dir(appPath, [
        file('pubspec.yaml', '''
dependencies:
  foo:
    git: ../foo.git
''')
      ]).scheduleCreate();

      schedulePub(args: ['install'],
          output: const RegExp(@"Dependencies installed!$"));

      dir(packagesPath, [
        dir('foo', [
          file('foo.dart', 'main() => "foo";')
        ])
      ]).scheduleValidate();

      run();
    });
  });

  test('checks out packages transitively from Git', () {
    withGit(() {
      git('foo.git', [
        file('foo.dart', 'main() => "foo";'),
        file('pubspec.yaml', '''
dependencies:
  bar:
    git: ../bar.git
''')
      ]).scheduleCreate();

      git('bar.git', [
        file('bar.dart', 'main() => "bar";')
      ]).scheduleCreate();

      dir(appPath, [
        file('pubspec.yaml', '''
dependencies:
  foo:
    git: ../foo.git
''')
      ]).scheduleCreate();

      schedulePub(args: ['install'],
          output: const RegExp("Dependencies installed!\$"));

      dir(packagesPath, [
        dir('foo', [
          file('foo.dart', 'main() => "foo";')
        ]),
        dir('bar', [
          file('bar.dart', 'main() => "bar";')
        ])
      ]).scheduleValidate();

      run();
    });
  });

  test('checks out a package from a pub server', () {
    servePackages("localhost", 3123, ['{name: foo, version: 1.2.3}']);

    dir(appPath, [
      file('pubspec.yaml', '''
dependencies:
  foo:
    repo:
      name: foo
      url: http://localhost:3123
    version: 1.2.3
''')
    ]).scheduleCreate();

    schedulePub(args: ['install'],
        output: const RegExp("Dependencies installed!\$"));

    dir(cachePath, [
      dir('repo', [
        dir('localhost%583123', [
          dir('foo-1.2.3', [
            file('pubspec.yaml', '{name: foo, version: 1.2.3}'),
            file('foo.dart', 'main() => print("foo 1.2.3");')
          ])
        ])
      ])
    ]).scheduleValidate();

    dir(packagesPath, [
      dir('foo', [
        file('pubspec.yaml', '{name: foo, version: 1.2.3}'),
        file('foo.dart', 'main() => print("foo 1.2.3");')
      ])
    ]).scheduleValidate();

    run();
  });

  test('checks out packages transitively from a pub server', () {
    servePackages("localhost", 3123, [
      '''
name: foo
version: 1.2.3
dependencies:
  bar:
    repo: {name: bar, url: http://localhost:3123}
    version: 2.0.4
''',
      '{name: bar, version: 2.0.3}',
      '{name: bar, version: 2.0.4}',
      '{name: bar, version: 2.0.5}',
    ]);

    dir(appPath, [
      file('pubspec.yaml', '''
dependencies:
  foo:
    repo:
      name: foo
      url: http://localhost:3123
    version: 1.2.3
''')
    ]).scheduleCreate();

    schedulePub(args: ['install'],
        output: const RegExp("Dependencies installed!\$"));

    dir(cachePath, [
      dir('repo', [
        dir('localhost%583123', [
          dir('foo-1.2.3', [
            file('pubspec.yaml', '''
name: foo
version: 1.2.3
dependencies:
  bar:
    repo: {name: bar, url: http://localhost:3123}
    version: 2.0.4
'''),
            file('foo.dart', 'main() => print("foo 1.2.3");')
          ]),
          dir('bar-2.0.4', [
            file('pubspec.yaml', '{name: bar, version: 2.0.4}'),
            file('bar.dart', 'main() => print("bar 2.0.4");')
          ])
        ])
      ])
    ]).scheduleValidate();

    dir(packagesPath, [
      dir('foo', [
            file('pubspec.yaml', '''
name: foo
version: 1.2.3
dependencies:
  bar:
    repo: {name: bar, url: http://localhost:3123}
    version: 2.0.4
'''),
        file('foo.dart', 'main() => print("foo 1.2.3");')
      ]),
      dir('bar', [
        file('pubspec.yaml', '{name: bar, version: 2.0.4}'),
        file('bar.dart', 'main() => print("bar 2.0.4");')
      ])
    ]).scheduleValidate();

    run();
  });
}

versionCommand() {
  test('displays the current version', () =>
    runPub(args: ['version'], output: VERSION_STRING));
}
