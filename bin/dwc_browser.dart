// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Compiles Dart Web Components from within a Chrome extension.
 * The Chrome extension logic exists outside of Dart as Dart does not support
 * Chrome extension APIs at this time.
 */
library dwc_browser;

import 'dart:html';
import 'dart:uri';
import 'package:web_components/src/compiler.dart';
import 'package:web_components/src/file_system.dart';
import 'package:web_components/src/file_system/browser.dart';
import 'package:web_components/src/file_system/path.dart';
import 'package:web_components/src/messages.dart';
import 'package:web_components/src/options.dart';
import 'package:web_components/src/utils.dart';
import 'package:js/js.dart' as js;

FileSystem fileSystem;

void main() {
  js.scoped(() {
    js.context.setOnParseCallback(new js.Callback.many(parse));
  });
}

/**
 * Process the input file at [sourceUri] with the 'dwc' compiler.
 * [sourcePagePort] is a Chrome extension port used to communicate back to the
 * source page that will consume these proxied urls.
 * See extension/background.js.
 */
void parse(js.Proxy sourcePagePort, String sourceUri) {
  // TODO(jacobr): we need to send error messages back to sourcePagePort.
  js.retain(sourcePagePort);
  print("Processing: $sourceUri");
  Uri uri = new Uri.fromString(sourceUri);
  fileSystem = new BrowserFileSystem(uri.scheme, sourcePagePort);
  // TODO(jacobr): provide a way to pass in options.
  var options = CompilerOptions.parse(['--no-colors', uri.path]);
  messages = new Messages(options: options);
  asyncTime('Compiled $sourceUri', () {
    var compiler = new Compiler(fileSystem, options);
    return compiler.run().chain((_) {
      for (var file in compiler.output) {
        fileSystem.writeString(file.path, file.contents);
      }
      var ret = fileSystem.flush();
      js.release(sourcePagePort);
      return ret;
    });
  }, printTime: true);
}
