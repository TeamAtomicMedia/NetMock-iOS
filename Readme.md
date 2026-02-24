# NetMock

NetMock is a tool to swap in mock responses for API calls, for use in offline app configurations and unit/UI tests.
NetMock will inject the mock responses, where defined via nm files, and fall back to live API calls where a NetMock file can't be found.

## Package Structure

NetMock is organised into two modules:

- **NetMockCore**: Core data types, parsing, validation, and capture functionality. Use this module if you only need to parse or generate NetMock files without URLProtocol integration. This is useful for build tools, scripts, or utilities that work with `.nm` files.

- **NetMock**: Full mocking functionality including URLProtocol integration. This module depends on and re-exports NetMockCore, providing the complete NetMock experience.

**For most users**, simply `import NetMock` to access everything you need. The modular structure allows advanced users to depend on only `NetMockCore` for lightweight parsing and file generation without pulling in URLProtocol dependencies.

## Setup

Make sure you initialise NetMock before use:
```swift
NetMock.shared.initialise()
// Or, if using in a package:
NetMock.shared.initialise(bundle: .module)
```

You may then add NetMock files to your offline app target, or unit test target, and they will be included in the Bundle and detected by NetMock.

---

To apply NetMock to a single URLSession, add NetMockURLProtocol to your URLSessionConfiguration when constructing it:
```swift
let configuration = URLSessionConfiguration.ephemeral
configuration.protocolClasses = [NetMockURLProtocol.self]
return URLSession(configuration: configuration)
```

To make use of NetMock in system calls and webviews, apply:
```swift
URLProtocol.registerClass(NetMockURLProtocol.self)
```

To apply NetMock throughout the app, including dependencies which don't make their URLSession injectable, NetMock provides a one-line call to inject itself everywhere:
```swift
NetMockURLProtocol.applyGlobally()
```

To mock out GraphQL responses, which tend to go through a single endpoint with the actual request in the body, you may choose to have your testing network stack use a custom URL specifically for NetMock lookup.

## NetMock files

NetMock files contain mock responses, and can be used to avoid making live calls, allowing us to develop or test an app offline using real, saved API responses. NetMock will find all these files, and inject them as responses when a request is made.

### Format

A typical NetMock response file looks as follows:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example

200
{
  "jsonValue": 123
}
```

### Providing alternative status codes

You may provide alternative responses for different status codes with a divider of "\n---" between them:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example

200
{
  "jsonValue": 123
}
---
404
---
418
{
  "example": "abc"
}
---
500
```

The first response in the list will be used by default.

Optionally, you may provide a trailing "\n---" on the final response in a file.

### Response sequences

The first response will be used by default, but a different default, or a sequence of responses can be configured. The last item in the sequence will be repeated if subsequent calls are made.

`ExampleGETAPI.nm`
```
GET https://api.example.com/example 200 500 200

200
{
  "jsonValue": 123
}
---
404
---
418
{
  "example": "abc"
}
---
500
```

In this example, 200 will be used for the first call, then 500, then 200 will be used for all subsequent calls.

### Response disambiguation

To disambiguate when multiple responses share a status code, responses can be named:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example Success 500 SuccessLong

200 Success
{
  "jsonValue": 123
}
---
200 SuccessLong
{
  "jsonValue": 123,
  "anotherJSONValue": 456
}
---
404
---
418
{
  "example": "abc"
}
---
500
```

NetMock supports adding multiple names for a single response, separated by spaces, which could be useful when performing a naming migration, or when two use-cases happen to match.

### Live responses

Specifying an identifier of "#Live" will tell the test to perform the real API call. Sequencing calls after #Live is not supported, #Live must always be positioned at the end of the sequence.

`ExampleGETAPI.nm`
```
GET https://api.example.com/example 200 #Live

