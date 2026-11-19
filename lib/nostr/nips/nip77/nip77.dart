import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' show hex;
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';

const int _protocolVersion = 0x61;
const int _idSize = 32;
const int _fingerprintSize = 16;
const int _modeSkip = 0;
const int _modeFingerprint = 1;
const int _modeIdList = 2;

/// {@template nip77_item}
/// A `(timestamp, id)` pair stored for negentropy reconciliation.
///
/// `id` is normally the 32-byte event id. Bounds exchanged during
/// reconciliation may carry a shorter id prefix, which is why [id] is a byte
/// list rather than a hex string.
/// {@endtemplate}
class NostrNegentropyItem {
  /// {@macro nip77_item}
  NostrNegentropyItem({required this.timestamp, required this.id});

  /// UNIX timestamp in seconds.
  final int timestamp;

  /// Event id bytes (32 bytes for stored items, a prefix for bounds).
  final Uint8List id;
}

/// {@template nip77_storage}
/// Sorted, sealed vector of event ids used by [NostrNegentropy].
///
/// Insert every known event, then [seal] before reconciling. Sealing sorts
/// the items and rejects duplicate `(timestamp, id)` pairs.
/// {@endtemplate}
class NostrNegentropyStorageVector {
  final List<NostrNegentropyItem> _items = [];
  bool _sealed = false;

  /// Whether [seal] has been called.
  bool get isSealed => _sealed;

  /// Number of stored items.
  int get length {
    _checkSealed();
    return _items.length;
  }

  /// Adds an event id (64-char hex) at [timestamp].
  void insert(int timestamp, String id) {
    if (_sealed) {
      throw StateError('negentropy storage is already sealed');
    }

    final idBytes = Uint8List.fromList(hex.decode(id));
    if (idBytes.length != _idSize) {
      throw ArgumentError.value(id, 'id', 'must be a 32-byte hex id');
    }

    _items.add(NostrNegentropyItem(timestamp: timestamp, id: idBytes));
  }

  /// Sorts the items and locks the storage against further inserts.
  void seal() {
    if (_sealed) {
      throw StateError('negentropy storage is already sealed');
    }
    _sealed = true;
    _items.sort(_itemCompare);

    for (var i = 1; i < _items.length; i++) {
      if (_itemCompare(_items[i - 1], _items[i]) == 0) {
        throw StateError('duplicate negentropy item');
      }
    }
  }

  /// Unlocks the storage so more items can be inserted.
  void unseal() {
    _sealed = false;
  }

  /// Returns the item at [index].
  NostrNegentropyItem getItem(int index) {
    _checkSealed();
    if (index < 0 || index >= _items.length) {
      throw RangeError.index(index, _items);
    }
    return _items[index];
  }

  /// Calls [callback] for each item in `[begin, end)` until it returns false.
  void iterate(
    int begin,
    int end,
    bool Function(NostrNegentropyItem item, int index) callback,
  ) {
    _checkSealed();
    _checkBounds(begin, end);

    for (var i = begin; i < end; i++) {
      if (!callback(_items[i], i)) {
        break;
      }
    }
  }

  /// Returns the first index in `[begin, end)` not less than [bound].
  int findLowerBound(int begin, int end, NostrNegentropyItem bound) {
    _checkSealed();
    _checkBounds(begin, end);

    var first = begin;
    var count = end - begin;

    while (count > 0) {
      final step = count ~/ 2;
      if (_itemCompare(_items[first + step], bound) < 0) {
        first += step + 1;
        count -= step + 1;
      } else {
        count = step;
      }
    }

    return first;
  }

  /// Fingerprint of the items in `[begin, end)`.
  Uint8List fingerprint(int begin, int end) {
    _checkSealed();
    _checkBounds(begin, end);

    final accumulator = _Accumulator();
    for (var i = begin; i < end; i++) {
      accumulator.add(_items[i].id);
    }

    return accumulator.fingerprint(end - begin);
  }

  void _checkSealed() {
    if (!_sealed) {
      throw StateError('negentropy storage is not sealed');
    }
  }

