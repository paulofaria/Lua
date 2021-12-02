import CLua

#warning("TODO: Rename this")
public protocol CustomTypeInstance: TypeCheckable {
    #warning("TODO: What is this all about? Allow freeing resources? Looks like Lua doesn't like that. Ir prefers to use the garbage collector to only free memory, not resources like files, etc.")
    func deinitialize()
}

public extension CustomTypeInstance {
    func deinitialize() {}
    
    static var luaTypeName: String {
        return String(reflecting: self)
    }

    static func typecheck(value: Value, lua: Lua) -> Bool {
        value.push(lua)
        let isLegit = luaL_testudata(lua.state, -1, Self.luaTypeName) != nil
        lua.pop()
        return isLegit
    }
}