200
{
}
```

### Network availability errors / URLError

Networking errors occur when the server could not be reached, meaning no HTTP status code is available or relevant. These could include no internet, transport security failures, timeouts, and more.

To simulate a networking error, such as `URLError(.notConnectedToInternet)`, provide the corresponding error code in the response sequence:

`ExampleGETAPI.nm`
```
GET https://api.example.com/example -1009
```

By design, all URLError error codes are negative, while HTTP response codes are positive, so this is not ambiguous. Response body definitions for negative status codes will be ignored.

### Versioning

As of version 2.1.1, the NetMock file format support versioning, to make them forward-compatible with breaking changes to the file schema. This is achieved through an optional versioning header:

`ExampleGETAPI.nm`
```
NetMock 2.1.1
GET https://api.example.com/example
```

Breaking changes to the file format should generally be accompanied by a major version bump to the package, so in theory the major version specified by a file should be all that matters if we make use of this in future. However, minor versions are still parsed.

## Further configuration

### Custom URL handling

Many projects have a primary API which the apps calls, such as `https://api.example.com/`. In these cases, it may be desirable to maintain a single source of truth for this base URL, and specify only the API path in NetMock files.

NetMock allows a custom URL interpretation step to be inserted before its own parsing, allowing an app to specify its own schema for URLs. In the simple case, an app could check if the URL string is a full `https://` URL, and inject the API URL if not.

```swift
NetMock.shared.applyCustomURLParsing { urlString in
    if !urlString.hasPrefix("https://") {
        return URL(string: "https://api.example.com/" + urlString) // Example use-case: Inject API domain to API path specified in NetMock file
    }
    return nil // Use NetMock default behaviour, or previously set custom parsing
}
NetMock.shared.initialise()
```

Parsing is performed during the call to `initialise`, so you must ensure this call is made prior to initialisation.

With this setup, we can simplify our call to `https://api.example.com/example`:

`ExampleGETAPI.nm`
```
GET example

200
```

### Testing & Overrides

In unit tests, overrides can be provided using the NetMock API:
```swift
NetMock.override(URL("https://api.example.com/example")!, responses: ["Success", 500, 404, "SuccessLong"])
```

In UI tests, the UI test target could communicate to the app via launch arguments to build an API like so:
```swift
AppRobot()
    .netmockOverride(URL("https://api.example.com/example")!, responses: ["Success", 500, 404, "SuccessLong"])
```

Note that consecutively run UI tests may preserve launch arguments, so the API used should account for this in resetting launch arguments even when no overrides are specified.

## Justification of approach

NetMock performs injection client-side, for a number of reasons:

- We can inject responses we want, and sequence them as needed, which we can't making actual requests to a live API.
- We can simulate a range of API error responses, which a mock API may not support.
- We can simulate network availability errors, which is just not possible via a mock API.
- We can make use of JSON responses captured during implementation & testing, with no code needed, which saves time compared to constructing responses programmatically.
- We can inject responses for calls to domains outside of our control without the need for a self-hosted DNS, and without the need to mimic transport security protections, providing an advantage to our scope of coverage compared to a localhost server.
- NetMock achieves a lot of capability with very little actual implementation code, making it extremely maintainable to anyone with a little iOS experience, while other approaches could get significantly more complex.

### Injection

We can use NetMock for system calls and webviews:
```swift
URLProtocol.registerClass(NetMockURLProtocol.self)
```

We can use NetMock for any calls where we have access to the URLSession:
```swift
var urlSessionConfig = URLSessionConfiguration.ephemeral
urlSessionConfig.protocolClasses = [NetMockURLProtocol.self]
let urlSession = URLSession(configuration: urlSessionConfig)
```

If we don't have access to the URLSession point of construction, our options are more limited. If we have a Local configuration, it is still technically possible to change out the default globally in this configuration using swizzling, if we so desire:
```swift
#if LOCAL
private extension URLSessionConfiguration {
    @objc class var defaultWithNetMock: URLSessionConfiguration {
        let config = URLSessionConfiguration.defaultWithNetMock // Now has .default's implementation
        config.protocolClasses = [NetMockURLProtocol.self] + (config.protocolClasses ?? [])
        return config
    }
    static func swizzleDefault() {
        let original = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: defaultWithNetMock))!
        let replacement = class_getClassMethod(URLSessionConfiguration.self, #selector(getter: `default`))!
        method_exchangeImplementations(original, replacement)
    }
}
#endif
```