  void _checkBounds(int begin, int end) {
    if (begin > end || end > _items.length) {
      throw RangeError('bad negentropy range [$begin, $end)');
    }
  }
}

/// {@template nip77_result}
/// Outcome of one [NostrNegentropy.reconcile] round.
///
/// [message] is the reply to send back (`null` when reconciliation is done).
/// [have] lists ids present locally but missing remotely; [need] lists ids
/// present remotely but missing locally.
/// {@endtemplate}
class NostrNegentropyReconcileResult {
  /// {@macro nip77_result}
  const NostrNegentropyReconcileResult({
    required this.message,
    required this.have,
    required this.need,
  });

  /// Hex-encoded reply, or `null` when both sides are in sync.
  final String? message;

  /// Ids known locally but not remotely.
  final List<String> have;

  /// Ids known remotely but not locally.
  final List<String> need;
}

/// {@template nip77}
/// NIP-77 negentropy set reconciliation.
///
/// Implements the client side of the NIP-77 algorithm (Doug Hoyte's
/// negentropy): varint framing, timestamp bounds, sorted fingerprints and
/// id-list splitting.
///
/// This is a pure protocol implementation: it produces and consumes
/// `NEG-OPEN`/`NEG-MSG`/`NEG-CLOSE` payloads but owns no relay connection.
/// Feed [reconcile] the payload from a `NEG-MSG` frame, send back
/// [NostrNegentropyReconcileResult.message], and stop when it is `null`.
/// {@endtemplate}
class NostrNegentropy {
  /// {@macro nip77}
  NostrNegentropy(this.storage, {this.frameSizeLimit = 60000}) {
    if (frameSizeLimit < 4096) {
      throw ArgumentError.value(
        frameSizeLimit,
        'frameSizeLimit',
        'must be at least 4096',
      );
    }
  }

  /// Sealed storage reconciled against the relay.
  final NostrNegentropyStorageVector storage;

  /// Maximum size of an outgoing frame, in bytes.
  final int frameSizeLimit;

  /// Sentinel timestamp used for the open-ended upper bound.
  ///
  /// Matches JavaScript's `Number.MAX_SAFE_INTEGER` so wire output stays
  /// compatible with `nostr-tools`.
  static const int maxTimestamp = 0x1FFFFFFFFFFFFF;

  int _lastTimestampIn = 0;
  int _lastTimestampOut = 0;

  /// Builds the initial `NEG-OPEN` payload.
  String initiate() {
    final output = BytesBuilder()..addByte(_protocolVersion);
    _splitRange(
      0,
      storage.length,
      NostrNegentropyItem(timestamp: maxTimestamp, id: Uint8List(0)),
      output,
    );

    return _bytesToHex(output.takeBytes());
  }

