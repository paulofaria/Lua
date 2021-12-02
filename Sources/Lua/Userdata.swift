import CLua

public class Userdata: StoredValue {
    override public var type: Type {
        .userdata
    }
    
    func userdataPointer() -> UnsafeMutableRawPointer {
        self.push(self.lua)
        let pointer = lua_touserdata(self.lua.state, -1)!
        self.lua.pop()
        return pointer
    }
    
    func userdataPointer<T>() -> UnsafeMutablePointer<T> {
        self.userdataPointer().assumingMemoryBound(to: T.self)
    }

    func toCustomType<T: CustomTypeInstance>() -> T {
        self.userdataPointer().pointee
    }

    func forceToCustomType<T>() -> T {
        self.userdataPointer().pointee
    }

    func toAny() -> Any {
        self.userdataPointer().pointee
    }
    
    public override class func typecheck(value: Value, lua: Lua) -> Bool {
        value.type == .userdata
    }
}





