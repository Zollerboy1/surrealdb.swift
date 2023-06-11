import SurrealDB

@Model
final class Foo {
    static let table = "foo"

    let id: Int
    let bar: String
    var baz: Int
    var qux = "Hello"
}

print("Hello, world!")