  /// Processes one remote payload and returns the local response.
  NostrNegentropyReconcileResult reconcile(String queryMessage) {
    final query = _Reader(Uint8List.fromList(hex.decode(queryMessage)));

    _lastTimestampIn = 0;
    _lastTimestampOut = 0;

    final fullOutput = BytesBuilder()..addByte(_protocolVersion);

    final version = query.shift();
    if (version < 0x60 || version > 0x6f) {
      throw const FormatException('invalid negentropy protocol version byte');
    }
    if (version != _protocolVersion) {
      throw FormatException(
        'unsupported negentropy protocol version: ${version - 0x60}',
      );
    }

    final storageSize = storage.length;
    var prevBound = NostrNegentropyItem(timestamp: 0, id: Uint8List(0));
    var prevIndex = 0;
    var skip = false;

    final have = <String>[];
    final need = <String>[];

    while (query.length != 0) {
      final output = BytesBuilder();

      void doSkip() {
        if (!skip) {
          return;
        }
        skip = false;
        output
          ..add(_encodeBound(prevBound))
          ..add(_encodeVarInt(_modeSkip));
      }

      final currBound = _decodeBound(query);
      final mode = _decodeVarInt(query);

      final lower = prevIndex;
      final upper = storage.findLowerBound(prevIndex, storageSize, currBound);

      switch (mode) {
        case _modeSkip:
          skip = true;
        case _modeFingerprint:
          final theirFingerprint = query.shiftN(_fingerprintSize);
          final ourFingerprint = storage.fingerprint(lower, upper);

          if (_bytesCompare(theirFingerprint, ourFingerprint) != 0) {
            doSkip();
            _splitRange(lower, upper, currBound, output);
          } else {
            skip = true;
          }
        case _modeIdList:
          final numIds = _decodeVarInt(query);
          final theirElems = <String, Uint8List>{};
          for (var i = 0; i < numIds; i++) {
            final element = query.shiftN(_idSize);
            theirElems[_bytesToHex(element)] = element;
          }

          skip = true;
          storage.iterate(lower, upper, (item, _) {
            final id = _bytesToHex(item.id);
            if (!theirElems.containsKey(id)) {
              have.add(id);
            } else {
              theirElems.remove(id);
            }
            return true;
          });

          need.addAll(theirElems.keys);
        default:
          throw const FormatException('unexpected negentropy mode');
      }

      if (fullOutput.length + output.length > frameSizeLimit - 200) {
        final remaining = storage.fingerprint(upper, storageSize);
        fullOutput
          ..add(
            _encodeBound(
              NostrNegentropyItem(timestamp: maxTimestamp, id: Uint8List(0)),
            ),
          )
          ..add(_encodeVarInt(_modeFingerprint))
          ..add(remaining);
        break;
      }

      fullOutput.add(output.takeBytes());
      prevIndex = upper;
      prevBound = currBound;
    }

    final bytes = fullOutput.takeBytes();

    return NostrNegentropyReconcileResult(
      message: bytes.length == 1 ? null : _bytesToHex(bytes),
      have: have,
      need: need,
    );
  }

  /// Builds a `NEG-OPEN` message for [filter].
  static String negOpenMessage({
    required String subscriptionId,
    required NostrFilter filter,
    required String initialMessage,
  }) {
    return jsonEncode([
      'NEG-OPEN',
      subscriptionId,
      filter.toMap(),
      initialMessage,
    ]);
  }

  /// Builds a `NEG-MSG` message.
  static String negMsgMessage({
    required String subscriptionId,
    required String message,
  }) {
    return jsonEncode(['NEG-MSG', subscriptionId, message]);
  }

  /// Builds a `NEG-CLOSE` message.
  static String negCloseMessage(String subscriptionId) {
    return jsonEncode(['NEG-CLOSE', subscriptionId]);
  }

  void _splitRange(
    int lower,
    int upper,
    NostrNegentropyItem upperBound,
    BytesBuilder output,
  ) {
    const buckets = 16;
    final numElems = upper - lower;

    if (numElems < buckets * 2) {
      output
        ..add(_encodeBound(upperBound))
        ..add(_encodeVarInt(_modeIdList))
        ..add(_encodeVarInt(numElems));
      storage.iterate(lower, upper, (item, _) {
        output.add(item.id);
        return true;
      });
      return;
    }

    final itemsPerBucket = numElems ~/ buckets;
    final bucketsWithExtra = numElems % buckets;
    var curr = lower;

    for (var i = 0; i < buckets; i++) {
      final bucketSize = itemsPerBucket + (i < bucketsWithExtra ? 1 : 0);
      final ourFingerprint = storage.fingerprint(curr, curr + bucketSize);
      curr += bucketSize;

      final NostrNegentropyItem nextBound;
      if (curr == upper) {
        nextBound = upperBound;
      } else {
        nextBound = _minimalBound(
          storage.getItem(curr - 1),
          storage.getItem(curr),
        );
      }

      output
        ..add(_encodeBound(nextBound))
        ..add(_encodeVarInt(_modeFingerprint))
        ..add(ourFingerprint);
    }
  }

  int _decodeTimestampIn(_Reader encoded) {
    var timestamp = _decodeVarInt(encoded);
    timestamp = timestamp == 0 ? maxTimestamp : timestamp - 1;

    if (_lastTimestampIn == maxTimestamp || timestamp == maxTimestamp) {
      _lastTimestampIn = maxTimestamp;
      return maxTimestamp;
    }

    timestamp += _lastTimestampIn;
    _lastTimestampIn = timestamp;

    return timestamp;
  }

