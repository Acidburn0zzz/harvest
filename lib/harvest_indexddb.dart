// Copyright (c) 2013, the project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed 
// by a Apache license that can be found in the LICENSE file.

/** Eventstore backed by IndexedDB */ 
library harvest_indexeddb;

import 'dart:indexed_db';

import 'package:log4dart/log4dart.dart';

import 'harvest.dart';
export 'harvest.dart';

part 'src/stores/indexdb/indexeddb_event_store.dart';

IDBConnection idbConnection(String name, String version) => new IDBConnection(name, version);