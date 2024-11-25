module table;

import std::io;
import libc;

import value;
import object;
import memory;

// TODO test using std::collections::map

const TABLE_MAX_LOAD = 0.75;

struct Table {
  int count;
  int capacity;
  Entry* entries;
}

struct Entry {
  ObjString* key;
  Value value;
}

fn void initTable(Table* table) {
  table.count = 0;
  table.capacity = 0;
  table.entries = null;
}

fn void freeTable(Table* table) {
  memory::free_array(Entry, table.entries, table.capacity);
  initTable(table);
}

fn Entry* findEntry(Entry* entries, int capacity, ObjString* key) {
  uint index = key.hash & (capacity - 1);
  Entry* tombstone = null;
  for (;;) {
    Entry* entry = &entries[index];
    if (entry.key == null) {
      if (value::is_nil(entry.value)) {
        // Empty entry.
        return tombstone != null ? tombstone : entry;
      } else {
        // We found a tombstone.
        if (tombstone == null) tombstone = entry;
      }
    } else if (entry.key == key) {
      // We found the key.
      return entry;
    }
    index = (index + 1) & (capacity - 1);
  }
}

fn bool tableGet(Table* table, ObjString* key, Value* value) {
  if (table.count == 0) return false;

  Entry* entry = findEntry(table.entries, table.capacity, key);
  if (entry.key == null) return false;

  *value = entry.value;
  return true;
}

fn void adjustCapacity(Table* table, int capacity) {
  Entry* entries = memory::allocate(Entry, capacity);
  for (int i = 0; i < capacity; i++) {
    entries[i].key = null;
    entries[i].value = value::nil_val();
  }
  
  table.count = 0;
  for (int i = 0; i < table.capacity; i++) {
    Entry* entry = &table.entries[i];
    if (entry.key == null) continue;

    Entry* dest = findEntry(entries, capacity, entry.key);
    dest.key = entry.key;
    dest.value = entry.value;
    table.count++;
  }

  memory::free_array(Entry, table.entries, table.capacity);
  table.entries = entries;
  table.capacity = capacity;
}

fn bool tableSet(Table* table, ObjString* key, Value value) {
  if ((double) table.count + 1 > table.capacity * TABLE_MAX_LOAD) {
    int capacity = memory::grow_capacity(table.capacity);
    adjustCapacity(table, capacity);
  }
  Entry* entry = findEntry(table.entries, table.capacity, key);
  bool isNewKey = entry.key == null;
  if (isNewKey && value::is_nil(entry.value)) table.count++;

  entry.key = key;
  entry.value = value;
  return isNewKey;
}

fn bool tableDelete(Table* table, ObjString* key) {
  if (table.count == 0) return false;

  // Find the entry.
  Entry* entry = findEntry(table.entries, table.capacity, key);
  if (entry.key == null) return false;

  // Place a tombstone in the entry.
  entry.key = null;
  entry.value = value::bool_val(true);
  return true;
}

fn void tableAddAll(Table* from, Table* to) {
  for (int i = 0; i < from.capacity; i++) {
    Entry* entry = &from.entries[i];
    if (entry.key != null) {
      tableSet(to, entry.key, entry.value);
    }
  }
}

fn ObjString* tableFindString(Table* table, char* chars, int length, uint hash) {
  if (table.count == 0) return null;

  uint index = hash & (table.capacity - 1);
  for (;;) {
    Entry* entry = &table.entries[index];
    if (entry.key == null) {
      // Stop if we find an empty non-tombstone entry.
      if (value::is_nil(entry.value)) return null;
    } else if (entry.key.length == length &&
        entry.key.hash == hash && libc::memcmp(entry.key.chars, chars, length) == 0) {
      // We found it.
      return entry.key;
    }

    index = (index + 1) & (table.capacity - 1);
  }
}

fn void tableRemoveWhite(Table* table) {
  for (int i = 0; i < table.capacity; i++) {
    Entry* entry = &table.entries[i];
    if (entry.key != null && !entry.key.obj.isMarked) {
      tableDelete(table, entry.key);
    }
  }
}

fn void markTable(Table* table) {
  for (int i = 0; i < table.capacity; i++) {
    Entry* entry = &table.entries[i];
    memory::markObject((Obj*)entry.key);
    memory::markValue(entry.value);
  }
}