  NostrNegentropyItem _decodeBound(_Reader encoded) {
    final timestamp = _decodeTimestampIn(encoded);
    final length = _decodeVarInt(encoded);
    if (length > _idSize) {
      throw const FormatException('negentropy bound key too long');
    }

    return NostrNegentropyItem(
      timestamp: timestamp,
      id: encoded.shiftN(length),
    );
  }

  Uint8List _encodeTimestampOut(int timestamp) {
    if (timestamp == maxTimestamp) {
      _lastTimestampOut = maxTimestamp;
      return _encodeVarInt(0);
    }

    final delta = timestamp - _lastTimestampOut;
    _lastTimestampOut = timestamp;

    return _encodeVarInt(delta + 1);
  }

  Uint8List _encodeBound(NostrNegentropyItem key) {
    final output = BytesBuilder()
      ..add(_encodeTimestampOut(key.timestamp))
      ..add(_encodeVarInt(key.id.length))
      ..add(key.id);

    return output.takeBytes();
  }

  NostrNegentropyItem _minimalBound(
    NostrNegentropyItem prev,
    NostrNegentropyItem curr,
  ) {
    if (curr.timestamp != prev.timestamp) {
      return NostrNegentropyItem(
        timestamp: curr.timestamp,
        id: Uint8List(0),
      );
    }

    var sharedPrefixBytes = 0;
    while (sharedPrefixBytes < _idSize &&
        curr.id[sharedPrefixBytes] == prev.id[sharedPrefixBytes]) {
      sharedPrefixBytes++;
    }

    return NostrNegentropyItem(
      timestamp: curr.timestamp,
      id: Uint8List.fromList(
        curr.id.sublist(0, sharedPrefixBytes + 1),
      ),
    );
  }
}

/// {@template nip77_session}
/// Message-level NIP-77 sync state for one subscription.
///
/// Holds the [filter] and [NostrNegentropy] storage, emits the `NEG-OPEN`
/// payload and turns each relay frame into the next message to send. The
/// relay transport itself is the caller's responsibility.
/// {@endtemplate}
class NostrNegentropySession {
  /// {@macro nip77_session}
  NostrNegentropySession({
    required this.storage,
    required this.filter,
    this.subscriptionId = 'negentropy',
    int frameSizeLimit = 60000,
  }) : _negentropy = NostrNegentropy(
          storage,
          frameSizeLimit: frameSizeLimit,
        );

  /// Local id storage being reconciled.
  final NostrNegentropyStorageVector storage;

  /// Filter scoping the reconciliation.
  final NostrFilter filter;

  /// Subscription id used in `NEG-*` frames.
  final String subscriptionId;

  final NostrNegentropy _negentropy;

  /// Ids the relay is missing.
  final List<String> have = [];

  /// Ids we are missing.
  final List<String> need = [];

  /// Reason the relay closed the sync, if any.
  String? closeReason;

  /// Whether reconciliation finished or the relay closed it.
  bool isClosed = false;

  /// The `NEG-OPEN` frame to send.
  String startMessage() {
    return NostrNegentropy.negOpenMessage(
      subscriptionId: subscriptionId,
      filter: filter,
      initialMessage: _negentropy.initiate(),
    );
  }

  /// Handles a decoded relay frame and returns the reply to send, or `null`
  /// when the sync is done or the relay reported an error.
  String? handleMessage(List<dynamic> data) {
    if (data.isEmpty) {
      throw ArgumentError('empty negentropy message');
    }

    switch (data.first) {
      case 'NEG-MSG':
        if (data.length < 3) {
          throw ArgumentError('NEG-MSG is missing its payload');
        }

        final result = _negentropy.reconcile(data[2] as String);
        have.addAll(result.have);
        need.addAll(result.need);

        final message = result.message;
        if (message == null) {
          isClosed = true;
          return null;
        }

        return NostrNegentropy.negMsgMessage(
          subscriptionId: subscriptionId,
          message: message,
        );
      case 'NEG-CLOSE':
        closeReason = data.length > 2 ? '${data[2]}' : null;
        isClosed = true;
        return null;
      case 'NEG-ERR':
        closeReason = data.length > 2 ? '${data[2]}' : 'unknown';
        isClosed = true;
        return null;
      default:
        throw ArgumentError('unexpected negentropy message: ${data.first}');
    }
  }

