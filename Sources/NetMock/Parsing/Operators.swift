//
//  Operators.swift
//  NetMock
//
//  Created by Christopher Wainwright on 14/10/2025.
//


extension Parser {
    /// Functor
    ///
    /// Functor Operator (transform value inside Monadic context of Parser)
    /// - Parameter transform: An operation to perform on a parsers result after parsing has completed.
    /// - Returns: A parser with the transformation mapped to its output.
    func map<U>(transform: @Sendable @escaping (T) throws -> U) -> Parser<U> {
        Parser<U> { input in
            try transform(try self.run(&input))
        }
    }
}

/// Alternative
///
/// Alternative Operator (parse this, but if that fails, parse this instead)
infix operator <|> : LogicalDisjunctionPrecedence

func <|><A>(
    lhs: Parser<A>,
    rhs: Parser<A>
) -> Parser<A> {
    Parser { input in
        do {
            return try lhs.run(&input)
        } catch let firstError as ParseError {
            do {
                return try rhs.run(&input)
            } catch let secondError as ParseError {
                throw ParseError.eitherError(firstError, secondError)
            }
        }
    }.atomic()
}

/// Monad
///
/// Bind Operator (parse this, then pipe the result into this parser)
infix operator >>= : AdditionPrecedence

func >>=<A, B>(
    lhs: Parser<A>,
    rhs: @Sendable @escaping (A) -> Parser<B>
) -> Parser<B> {
    Parser<B> { input in
        let a = try lhs.run(&input)
        let bParser = rhs(a)
        return try bParser.run(&input)
    }.atomic()
}

extension Parser {
    func bind<B>(to parserBuilder: @Sendable @escaping (T) -> Parser<B>) -> Parser<B> {
        self >>= parserBuilder
    }
}

/// Bind left (discarding)
///
/// Make the success of the rhs parser dependent on the success of the lhs parser
/// If both succeed, the result of the rhs parser will be returned
/// If either fail, an error will be thrown
infix operator *> : AdditionPrecedence

func *><A, B>(
    lhs: Parser<A>,
    rhs: Parser<B>
) -> Parser<B> {
    .init { input in
        let _ = try lhs.run(&input)
        let b = try rhs.run(&input)
        return b
    }.atomic()
}

/// Bind right (discarding)
///
/// Make the success of the lhs parser dependent on the success of the rhs parser
/// If both succeed, the result of the lhs parser will be returned
/// If either fail, an error will be thrown
infix operator <* : AdditionPrecedence

func <*<A, B>(
    lhs: Parser<A>,
    rhs: Parser<B>
) -> Parser<A> {
    .init { input in
        let a = try lhs.run(&input)
        let _ = try rhs.run(&input)
        return a
    }.atomic()
}