## NetMock Capture and File Generation

The `NetMock.DocumentStore` actor and its related methods enable the automatic capturing and saving of network responses in the form of NetMock documents. This can be particularly useful when preparing testing environments where a lot of real-world data may be required, such as UI testing.

### Response Capturing

Live network responses can be captured automatically by applying NetMockCaptureURLProtocol's `applyGlobally` function.

```swift
#if CAPTURE
NetMockCaptureURLProtocol.applyGlobally()
#endif
``` 

This will capture all network requests performed via URLSession, directly or indirectly.

Other uses-cases can be built to pass network responses to the `DocumentStore` via `DocumentStore.add`.

```swift
class ApolloNetMockInterceptor: ApolloInterceptor {
    let id: String = UUID().uuidString
    
    let active: Bool
    
    init(isActive: Bool) {
        self.active = isActive
    }
    
    func interceptAsync<Operation>(
        chain: any Apollo.RequestChain,
        request: Apollo.HTTPRequest<Operation>,
        response: Apollo.HTTPResponse<Operation>?,
        completion: @escaping (Result<Apollo.GraphQLResult<Operation.Data>, any Error>) -> Void
    ) where Operation : ApolloAPI.GraphQLOperation {
        /// Always pass the request and response through to the next interceptor layer 
        /// to maintain normal network behaviour and avoid interrupting the network stack.
        defer { chain.proceedAsync(request: request, response: response, interceptor: self, completion: completion) }
        
        guard active else { return }
        
        let method: NetMock.Method = .init(operationType: Operation.operationType)
        let urlString = URL(string: "\(request.graphQLEndpoint.host ?? "no.host")/\(Operation.operationName)")!
        let statusCode: Int = response?.httpResponse.statusCode ?? 408 // Assume timeout if response not provided
        let body: Data? = response?.rawData
        
        /// Build DocumentStoreEntry instance from response information
        /// Method and urlString should uniquely identify the response type
        let storeEntry: NetMock.DocumentStoreEntry = .init(method: method, url: url, statusCode: statusCode, body: body)
        
        /// Add NetMock response to DocumentStore
        Task {
            await NetMock.DocumentStore.shared.add(storeEntry)
        }
    }
}
```

Multiple responses to the same request will be combined into a single file, labelled by the timestamp of capture time.

### File Generation

Use `DocumentStore.save` method to persist captured responses to the disk. By default, the method will save to the app's document directory. 

The save function also features parameters for customising file locations and contents which can be used to generalise domains and organise the resulting files:
- `toDirectory`: The base directory where files will be written. Defaults to the app’s document directory.
- `modifyContents`: A closure for transforming the saved file contents (e.g. redacting or generalising domains). Defaults to a closure with no effect.
- `customFilename`: A closure for customising the file’s name, not including the file extension. Defaults to the last component of the urlString (if a valid url) otherwise the full urlString.
- `customSubpath`: A closure for customising the directory structure for each response. Defaults to all but the last component of the urlString plus the method.

```swift
Button("Save Responses") {
    Task {
        await NetMock.DocumentStore.shared.save { fileContents in
            fileContents.replacingOccurrences(
                of: "gateway.uat.testservice.net", with: "graphql:/"
            )
        }
    }
}
```

In this example, the `modifyContents` closure replace occurrences of the UAT domain with a more generalised URL, allowing the persisted files to remain environment-agnostic.

### Resetting

Use `DocumentStore.reset` method to erase captured responses from `DocumentStore`. This action will not affect captured responses that have been persisted to the disk. This can be used a convenient way to reset the app's captured responses without having to restart the app.

```swift
Button("Erase Responses") {
    Task {
        await NetMock.DocumentStore.shared.reset() 
    }
}
```
