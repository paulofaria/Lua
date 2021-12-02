public protocol TypeCheckable {
    static func typecheck(value: Value, lua: Lua) -> Bool
}