  /// The `NEG-CLOSE` frame to send when cancelling the sync.
  String closeMessage() {
    return NostrNegentropy.negCloseMessage(subscriptionId);
  }
}

/// {@template nip77_facade}
/// Stateless NIP-77 entry point exposed as `Nostr.nips.nip77`.
///
/// Creates reconciliation sessions and negentropy instances; all state lives
/// in the caller's [NostrNegentropyStorageVector].
/// {@endtemplate}
class NostrNip77 {
  /// {@macro nip77_facade}
  const NostrNip77();

  /// Creates a message-level sync session for [filter].
  NostrNegentropySession session({
    required NostrNegentropyStorageVector storage,
    required NostrFilter filter,
    String subscriptionId = 'negentropy',
    int frameSizeLimit = 60000,
  }) {
    return NostrNegentropySession(
      storage: storage,
      filter: filter,
      subscriptionId: subscriptionId,
      frameSizeLimit: frameSizeLimit,
    );
  }

  /// Creates a negentropy reconciler over [storage].
  NostrNegentropy negentropy(
    NostrNegentropyStorageVector storage, {
    int frameSizeLimit = 60000,
  }) {
    return NostrNegentropy(storage, frameSizeLimit: frameSizeLimit);
  }
}

class _Reader {
  _Reader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  int get length => _bytes.length - _offset;

  int shift() {
    if (length == 0) {
      throw const FormatException('parse ends prematurely');
    }
    return _bytes[_offset++];
  }

  Uint8List shiftN(int count) {
    if (length < count) {
      throw const FormatException('parse ends prematurely');
    }

    final out = Uint8List.fromList(
      _bytes.sublist(_offset, _offset + count),
    );
    _offset += count;

    return out;
  }
}

class _Accumulator {
  final Uint8List buf = Uint8List(_idSize);

  void add(Uint8List other) {
    var carry = 0;
    for (var i = 0; i < _idSize; i++) {
      final sum = buf[i] + other[i] + carry;
      buf[i] = sum & 0xff;
      carry = sum >> 8;
    }
  }

  Uint8List fingerprint(int n) {
    final input = BytesBuilder()
      ..add(buf)
      ..add(_encodeVarInt(n));

    final digest = sha256.convert(input.takeBytes()).bytes;

    return Uint8List.fromList(digest.sublist(0, _fingerprintSize));
  }
}

int _decodeVarInt(_Reader reader) {
  var result = 0;

  while (true) {
    if (reader.length == 0) {
      throw const FormatException('parse ends prematurely');
    }

    final byte = reader.shift();
    result = (result << 7) | (byte & 127);

    if ((byte & 128) == 0) {
      break;
    }
  }

  return result;
}

Uint8List _encodeVarInt(int n) {
  if (n == 0) {
    return Uint8List.fromList(const [0]);
  }

  final groups = <int>[];
  var value = n;
  while (value != 0) {
    groups.add(value & 127);
    value >>= 7;
  }

  final out = groups.reversed.toList();
  for (var i = 0; i < out.length - 1; i++) {
    out[i] |= 128;
  }

  return Uint8List.fromList(out);
}

int _bytesCompare(Uint8List a, Uint8List b) {
  final length = a.length < b.length ? a.length : b.length;

  for (var i = 0; i < length; i++) {
    if (a[i] < b[i]) {
      return -1;
    }
    if (a[i] > b[i]) {
      return 1;
    }
  }

  if (a.length > b.length) {
    return 1;
  }
  if (a.length < b.length) {
    return -1;
  }

  return 0;
}

int _itemCompare(NostrNegentropyItem a, NostrNegentropyItem b) {
  if (a.timestamp == b.timestamp) {
    return _bytesCompare(a.id, b.id);
  }

  return a.timestamp.compareTo(b.timestamp);
}

String _bytesToHex(Uint8List bytes) => hex.encode(bytes);
