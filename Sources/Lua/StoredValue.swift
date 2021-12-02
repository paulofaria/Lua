import CLua

public class StoredValue: Value, Equatable {
    #warning("TODO: Store this in Lua and call unref over there on deinit. Like the functions.")
    private let registryLocation: Int
    #warning("TODO: Fix leak, don't store lua here.")
    internal let lua: Lua

    internal init(_ state: OpaquePointer) {
        self.lua = Lua(state)
        self.lua.pushValue(at: -1)
        self.registryLocation = self.lua.reference(Lua.registryIndex)
    }

    deinit {
        self.lua.releaseReference(Lua.registryIndex, self.registryLocation)
    }
    
    public var type: Type {
        fatalError("Override type")
    }

    public func push(_ lua: Lua) {
        lua.rawGet(at: Lua.registryIndex, n: self.registryLocation)
    }

    public class func typecheck(value: Value, lua: Lua) -> Bool {
        fatalError("Override arg()")
    }
    
    public static func == (lhs: StoredValue, rhs: StoredValue) -> Bool {
        if lhs.lua.state != rhs.lua.state {
            return false
        }

        lhs.push(lhs.lua)
        lhs.push(rhs.lua)
        let result = lua_compare(lhs.lua.state, -2, -1, LUA_OPEQ) == 1
        lhs.lua.pop(n: 2)

        return result
    }
}
