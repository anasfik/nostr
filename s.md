# SHA256

## Javascript

### input

```js
(async () => {
  let data = "hello";

  let hashed = bitcoinjs.crypto.sha256(data);

  console.log(hashed.toString("hex"));
})();
```

### output

```txt
8855508aade16ec573d21e6a485dfd0a7624085c1a14b5ecdd6485de0c6839a4
```

## Dart

### input

```Dart
final data = "hello";
final hash = crypto.sha256.convert(utf8.encode(data)).toString();

print(hash);
```

toString() is ensured to return a hex string

## Output

```txt
2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
```
