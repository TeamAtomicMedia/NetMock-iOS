# ``NetMockCore``

Core data types, parsing, validation, and capture functionality for NetMock files.

## Overview

NetMockCore provides the fundamental building blocks for working with NetMock (`.nm`) files without requiring URLProtocol integration. This module is ideal for:

- **Build Tools**: Parse and generate `.nm` files in build scripts
- **Command-Line Utilities**: Work with NetMock files from the terminal
- **File Generators**: Create NetMock files programmatically
- **Parsers**: Extract information from existing `.nm` files

If you need full mocking functionality with URLProtocol integration, use the ``NetMock`` module instead, which re-exports everything from NetMockCore.

## Key Features

### Parsing

Parse NetMock files from strings or file URLs:

```swift
import NetMockCore

// Parse from a file
let document = try Document(
    fileURL: fileURL,
    urlParser: URL.init(string:)
)

// Parse from a string
var input = fileContents[...]
let document = try Document.parser.run(&input)
```

### Generation

Create NetMock documents programmatically:

```swift
let document = Document(
    version: VersionNumber(major: 3, minor: 0, patch: 0),
    header: Request(
        method: .GET,
        url: URL(string: "https://api.example.com/users")!
    ),
    sequence: [.code(200)],
    body: [
        Response(
            header: Response.Header(code: 200, labels: ["Success"]),
            body: jsonData
        )
    ]
)

// Convert to string for saving
let fileContents = document.description
```

### Capture

Capture network responses and organise them into NetMock documents:

```swift
import NetMockCore

// Create an entry from a captured response
let entry = DocumentStoreEntry(
    method: .GET,
    url: URL(string: "https://api.example.com/users")!,
    statusCode: 200,
    body: responseData
)

// Add to the document store
await DocumentStore.shared.add(entry)

// Save to disk as .nm files
await DocumentStore.shared.save()
```

### Validation

Validate NetMock documents to ensure they follow format rules:

```swift
do {
    try document.validate()
} catch Document.ValidationError.invalidHeaderSequence {
    print("#Live must only appear at the end of the sequence")
} catch Document.ValidationError.invalidLabels(let labels) {
    print("Invalid labels with # prefix: \(labels)")
}
```

## NetMock File Format

NetMockCore understands the complete `.nm` file format:

### Structure

```
[Optional Version Header]
HTTP_METHOD URL [SEQUENCE...]

STATUS_CODE [LABEL...]
[RESPONSE_BODY]
---
[Additional responses...]
```

### Example

```
NetMock 3.0.0
GET https://api.example.com/users 200 500

200 Success
{
  "users": [{"id": 1, "name": "Alice"}]
}
---
500 Error
{
  "error": "Internal server error"
}
```

## Data Model

The core data model consists of:

- **``Document``**: A complete NetMock file with version, request, sequence, and responses
- **``Request``**: HTTP method and URL identifying the mocked endpoint
- **``Response``**: Status code, labels, and body data for a mock response
- **``Identifier``**: Response selector (status code, label, or `#Live`)
- **``VersionNumber``**: Semantic version of the file format

## Topics

### Documents

- ``Document``
- ``Document/init(version:header:sequence:body:)``
- ``Document/init(fileURL:urlParser:)``
- ``Document/validate()``

### HTTP Components

- ``Request``
- ``Response``
- ``Method``

### Response Selection

- ``Identifier``

### Capture & Storage

- ``DocumentStore``
- ``DocumentStoreEntry``

### Errors

- ``LoadError``

### Utilities

- ``VersionNumber``
- ``setupLogger``
- ``requestLogger``
- ``captureLogger``

### Validation

- ``Document/ValidationError``
