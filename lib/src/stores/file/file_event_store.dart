// Copyright (c) 2013, the project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed 
// by a Apache license that can be found in the LICENSE file.

part of harvest_file;

/**
 * File backed event store
 * 
 * TODO fix this so it works again after switching to ASYNC api
 */
class FileEventStore implements EventStore {
  /**
   * Store events in files in the [_storeFolder] directory. Each aggregate gets its own file.  
   */ 
  FileEventStore(this._storeFolder, DomainEventFactory eventFactory):
    _logger = LoggerFactory.getLoggerFor(FileEventStore),
    _store = new Map<Guid, File>(), 
    _messageBus = new MessageBus(),
    _jsonSerializer = new JsonSerializer(eventFactory);
  
  Future<int> saveEvents(Guid aggregateId, List<DomainEvent> events, int expectedVersion) {
    var completer = new Completer<int>();
    
    if(!_store.containsKey(aggregateId)) {
      // TODO switch to using path for windows support
      var aggregteFilePath = "${_storeFolder.path}/${aggregateId}.json";
      var aggregateFile = new File(aggregteFilePath);
      aggregateFile.exists().then((bool exists) {
        if(exists) {
          _logger.debug("using existing aggregate file $aggregteFilePath");
          _store[aggregateId] = aggregateFile;
          _readJsonFile(aggregateFile).then((Map json) {
            _saveEventsFor(aggregateId, events, expectedVersion, completer, aggregateFile, json);
          });
        } else {
          _logger.debug("creating aggregate file $aggregteFilePath");
          aggregateFile.create().then((File file) {
            _store[aggregateId] = file;
            _saveEventsFor(aggregateId, events, expectedVersion, completer, file, {"eventlog":[]});
          });
        }
      });
    } else {
      var aggregateFile = _store[aggregateId];
      _readJsonFile(aggregateFile).then((Map json) {
        _saveEventsFor(aggregateId, events, expectedVersion, completer, aggregateFile, json);
      });
    }
    
    return completer.future; 
  }
  
  Future<Map> _readJsonFile(File file) {
    var completer = new Completer<Map>();
    file.readAsString().then((String text) {
      completer.complete(JSON.parse(text));
    });
    return completer.future;
  }
  
  _saveEventsFor(Guid aggregateId, List<DomainEvent> events, int expectedVersion, Completer<int> completer, File aggregateFile, Map data) {
    if(!data.containsKey("eventlog")) {
      completer.completeError(new ArgumentError("malformed data in file ${aggregateFile.fullPathSync()}"));
    } 
    var eventDescriptors = _jsonSerializer.loadJsonEventDescriptors(data["eventData"]);
    
    // TODO duplicated code begin
    if(expectedVersion != -1 && eventDescriptors.last.version != expectedVersion) {
      completer.completeError(new ConcurrencyError());
    }
    for(DomainEvent event in events) {
      expectedVersion++;
      event.version = expectedVersion;
      eventDescriptors.add(new DomainEventDescriptor(aggregateId, event));
      _logger.debug("saving event ${event.runtimeType} for aggregate ${aggregateId}");
    }
    // TODO duplicated code end
    
    var jsonEventDescriptors = _jsonSerializer.writeJsonEventDescriptors(eventDescriptors);
    _storeJsonFile(aggregateFile, jsonEventDescriptors).then((f) {
      // TODO duplicated code begin
      for(DomainEvent event in events) {
        _messageBus.fire(event);
      }
      completer.complete(events.length);
      // TODO duplicated code end
    });
  }
  
  Future<File> _storeJsonFile(File file, Map json) {
    var completer = new Completer<File>();
    var text = JSON.stringify(json);
    file.open(FileMode.WRITE).then((output) {
      output.writeString(text).then((r) {
        // TODO remove these        
        r.flushSync();
        completer.complete(file);
      });
    });
    return completer.future;
  }
  
  Future<List<DomainEvent>> getEventsForAggregate(Guid aggregateId) {
    /*
    var completer = new Completer<List<DomainEvent>>();
    
    if(!_store.containsKey(aggregateId)) {
      completer.completeException(new AggregateNotFoundException(aggregateId));
    } 
    var eventDescriptors = _store[aggregateId];
    Expect.isTrue(eventDescriptors.length > 0);
    List<DomainEvent> events = eventDescriptors.map((DomainEventDescriptor desc) => desc.eventData);
    completer.complete(events);
    
    return completer.future; 
    */
  }
  
  final Map<Guid, File> _store;
  final Directory _storeFolder;
  final MessageBus _messageBus;
  final Logger _logger;
  final JsonSerializer _jsonSerializer;
}

