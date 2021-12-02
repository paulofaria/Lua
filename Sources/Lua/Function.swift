import CLua


public class Function: StoredValue {
    public func call(_ arguments: Value...) throws -> [Value] {
        try self.call(arguments)
    }
    
    public func call(_ arguments: [Value]) throws -> [Value] {
        let debugTable = self.lua.globals["debug"] as! Table
        let messageHandler = debugTable["traceback"]

        let originalStackTop = self.lua.topElementIndex

        messageHandler.push(self.lua)
        push(self.lua)
        
        for argument in arguments {
            argument.push(self.lua)
        }

        let result = lua_pcallk(
            self.lua.state,
            Int32(arguments.count),
            LUA_MULTRET,
            Int32(originalStackTop + 1),
            0,
            nil
        )
        
        self.lua.remove(at: originalStackTop + 1)

        guard result == LUA_OK else {
            throw self.lua.popError()
        }

        var values: [Value] = []
        let numReturnValues = self.lua.topElementIndex - originalStackTop

        for _ in 0 ..< numReturnValues {
            let value = self.lua.pop(at: originalStackTop + 1)!
            values.append(value)
        }

        return values
    }

    override public var type: Type {
        return .function
    }

    override public class func typecheck(value: Value, lua: Lua) -> Bool {
        return value.type == .function
    }
}
