import CLua

extension Bool: Value {
    public var type: Type {
        .boolean
    }
    
    public func push(_ lua: Lua) {
        lua_pushboolean(lua.state, self ? 1 : 0)
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        value.type == .boolean
    }
}

#warning("TODO: Make Optional a Value")
public class Nil: Value, Equatable {
    public var type: Type {
        .nil
    }
    
    public func push(_ lua: Lua) {
        lua_pushnil(lua.state)
    }

    public class func typecheck(value: Value, lua: Lua) -> Bool {
        value.type == .nil
    }
    
    public static func == (lhs: Nil, rhs: Nil) -> Bool {
        true
    }
}

public class Number: StoredValue, CustomDebugStringConvertible {
    override public var type: Type {
        .number
    }

    public func toDouble() -> Double {
        self.push(self.lua)
        let double = lua_tonumberx(lua.state, -1, nil)
        self.lua.pop()
        return double
    }

    public func toInteger() -> Int64 {
        self.push(self.lua)
        let integer = lua_tointegerx(self.lua.state, -1, nil)
        self.lua.pop()
        return integer
    }

    public var debugDescription: String {
        self.push(self.lua)
        let isInteger = lua_isinteger(self.lua.state, -1) != 0
        self.lua.pop()

        guard isInteger else {
            return toDouble().description
        }
        
        return toInteger().description
    }

    public override class func typecheck(value: Value, lua: Lua) -> Bool {
        value.type == .number
    }
}

extension Double: Value {
    public var type: Type {
        .number
    }
    
    public func push(_ lua: Lua) {
        lua_pushnumber(lua.state, self)
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        value.push(lua)
        let isDouble = lua_isnumber(lua.state, -1) != 0
        lua.pop()
        return isDouble
    }
}

extension Int64: Value {
    public var type: Type {
        .number
    }

    public func push(_ lua: Lua) {
        lua_pushinteger(lua.state, self)
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        value.push(lua)
        let isInteger = lua_isinteger(lua.state, -1) != 0
        lua.pop()
        return isInteger
    }
}

extension Int: Value {
    public var type: Type {
        .number
    }
    
    public func push(_ lua: Lua) {
        lua_pushinteger(lua.state, Int64(self))
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        Int64.typecheck(value: value, lua: lua)
    }
}

extension String: Value {
    public var type: Type {
        return .string
    }
    
    public func push(_ lua: Lua) {
        lua_pushstring(lua.state, self)
    }

    public static func typecheck(value: Value, lua: Lua) -> Bool {
        value.type == .string
    }
}
