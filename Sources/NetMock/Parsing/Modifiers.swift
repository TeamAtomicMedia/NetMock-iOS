//
//  Modifiers.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
//


/// Parser Modifiers
extension Parser {
    /// Make Compound Parser Atomic
    ///
    /// Make parser groupings atomic, either they complete completely,
    /// or fail and restore the partially consumed string to its original state
    func atomic() -> Parser<T> {
        .init { input in
            let original = input
            do {
                return try self.run(&input)
            } catch {
                input = original
                throw error
            }
        }
    }
    
    /// Make Parser Optional
    ///
    /// This modifier transforms the output of the parser to an optional
    /// - If the parser completes successfully, it will return the value as normal
    /// - If the parser does not complete, it will return nil and restore the input to its original
    func optional() -> Parser<T?> {
        .init { input in
            let original = input
            if let result = try? self.run(&input) {
                return result
            }
            input = original
            return nil
        }
    }
    
    /// Make Parser Optional
    ///
    /// This modifier adds a default to the parser output
    /// - If the parser completes successfully, it will return its result as normal
    /// - If the parser does not complete, it will return a default value and restore the input to its original
    func optional(defaultValue: T) -> Parser<T> {
        .init { input in
            let original = input
            if let result = try? self.run(&input) {
                return result
            }
            input = original
            return defaultValue
        }
    }
    
    /// Discard Parser's Output
    ///
    /// Useful when you want to consume a token without using the result
    func discard() -> Parser<Void> {
        .init { input in
            let _ = try? self.run(&input)
        }
    }
    
    /// Consume Multiple Tokens Sequentially
    ///
    /// # Parameters:
    /// - separator: customise the separator between each element in your sequence, defaults to ', ' (with optional trailing whitespace)
    /// - allowEmpty: accept no instances of elements and separators, returning an empty array
    /// - allowTrailingSeparator: accept trailing separator in list
    func sequence<U>(separator: Parser<U> = (.character(",") *> .whitespace().optional()), allowEmpty: Bool = true, allowTrailingSeparator: Bool = true) -> Parser<[T]> {
        .init { input in
            var results: [T] = []
            
            do {
                let first = try self.run(&input)
                results.append(first)
            } catch {
                if allowEmpty {
                    return results
                } else {
                    throw error
                }
            }
            
            while !input.isEmpty {
                let original = input
                do {
                    let _ = try separator.run(&input)
                    do {
                        let element = try self.run(&input)
                        results.append(element)
                    } catch {
                        if allowTrailingSeparator {
                            return results
                        } else {
                            throw error
                        }
                    }
                } catch {
                    input = original
                    return results
                }
            }
            
            return results
        }
    }
    
    /// Provide Context for Thrown Errors
    ///
    /// When an error is thrown by a parser, this modifier will catch the error,
    /// wrapping it with a `String` to provide additional context as to where the error was thrown
    func context(_ label: String) -> Parser<T> {
        .init { input in
            do {
                return try self.run(&input)
            } catch {
                if let parseError = error as? ParseError {
                    throw ParseError.contextualError(label, parseError)
                } else {
                    throw error
                }
            }
        }
    }
    
    /// Ensure a complete parse
    /// Trailing input which remains unconsumed will trigger an .incompleteParser error
    func complete() -> Parser<T> {
        .init { input in
            do {
                let result = try self.run(&input)
                
                if !input.isEmpty {
                    throw ParseError.incompleteParse(input)
                }
                
                return result
            }
        }
    }
}
