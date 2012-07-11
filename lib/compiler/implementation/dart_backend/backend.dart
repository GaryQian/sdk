// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

class BailoutException {
  final String reason;

  const BailoutException(this.reason);
}

class DartBackend extends Backend {
  final List<CompilerTask> tasks;
  final UnparseValidator unparseValidator;

  Map<Element, TreeElements> get resolvedElements() =>
      compiler.enqueuer.resolution.resolvedElements;

  DartBackend(Compiler compiler, [bool validateUnparse = false])
      : tasks = <CompilerTask>[],
      unparseValidator = new UnparseValidator(compiler, validateUnparse),
      super(compiler) {
    tasks.add(unparseValidator);
  }

  void enqueueHelpers(Enqueuer world) {
    // TODO(antonm): Implement this method, if needed.
  }

  CodeBlock codegen(WorkItem work) { return new CodeBlock(null, null); }

  void processNativeClasses(Enqueuer world,
                            Collection<LibraryElement> libraries) {
  }

  void assembleProgram() {
    resolvedElements.forEach((element, treeElements) {
      unparseValidator.check(element);
    });

    // TODO(antonm): Eventually bailouts will be proper errors.
    void bailout(String reason) {
      throw new BailoutException(reason);
    }

    try {
      StringBuffer sb = new StringBuffer();
      resolvedElements.forEach((element, treeElements) {
        if (!element.isTopLevel()) {
          bailout('Cannot process non top-level $element');
        }

        if (element.isField()) {
          // Add modifiers first.
          sb.add(element.modifiers.toString());
          sb.add(' ');
          // Figure out type.
          if (element is VariableElement) {
            VariableListElement variables = element.variables;
            if (variables.type !== null) {
              sb.add(variables.type);
              sb.add(' ');
            }
          }
          // TODO(smok): Maybe not rely on node unparsing,
          // but unparse initializer manually.
          sb.add(element.parseNode(compiler).unparse());
          sb.add(';');
        } else {
          sb.add(element.parseNode(compiler).unparse());
        }
      });
      compiler.assembledCode = sb.toString();
    } catch (BailoutException e) {
      compiler.assembledCode = '''
main() {
  final bailout_reason = "${e.reason}";
}
''';
    }
  }

  log(String message) => compiler.log('[DartBackend] $message');
}
